extends Node

var input_delay = 5 #amount of input delay in frames
var rollback = 7 #number of frame states to save in order to implement rollback (max amount of frames able to rollback)
var dup_send_range = 5 #frame range of duplicate past input packets to send every frame (should be less than rollback in current implementation)

var input_array = [] #array for inputs
var state_queue = [] #queue for states at passed frames (for rollback)
var input_arrival_array = [] #boolean array to determine if inputs for a given frame have arrived from the network
var input_local_saved_array = [] #boolean array to determine if local inputs for a given frame are viable (can be sent by request)
var prev_frame_arrival_array = [] #boolean array to compare input arrivals between current and previous frames
var input_array_mutex = Mutex.new()
var input_local_saved_array_mutex = Mutex.new()

var frame_num = 0 #ranges between 0-255 per circular input array cycle (cycle is every 256 frames

var game_state = {} #holds dictionaries that track children states every frame

var input_received #boolean to detect if new inputs have been received, set to true by networking thread, set to false by main when waiting on input
var input_received_mutex = Mutex.new()

var input_thread = null #thread to receive inputs over the network

var UDPPeer = PacketPeerUDP.new()

#class declarations
class Inputs:
	var local_input #inputs by local player for a single frame
	var net_input #inputs by a player over network for a single frame
	var encoded_local_input
	
	func _init():
		#Indexing [0]: W, [1]: A, [2]: S, [3]: D, [4]: SPACE
		self.local_input = [false, false, false, false, false]
		self.net_input = [false, false, false, false, false]
		encoded_local_input = 0


class Frame_State:
	var local_input #inputs by local player for a single frame
	var net_input #inputs by a player over network for a single frame
	var frame #frame number according to 256 frame cycle number
	#var true_frame #absolute frame number (Warning: if game runs for a long time, this number can exceed max int. Can be used for storing frame states for a short game for replay functionality?)
	var game_state #dictionary holds the values need for tracking a game's state at a given frame. Keys are child names.
	var actual_input #boolean, whether the state contains guessed input (false) or actual input (true) from networked player


	func _init(_local_input, _net_input, _frame, _game_state, _actual_input):
		self.local_input = _local_input
		self.net_input = _net_input
		self.frame = _frame
		#self.true_frame = _true_frame
		self.game_state = _game_state
		self.actual_input = _actual_input


func thr_network_inputs(userdata = null): #thread function to read inputs from network
	while(true):
		UDPPeer.wait() #wait for packets to arrive
		var result = true
		while (result):
			result = UDPPeer.get_packet() #receive a single packet
			if result:
				match result[0]: #switch statement for header byte
					0: #input received
						#print("INPUT RECEIVED")
						if result.size() == 3: #check for complete packet (no bytes lost)
							input_array_mutex.lock()
							if input_arrival_array[result[1]] == false: #if input arrival is false
#								print("GOOD INPUT FOR FRAME: ", result[1], ", frame_num is: ", frame_num, ", inputs is: ", result[2])
								input_array[result[1]].net_input = [
										bool(result[2] & 1),
										bool(result[2] & 2),
										bool(result[2] & 4),
										bool(result[2] & 8),
										bool(result[2] & 16)]
								input_arrival_array[result[1]] = true
								input_received_mutex.lock()
								input_received = true
								input_received_mutex.unlock()
							input_array_mutex.unlock()

					1: #request for input received
						#print("REQUEST FOR INPUT RECEIVED")
						if result.size() == 3: #check for complete packet (no bytes lost)
#							print("RECEIVED REQUEST FOR FRAMES ", result[1], " TO ", result[2])
							var frame = result[1]
							input_local_saved_array_mutex.lock()
							while (frame != result[2]): #send inputs for requested frame and newer past frames
								if input_local_saved_array[frame] == false: break #do not send inputs for future frames
#								print("requests for frame ", frame, " sent.")
								UDPPeer.put_packet(PoolByteArray([0, frame, input_array[frame].encoded_local_input]))
								#print("FULFILLING REQUEST FOR FRAME: ", frame)
								frame = (frame + 1)%256
							input_local_saved_array_mutex.unlock()

					2: #game start
						input_received = true

					3: #game end
						pass #add response to game end


func _ready():
	#initialize input array
	for x in range (0, 256):
		input_array.append(Inputs.new()) 
	
	#initialize state queue
	for x in range (0, rollback):
		#empty local input, empty net input, frame 0, inital game state, treat initial empty inputs as true
		state_queue.append(Frame_State.new({}, {}, 0, get_game_state(), true))
	
	#initialize arrived input array
	for i in range (0, 256):
		input_arrival_array.append(false)
		input_local_saved_array.append(false)
	for i in range (1, rollback + 100):
		prev_frame_arrival_array.append(true)
		input_arrival_array[-i] = true # for initialization, pretend all "previous" inputs arrived
	for i in range (0, input_delay):
		input_arrival_array[i] = true # assume empty inputs at game start input_delay window
		input_local_saved_array[i] = true
		
	input_received = false #network thread will set to true when a networked player is found.
	
	#set up networking thread, definition of sending/receiving addresses and ports
	UDPPeer.listen(240, "*")
	UDPPeer.set_dest_address("::1", 240) #::1 is localhost
	input_thread = Thread.new()
	input_thread.start(self, "thr_network_inputs", null, 2)
	
	while(!input_received):#search for networked player (block until networked player is found)
		UDPPeer.put_packet(PoolByteArray([2])) #send ready handshake to opponent
#		print("SENDING HANDSHAKE")


func _physics_process(delta):
#	print("Starting relative frame: ", frame_num)
	input_received_mutex.lock()
	if (input_received):
		#if the oldest Frame_State is guessed, but the input_queue Input does not yet contain an actual input for the oldest Frame_State's frame
		if state_queue[0].actual_input == false && input_arrival_array[state_queue[0].frame] == false:
			input_received = false #block until actual input is received for guessed oldest Frame_State
			input_received_mutex.unlock()
#			print("SENDING REQUEST FOR FRAMES ", state_queue[0].frame, " to ", frame_num)
			UDPPeer.put_packet(PoolByteArray([1, state_queue[0].frame, frame_num])) #send request for needed input
		else:
			input_received_mutex.unlock()
			handle_input()
	else:
		input_received_mutex.unlock()
#		print("SENDING REQUEST FOR FRAMES ", state_queue[0].frame, " to ", frame_num)
		UDPPeer.put_packet(PoolByteArray([1, state_queue[0].frame, frame_num])) #send request for needed input
	


func handle_input(): #get input, run rollback if necessary, implement inputs
	var pre_game_state = get_game_state()
#	print("handle_input start pre_game_state: ", pre_game_state)
	var actual_input = true
	var start_rollback = false
	
	var current_input = null
	var current_frame_arrival_array = []

	var local_input = [false, false, false, false, false]
	var encoded_local_input = 0
	
	frame_start_all() #for all children, set their update vars to their current/actual values
	
	input_array_mutex.lock()
	#record local inputs
	if Input.is_key_pressed(KEY_W):
		local_input[0] = true
		encoded_local_input += 1
	if Input.is_key_pressed(KEY_A):
		local_input[1] = true
		encoded_local_input += 2
	if Input.is_key_pressed(KEY_S):
		local_input[2] = true
		encoded_local_input +=4
	if Input.is_key_pressed(KEY_D):
		local_input[3] = true
		encoded_local_input += 8
	if Input.is_key_pressed(KEY_SPACE):
		local_input[4] = true
		encoded_local_input += 16
	
	input_array[(frame_num + input_delay) % 256].local_input = local_input
	input_array[(frame_num + input_delay) % 256].encoded_local_input = encoded_local_input
	
#	if (false):#for testing rollback and requests (forces max rollback by only using input request system)
	for i in dup_send_range + 1: #send inputs for current frame as well as duplicates of past frame inputs
		UDPPeer.put_packet(PoolByteArray([0, (frame_num + input_delay - i) % 256,
				input_array[(frame_num + input_delay - i) % 256].encoded_local_input]))
#	print("SENT INPUT: input frame is: ", frame_num + input_delay, ", input is: ", input_array[(frame_num + input_delay) % 256].encoded_local_input)
	
	#get current input arrival boolean values for current frame & old frames eligible for rollback
	for i in range(0, rollback + 1): 
		current_frame_arrival_array.push_front(input_arrival_array[frame_num - i]) #oldest frame in front
	
	input_array_mutex.unlock()
	
	input_local_saved_array_mutex.lock()
	input_local_saved_array[(frame_num + input_delay) % 256] = true
	input_local_saved_array_mutex.unlock()
	
	var current_frame_arrival = current_frame_arrival_array.pop_back() #remove current frame's arrival boolean for rollback condition comparison
	
	if current_frame_arrival_array.hash() != prev_frame_arrival_array.hash(): #if an old input has newly arrived (to fulfill a guess),
		#print("Rollback...")
		#iterate through all saved states until the state with the guessed input to be replaced by arrived actual input is found (rollback will begin with that state)
		#then, continue iterating through remaining saved states to continue rollback resimulation process
		var state_index = 0 #for tracking iterated element's index in state_queue
		for i in state_queue: #index 0 is oldest state
			#if an arrived input is for a past frame
			if (prev_frame_arrival_array[state_index] == false && current_frame_arrival_array[state_index] == true):
				input_array_mutex.lock()
				i.net_input = input_array[i.frame].net_input.duplicate() #set input in Frame_State from guess to true actual input
				input_array_mutex.unlock()
				i.actual_input = true #input has been set from guess to actual input
				if start_rollback == false:
					game_state = i.game_state #set value of game_state to old state for rollback resimulation of states/inputs
					reset_state_all(game_state) #reset update variables for all children to match given state ONCE
					start_rollback = true
				pre_game_state = get_game_state()
				update_all(input_array[i.frame]) #update game_state using new input
			#otherwise, continue simulating using currently stored input
			else:
				if start_rollback == true:
					pre_game_state = get_game_state() #save pre-update game_state value for Frame_State
					update_all(input_array[i.frame]) #update game_state using old (guessed or actual) input during rollback resimulation 			
			if start_rollback == true:
				i.game_state = pre_game_state #update Frame_States with updated game_state value.
			state_index += 1
			
	current_frame_arrival_array.push_back(current_frame_arrival) #reinsert current frame's arrival boolean (for next frame's prev_frame_arrival_array)
	current_frame_arrival_array.pop_front() #remove oldest frame's arrival boolean (needed for rollback condition comparison, but unwanted for next frame's prev_frame_arrival_array)
	
	current_input = Inputs.new()
	input_array_mutex.lock()
	#if the input for the current frame has not been received
	if input_arrival_array[frame_num] == false:
		
		#implement guess of empty input (can be replaced with input-guessing algorithm)
		current_input.local_input = input_array[frame_num].local_input.duplicate()
		input_array[frame_num].net_input = current_input.net_input

		#implement guess of last input used
#		current_input.local_input = input_array[frame_num].local_input.duplicate()
#		current_input.net_input = input_array[frame_num - 1].net_input.duplicate()
#		input_array[frame_num].net_input = input_array[frame_num - 1].net_input.duplicate()
		
		actual_input = false
	else: #else (if the input for the current frame has been received), proceed with true, actual input
		current_input.local_input = input_array[frame_num].local_input.duplicate()
		current_input.net_input = input_array[frame_num].net_input.duplicate()
	
	input_arrival_array[frame_num - (rollback + 120)] = false #reset input arrival boolean for old frame
	input_array_mutex.unlock()
	
	input_local_saved_array_mutex.lock()
	input_local_saved_array[frame_num - (rollback + 120)] = false #reset viable local input boolean
	input_local_saved_array_mutex.unlock()

	if start_rollback == true:
		pre_game_state = get_game_state()
		
	update_all(current_input) #update with current input
	execute_all() #implement all applied updates/inputs to all child objects
	
	#store current frame state into queue
	state_queue.append(Frame_State.new(current_input.local_input, current_input.net_input, frame_num, pre_game_state, actual_input))
	
	#remove oldest state from queue if queue has exceeded size limit
	if len(state_queue) > rollback:
		state_queue.pop_front()

	prev_frame_arrival_array = current_frame_arrival_array #store current input arrival array for comaparisons in next frame
	frame_num = (frame_num + 1)%256 #increment frame_num


func frame_start_all():
	for child in get_children():
		child.frame_start()


func reset_state_all(game_state):
	for child in get_children():
		child.reset_state(game_state)


func update_all(input):
	for child in get_children():
		child.input_update(input)


func execute_all():
	for child in get_children():
		child.input_execute()


func get_game_state():
	var state = {}
	for child in get_children():
		state[child.name] = child.get_state()
	game_state = state
	return game_state.duplicate(true) #deep duplicate to copy all nested dictionaries by value instead of by reference