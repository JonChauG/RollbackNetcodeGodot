extends Node

export var input_delay = 5 #amount of input delay in frames
export var net_delay = 4 #amount of artificial "network" delay for effective inputs (for rollback TESTING)
export var rollback = 7 #number of frame states to save in order to implement rollback (max amount of frames able to rollback)
export var dup_send_range = 5 #frame range of duplicate past input packets to send every frame (should be less than rollback in current implementation)

var input_array = [] #array for inputs
var state_queue = [] #queue for states at passed frames (for rollback)
var input_arrival_array = [] #boolean array to determine if inputs have arrived, can replace input_arrival_array?
var prev_frame_arrival_array = []

var input_array_mutex = Mutex.new()

var frame_num = 0 #ranges between 0-255 per circular input array cycle (cycle is every 256 frames
var game_state = {} #holds dictionaries that track children states every frame

var input_received #boolean to detect if new inputs have been received, set to true by networking thread, set to false by main when waiting on input
var input_received_mutex = Mutex.new()

var input_thread

var UDPPeer = PacketPeerUDP.new()

#class declarations
class Inputs:
	var local_input #inputs by local player for a single frame
	var net_input #inputs by a player over network for a single frame
	
	func _init():
		self.local_input = {'W': false, 'A': false, 'S': false, 'D': false, 'SPACE': false}
		self.net_input = {'W': false, 'A': false, 'S': false, 'D': false, 'SPACE': false}


class Frame_State:
	var local_input #inputs by local player for a single frame
	var net_input #inputs by a player over network for a single frame
	var frame #frame number according to 256 frame cycle number
	#var true_frame #absolute frame number (Warning: if game runs for a long time, this number will exceed maximum and can cause problems. Can be used for storing frame states for a short game for replay functionality
	var game_state #dictionary holds the values need for tracking a game's state at a given frame. keys are child names
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
			if result: #if (empty PoolByteArray gives false)
				match result[0]: #switch statement for header byte
					0: #input received
						#print("INPUT RECEIVED")
						if result.size() == 7: #check for complete packet (no bytes lost)
							input_array_mutex.lock()
							if input_arrival_array[result[1]] == false:# && frame_num%12:#if input arrival is false and input is within future window
								print("GOOD INPUT FOR FRAME: ", result[1], ", frame_num is: ", frame_num)
								input_array[result[1]].net_input = {
										'W': result[2],
										'A': result[3],
										'S': result[4],
										'D': result[5],
										'SPACE': result[6]}
								input_arrival_array[result[1]] = true
								input_received_mutex.lock()
								input_received = true
								input_received_mutex.unlock()
							input_array_mutex.unlock()
					
					1: #request for input received
						#print("REQUEST FOR INPUT RECEIVED")
						if result.size() == 3: #check for complete packet (no bytes lost)
							print("RECEIVED REQUEST FOR FRAMES ", result[1], " TO ", result[2])
							var frame = result[1]
							while (frame != result[2]): #send inputs for requested frame and newer past frames
								if frame == frame_num: break #do not send inputs for future frames
								print("requests for frame ", frame, " sent.")
								UDPPeer.put_packet(PoolByteArray([0, frame,
										input_array[frame].local_input['W'], 
										input_array[frame].local_input['A'],
										input_array[frame].local_input['S'],
										input_array[frame].local_input['D'],
										input_array[frame].local_input['SPACE']]))
								#print("FULFILLING REQUEST FOR FRAME: ", frame)
								frame = (frame + 1)%256

					2: #game start
						input_received = true


func _ready():
	#initialize input array
	for x in range (0, 256):
		input_array.append(Inputs.new()) 
	
	#initialize state queue
	for x in range (0, rollback):
		state_queue.append(Frame_State.new({}, {}, 0, get_game_state(), true)) #empty inputs, frame 0, initial game state, actual input
	
	#print("init game state: " + str(get_game_state()))
	
	#initialize arrived input array
	for i in range (0, 256):
		input_arrival_array.append(false)
	
	for i in range (1, rollback + 1):
		prev_frame_arrival_array.append(true)
		input_arrival_array[-i] = true #pretend all "previous" inputs arrived for initialization
	
	#create separate thread to receive inputs from network (testing)
	
	input_received = false #network thread will set to true when a networked player is found.
	
	UDPPeer.listen(240, "*")
	UDPPeer.set_dest_address("192.168.0.101", 240)
	input_thread = Thread.new()
	input_thread.start(self, "thr_network_inputs", null, 2) #2: high priority
	
	while(!input_received):#search for networked player (block until networked player is found)
		UDPPeer.put_packet(PoolByteArray([2])) #send ready handshake to opponent
		print("SENDING HANDSHAKE")


func _physics_process(delta):
	#print("Starting relative frame: ", frame_num)
	input_received_mutex.lock()
	if (input_received):
		#if the oldest Frame_State is guessed, but the input_queue Input does not (yet) contain an actual input for the oldest Frame_State's frame
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
		#print("Waiting for Input to fulfill oldest Frame_State (need to fulfill guessed state on frame: " + str(state_queue[0].frame) + ")") #block, can remove
#		print("SENDING REQUEST FOR FRAMES ", state_queue[0].frame, " to ", frame_num)
		UDPPeer.put_packet(PoolByteArray([1, state_queue[0].frame, frame_num])) #send request for needed input
	


func handle_input(): #get input, run rollback if necessary, implement inputs
	var pre_game_state = game_state.duplicate(true) #deep duplicate game_state of previous frame as pre_game_state
#	print("handle_input start pre_game_state: ", pre_game_state)
	var actual_input = true
	var start_rollback = false
	
#	##########
	#Frame_State manipulation and Input implementation, Rollback
#	##########
	var current_input = null
	
	###
	#print("input_arrival_array:")
	#print(input_arrival_array)
	#print("prev_frame_arrival_array:")
	#print(prev_frame_arrival_array)
	###
	var current_frame_arrival_array = []
	
	#print("current_frame_arrival_array.push_front (oldest first)")
	
	var local_input = {'W': false, 'A': false, 'S': false, 'D': false, 'SPACE': false}
	
#	#print("CHILDREN: " )
#	for child in get_children():
#		#print(child.name)
	
	frame_start_all() #set update vars to current actual vars for all children
	
	input_array_mutex.lock()
	#record local inputs
	if Input.is_key_pressed(KEY_W):
		local_input['W'] = true
#		#print("local_input['W']" + str(local_input['W']))
	if Input.is_key_pressed(KEY_A):
		local_input['A'] = true
#		#print("local_input['A']" + str(local_input['A']))
	if Input.is_key_pressed(KEY_S):
		local_input['S'] = true
#		#print("local_input['S']" + str(local_input['S']))
	if Input.is_key_pressed(KEY_D):
		local_input['D'] = true
#		#print("local_input['D']" + str(local_input['D']))
	if Input.is_key_pressed(KEY_SPACE):
		local_input['SPACE'] = true
#		#print("local_input['SPACE']" + str(local_input['SPACE']))
	input_array[frame_num].local_input = local_input
	
#	if (false):#for testing rollback and requests
	for i in dup_send_range + 1: #send inputs for current frame as well as duplicates of past frame inputs
		UDPPeer.put_packet(PoolByteArray([0, frame_num - i,
				input_array[frame_num - i].local_input['W'], 
				input_array[frame_num - i].local_input['A'],
				input_array[frame_num - i].local_input['S'],
				input_array[frame_num - i].local_input['D'],
				input_array[frame_num - i].local_input['SPACE']]))
	
	#get current input arrival values for current frame & old frames eligible for rollback
	for i in range(0, rollback + 1): 
		current_frame_arrival_array.push_front(input_arrival_array[frame_num - i]) #oldest frame in front
		#print("Frame: " + str(fposmod(frame_num - i, 256)) + ", value: " + str(input_arrival_array[frame_num - i]))
	input_array_mutex.unlock()
	
#	print("current_frame_arrival_array (before pop):")
#	print(current_frame_arrival_array)
	
	var current_frame_arrival = current_frame_arrival_array.pop_back() #remove current frame's arrival boolean for rollback condition comparison
	
#	print("current_frame_arrival_array (after pop):")
#	print(current_frame_arrival_array)
#	print("prev_frame_arrival_array:")
#	print(prev_frame_arrival_array)
	
	if current_frame_arrival_array.hash() != prev_frame_arrival_array.hash(): #if an old input has newly arrived (to fulfill a guess),
		#print("Rollback...")
		#iterate through all saved states until the state with the guessed input to be replaced is found to start rollback resimulation
		#then, continue iterating through remaining saved states to continue rollback resimulation  process
		var state_index = 0 #for tracking iterated element's index in state_queue
		for i in state_queue: #index 0 is oldest state
			#if an arrived input is for a past frame
			if (prev_frame_arrival_array[state_index] == false && current_frame_arrival_array[state_index] == true):
				i.net_input = input_array[i.frame].net_input #set input in Frame_State from guess to true actual input
				i.actual_input = true #input has been set from guess to actual input
				if start_rollback == false:
					game_state = i.game_state #set value of game_state to old state for rollback resimulation of states/inputs
					reset_state_all(game_state) #reset update variables for all children to match given state ONCE
					start_rollback = true
				pre_game_state = get_game_state()
				update_all(input_array[i.frame]) #update game_state using new input
#				print("ROLLBACK: GUESS TO ACTUAL INPUT UPDATE with state of frame " + str(i.frame))
			
			#otherwise, continue simulating using currently stored input
			else:
				if start_rollback == true:
					pre_game_state = get_game_state() #save pre-update game_state value for Frame_State
					update_all(input_array[i.frame]) #update game_state using old (guessed or actual) input during rollback resimulation 
#					#print("ROLLBACK: CURRENTLY REGISTERED UPDATE with state of frame " + str(i.frame))
			
			if start_rollback == true:
				i.game_state = pre_game_state #update Frame_States with updated game_state value.
#				print("After one Rollback iteration of Frame_States: Frame num of state is: " + str(i.frame) +  ", update PR-game_state for state is: " + str(pre_game_state) + ", current game_state at rollback iter end is: " + str(get_game_state())) # + ", Input for state is: " +)
			state_index += 1
			
	current_frame_arrival_array.push_back(current_frame_arrival) #reinsert current frame's arrival boolean (for next frame's prev_frame_arrival_array)
	current_frame_arrival_array.pop_front() #remove oldest frame's arrival boolean (needed for rollback condition comparison, but unwanted for next frame's prev_frame_arrival_array)
	
	
	input_array_mutex.lock()
#	if current_frame_arrival == false: #if the input for the current frame has not been received, ##############
	if input_arrival_array[frame_num] == false:
		#implement guess of empty input
		current_input = Inputs.new()
		current_input.local_input = input_array[frame_num].local_input.duplicate(true)
		input_array[frame_num].net_input = current_input.net_input #.duplcate(true)
		
		#implement guess of last frame's input
		#should be adaptive, only copying the last true input as of the current frame
#		if (input_arrival_array[frame_num - 1]): #condition here
#			input_array[frame_num].net_input = input_array[frame_num - 1].net_input.duplicate(true)
#			current_input = input_array[frame_num]
#		else:
#			current_input = Inputs.new()
#			current_input.local_input = input_array[frame_num].local_input.duplicate(true)
#			input_array[frame_num].net_input = current_input.net_input #.duplcate(true)
		
		actual_input = false
	else: #else (if the input for the current frame has been received), proceed with true, actual input
		current_input = input_array[frame_num]
	input_array_mutex.unlock()

	if start_rollback == true:
		pre_game_state = get_game_state() #cause of jitter/teleport bug?
		
	update_all(current_input) #update with current input
	execute_all() #implement all applied updates/inputs to all child objects
	
	#store current frame state into queue
	state_queue.append(Frame_State.new(input_array[frame_num].local_input, current_input.net_input, frame_num, pre_game_state, actual_input))
	
	#print("New state appended is: " + str(state_queue[state_queue.size() - 1]))
	
	#remove oldest state from queue if queue has exceeded size limit
	if len(state_queue) > rollback:
		state_queue.pop_front()
	
#	print("End of Frame: " + str(frame_num) + "\t\tgame_state: " + str(get_game_state()))
#	print("End of Frame: " + str(state_queue[rollback - 1].frame) + "\t\tlast state_queue game_state: " + str(state_queue[rollback - 1].game_state) + "\n\n")
	
	get_game_state() #store game_state after execution to initialize pre_game_state for next frame
	prev_frame_arrival_array = current_frame_arrival_array #store current input arrival array for comaparisons in next frame
	input_arrival_array[frame_num - rollback*3] = false #reset input arrival boolean for discarded old Frame_State's frame
	frame_num = (frame_num + 1)%256 #increment frame_num


func frame_start_all():
	for child in get_children():
		if child.name != "timer":
			child.frame_start()


func reset_state_all(game_state):
	for child in get_children():
		child.reset_state(game_state)


func update_all(input):
	for child in get_children():
		child.update(input)


func execute_all():
	for child in get_children():
		child.execute()


func get_game_state():
	var state = {}
	for child in get_children():
		state[child.name] = child.get_state()
	game_state = state
	return game_state.duplicate(true) #deep duplicate to copy all nested dictionaries by value instead of by reference
	
