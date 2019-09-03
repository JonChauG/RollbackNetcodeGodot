extends Node

export var input_delay = 5 #amount of input delay in frames
export var net_delay = 4 #amount of artificial "network" delay for effective inputs (for rollback TESTING)
export var rollback = 7 #number of frame states to save in order to implement rollback (max amount of frames able to rollback)

var input_array = [] #array for inputs
var state_queue = [] #queue for states at passed frames (for rollback)
var input_arrival_array = [] #boolean array to determine if inputs have arrived, can replace input_arrival_array?
var prev_frame_arrival_array = []

var input_array_mutex = Mutex.new()

var frame_num = 0 #ranges between 0-255 per circular input array cycle (cycle is every 256 frames
var game_state = -1 #test value

var input_received #boolean to detect if new inputs have been received, set to true by networking thread, set to false by main when waiting on input

#testing thread vars for receiving inputs
var input_thread
var testframe = 0


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


func thr_network_inputs(userdata = null):
	#get inputs from network
	var t = Timer.new()
	t.set_wait_time(0.2)
	self.add_child(t)
	t.start()
	
	while(true):
		yield(t, "timeout")
		print("Timer Yield: testing Thread has released Inputs")
		input_array_mutex.lock()
		if testframe % 12 == 0:
			#####if input is within rollback and input_arrival_array[testframe] is currently set to false SET LATER IN ACTUAL NETWORKING THREAD
			input_array[testframe].net_input =  {'W': true, 'A': true, 'S': true, 'D': true, 'SPACE': true}
			input_arrival_array[testframe] = true
		else:
			input_array[testframe].net_input =  {'W': true, 'A': false, 'S': false, 'D': false, 'SPACE': false}
			input_arrival_array[testframe] = true
		input_array_mutex.unlock()
		testframe = (testframe + 1)%256
		input_received = true


#static func input_sort(a:Inputs, b:Inputs) -> bool:
#	if a.target_frame < b.target_frame:
#		return true
#	return false


func _ready():
	#initialize input array
	for x in range (0, 256):
		input_array.append(Inputs.new()) 
	
	#initialize state queue
	for x in range (0, rollback):
		state_queue.append(Frame_State.new({}, {}, 0, {}, true)) #empty inputs, frame 0, empty game state, actual input
	 
	#initialize arrived input array
	for i in range (0, 256):
		input_arrival_array.append(false)
	
	for i in range (1, rollback + 1):
		prev_frame_arrival_array.append(true)
		input_arrival_array[-i] = true #pretend all "previous" inputs arrived for initialization
	
	#create separate thread to receive inputs from network (testing)
	input_thread = Thread.new()
	input_thread.start(self, "thr_network_inputs", null, 2)
	input_received = true


func _physics_process(delta):
	print("Starting relative frame: " + str(frame_num))
	if (input_received):
		
		###
		print("Size of state_queue is: " + str(state_queue.size()))
		for i in state_queue:
			print("**State for frame :" + str (i.frame) + ", game_state is : " +  str (i.game_state))
			print("local input is : " +  str(i.local_input))
			print("net input is : " +  str(i.net_input))
			print("actual input? " + str(i.actual_input))
		
		print("INPUTS:")
		for i in range((frame_num - 10), (frame_num + 10)): #fposmod for printing purposes only, Godot takes negative array indexes
			if fposmod(i, 256) == frame_num:
				print("CURRENT")
			print("FRAME: " + str(fposmod(i, 256)) + "\nlocal_input: " + str(input_array[i].local_input) + "\nnet_input: " + str(input_array[i].net_input))
		###
		
		#if the oldest Frame_State is guessed, but the input_queue Input does not (yet) contain an actual input for the oldest Frame_State's frame
		if state_queue[0].actual_input == false && input_arrival_array[state_queue[0].frame] == false:
			input_received = false #block until actual input is received for guessed oldest Frame_State
			return

		handle_input()
	else:
		print("Waiting for Input to fulfill oldest Frame_State (need to fulfill guessed state on frame: )" + str(state_queue[0].frame)) #block, can remove
	pass


func handle_input():
	
	var pre_game_state = game_state
	var actual_input = true
	var start_rollback = false
	
	##########
	#Frame_State manipulation and Input implementation, Rollback
	##########
	var current_input = null
	
	###
	print("input_arrival_array:")
	print(input_arrival_array)
	print("prev_frame_arrival_array:")
	print(prev_frame_arrival_array)
	###
	var current_frame_arrival_array = []
	
	print("current_frame_arrival_array.push_front (oldest first)")
	input_array_mutex.lock()
	#get current input arrival values for current frame & old frames eligible for rollback (rollback + 1 cuz range stops (does not iterate) there)
	for i in range(0, rollback + 1): 
		current_frame_arrival_array.push_front(input_arrival_array[frame_num - i]) #oldest frame in front
		print("Frame: " + str(fposmod(frame_num - i, 256)) + ", value: " + str(input_arrival_array[frame_num - i]))
	input_array_mutex.unlock()
	
	var current_frame_arrival = current_frame_arrival_array.pop_back() #remove current frame's arrival boolean for rollback condition comparison
	
	print("current_frame_arrival_array:")
	print(current_frame_arrival_array)
	
	if current_frame_arrival_array.hash() != prev_frame_arrival_array.hash(): #if an old input has newly arrived (to fulfill a guess),
		print("Rollback...")
		#var start_rollback = false
		#var pre_roll_game_state
		#iterate through all saved states until the state with the guessed input to be replaced is found to start rollback resimulation
		#then, continue iterating through remaining saved states to continue rollback resimulation  process
		var state_index = 0
		for i in state_queue: #index 0 is oldest state
			#if an input in queue targets the iterated PAST frame
			if (prev_frame_arrival_array[state_index] == false && current_frame_arrival_array[state_index] == true):
				i.net_input = input_array[i.frame].net_input #set input in Frame_State from guess to true actual input
				i.actual_input = true #input has been set from guess to actual input
				if start_rollback == false:
					#pre_game_state = i.game_state	#set value of pr_game_state to old value in order to preserve pre-rollback game_state value for that Frame_State
					#start rolling back by beginning with saved game_state.
					game_state = i.game_state			#set value of game_state to old value once for rollback resimulation of states/inputs
					start_rollback = true
				pre_game_state = game_state
				update_all(input_array[i.frame]) #update game_state using new input, discard input
			#otherwise, continue simulating using currently stored input
			else:
				if start_rollback == true:
					pre_game_state = game_state		#save pre-update game_state value for Frame_State
					update_all(input_array[i.frame]) #update game_state using old (guessed or actual) input during rollback resimulation 
			
			if start_rollback == true:
				i.game_state = pre_game_state #update Frame_States with updated game_state value.
				print("After one Rollback iteration of Frame_States: Frame num of state is: " + str(i.frame) +  ", update PR-game_state for state is: " + str(pre_game_state) + ", current game_state at rollback iter end is: " + str(game_state)) # + ", Input for state is: " +)
			state_index += 1
			
	current_frame_arrival_array.push_back(current_frame_arrival) #reinsert current frame's arrival boolean (for next frame's prev_frame_arrival_array)
	current_frame_arrival_array.pop_front() #remove oldest frame's arrival boolean (needed for rollback condition comparison, but unwanted for next frame's prev_frame_arrival_array)

	#if the input for the current frame has not been received,
	if input_arrival_array[frame_num] == false:
		#implement guess (guess null)
		current_input = Inputs.new()
		current_input.local_input = input_array[frame_num].local_input
		actual_input = false
		
	#else (if the input for the current frame has been received)   
	else: 
		current_input = input_array[frame_num]
		
	#implement current input (guess or real input)
	if start_rollback == true:
		pre_game_state = game_state
	update_all(current_input)
	
	
	#store current frame state into queue
	state_queue.append(Frame_State.new(input_array[frame_num].local_input, current_input.net_input, frame_num, game_state, actual_input))
	
	#remove oldest state from queue if queue has exceeded size limit
	if len(state_queue) > rollback:
		state_queue.pop_front()
	
	print("End of Frame: " + str(frame_num) + "\t\tgame_state: " + str(game_state) + "\n\n")
	
	prev_frame_arrival_array = current_frame_arrival_array #store current input arrival array for comaparisons in next frame
	input_arrival_array[frame_num - rollback] = false #reset input arrival boolean for discarded old Frame_State's frame
	frame_num += 1


func update_all(input):
#	for child in get_children():
#		child.update(input)
	if (input.net_input["SPACE"]):
		game_state = game_state/2
	else:
		game_state += 1


func execute_all():
	for child in get_children():
		child.execute()
