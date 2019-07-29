 extends Node

#amount of input delay in frames
const input_delay = 5
#amount of artificial "network" delay for effective inputs (for rollback)
const net_delay = 4
#number of frame states to save in order to implement rollback (max amount of frames able to rollback)
const rollback = 7

var input_queue = [] #queue for inputs
var state_queue = [] #queue for states at passed frames (for rollback)

var frame_num = 0
var counter = 0

#flag to detect if new inputs have been received
var input_received

#testing thread vars for receiving inputs
var input_thread
var testframe = input_delay

class Inputs:
	var inp
	var target_frame
	
	func _init(_inp, _target_frame):
		#the input registered at the frame
		self.inp = _inp
		#the target frame to implement the input
		self.target_frame = _target_frame

class Frame_State:
	var inp
	var frame
	var counter
	var actual_input
	
	func _init(_inp, _frame, _counter, _actual_input):
		#the input registered at the frame
		self.inp = _inp
		#the frame when this input/state occured
		self.frame = _frame
		#value of counter at the frame BEFORE the inputs at this frame are implemented
		self.counter = _counter
		#boolean, whether the state contains guessed input (false) or actual input (true)
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
		if input_queue.size() < 9:
			testframe += 1
			if testframe % 12 == 0:
				input_queue.append(Inputs.new(2, testframe))
			else:
				input_queue.append(Inputs.new(null, testframe))
			input_received = true
			#print("Size of input_queue is: " + str(input_queue.size()))
			
	pass

static func input_sort(a:Inputs, b:Inputs) -> bool:
	if a.target_frame < b.target_frame:
		return true
	return false
	

func _ready():
	#initialize input and state queue buffers
	for x in range (0, input_delay):
		input_queue.append(Inputs.new(null, frame_num + x + 1)) 
	for x in range (0, rollback):
		state_queue.append(Frame_State.new(null, frame_num, counter, true))
		
	#create separate thread to receive inputs from network
	input_thread = Thread.new()
	input_thread.start(self, "thr_network_inputs", null, 2)
	input_received = true
	
	#frame_num = 1

func _physics_process(delta):
	#var block_for_input = true
	#while (block_for_input):
	if (input_received):
		#Input queue sorts, checks if there are any inputs whose targets are lower than current frame
		input_queue.sort_custom(self, "input_sort") #sort input_queue Inputs by target_frame attribute
		print("Size of state_queue is: " + str(state_queue.size()))
		for i in state_queue:
			print("State for frame :" + str (i.frame) + ", counter is : " +  str (i.counter) + ", input is : " +  str (i.inp) + ", Guess? " + str(!i.actual_input))
		print("Sorted input_queue:")
		for x in input_queue:
			print("Target Frame: " + str(x.target_frame)+ "\t\t Input: " + str(x.inp))
			
		#if the oldest Frame_State is guessed, but the input_queue is empty or does not contain an actual input for the oldest Frame_State
		if state_queue[0].actual_input == false && (input_queue.size() == 0 || input_queue[0].target_frame != state_queue[0].frame):
			#block until actual input is received for guessed oldest Frame_State
			input_received = false
			return
	
		handle_input()
	else:
		print("Waiting for Input to fulfill oldest Frame_State (need to fulfill guessed state")
	pass

	
func handle_input():
	frame_num += 1
	
	var pre_counter = counter
	var actual_input = true
	var start_rollback = false
	
	##########
	#Frame_State manipulation and Input implementation, Rollback
	##########
	var current_input = null
	#if queue is empty or queued inputs are for future frames
	if input_queue.size() == 0 or input_queue[0].target_frame > frame_num: 
		#implement guess (guess null)
		current_input = Inputs.new(null, frame_num)
		actual_input = false
	#elif target frame is a PAST frame (###ROLLBACK###)
	elif (input_queue[0].target_frame < frame_num):
		print("Rollback...")
		#var start_rollback = false
		#var pre_roll_counter
		#iterate through all saved states until the state with the guessed input to be replaced is found to start rollback resimulation
		#then, continue iterating through remaining saved states to continue rollback resimulation  process
		for i in state_queue: #index 0 is oldest state
			#if an input in queue targets the iterated PAST frame
			if (input_queue.size() > 0 && input_queue[0].target_frame == i.frame):
				i.inp = input_queue[0].inp #set input in Frame_State from guess to true actual input
				i.actual_input = true #input has been set from guess to actual input
				if start_rollback == false:
					#pre_counter = i.counter	#set value of pr_counter to old value in order to preserve pre-rollback counter value for that Frame_State
					counter = i.counter			#set value of counter to old value once for rollback resimulation of states/inputs
					start_rollback = true
				pre_counter = counter
				update_all(input_queue.pop_front()) #update counter using new input, discard input
			#otherwise, continue simulating using currently stored input
			else:
				if start_rollback == true:
					pre_counter = counter		#save pre-update counter value for Frame_State
					update_all(Inputs.new(i.inp, i.frame)) #update counter using old (guessed or actual) input during rollback resimulation 
			
			if start_rollback == true:
				i.counter = pre_counter #update Frame_States with updated counter value.
				print("After one Rollback iteration of Frame_States: Frame num of state is: " + str(i.frame) +  ", update PR-Counter for state is: " + str(pre_counter) + ", current Counter at rollback iter end is: " + str(counter) + ", Input for state is: " + str(i.inp))

	#if queue is empty or queued inputs are for future frames (initially, queue only contained past frames or contained only past and future frames)
	#if no Rollback, this action is UNNECESSARILY REPEATED (use start_rollback as cond?)
	if input_queue.size() == 0 or input_queue[0].target_frame > frame_num: 
		#implement guess (guess null)
		current_input = Inputs.new(null, frame_num)
		actual_input = false
		
	#if target frame is current frame (post rollback or without rollback)    
	elif (input_queue[0].target_frame == frame_num): 
		current_input = input_queue.pop_front()
		
	#implement current input (guess or real input)
	if start_rollback == true:
		pre_counter = counter
	update_all(current_input) 
	
	
	#store current frame state into queue
	state_queue.append(Frame_State.new(current_input.inp, frame_num, pre_counter, actual_input))
	
	#remove oldest state from queue if queue has exceeded size limit
	if len(state_queue) > rollback:
		state_queue.pop_front()
	
	
	print("Frame: " + str(frame_num) + "\t\tCounter: " + str(counter) + "\n\n")
	
	pass

func update_all(input):
	if (input.inp != null):
		counter = counter/input.inp
	else:
		counter += 1
	pass