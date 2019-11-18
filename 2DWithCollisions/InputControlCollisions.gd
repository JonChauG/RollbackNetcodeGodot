  extends "res://InputControl.gd"

func handle_input(): #get input, run rollback if necessary, implement inputs
	var pre_game_state = get_game_state()
#	print("handle_input start pre_game_state: ", pre_game_state)
	var actual_input = true
	var start_rollback = false
	
	var current_input = null
	var current_frame_arrival_array = []

	var local_input = {'W': false, 'A': false, 'S': false, 'D': false, 'SPACE': false}
	var encoded_local_input = 0
	
	frame_start_all() #for all children, set their update vars to their current/actual values
	
	input_array_mutex.lock()
	#record local inputs
	if Input.is_key_pressed(KEY_W):
		local_input['W'] = true
		encoded_local_input += 1
	if Input.is_key_pressed(KEY_A):
		local_input['A'] = true
		encoded_local_input += 2
	if Input.is_key_pressed(KEY_S):
		local_input['S'] = true
		encoded_local_input +=4
	if Input.is_key_pressed(KEY_D):
		local_input['D'] = true
		encoded_local_input += 8
	if Input.is_key_pressed(KEY_SPACE):
		local_input['SPACE'] = true
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
	
	if current_frame_arrival_array.hash() != prev_frame_arrival_array.hash(): #if an input for an past fram has arrived (to fulfill a guess),
		#print("Rollback...")
		#iterate through all saved states until the state with the guessed input to be replaced by arrived actual input is found (rollback will begin with that state)
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
				update_all_with_state(input_array[i.frame], pre_game_state) #update game_state using new input
			#otherwise, continue simulating using currently stored input
			else:
				if start_rollback == true:
					pre_game_state = get_game_state() #save pre-update game_state value for Frame_State
					update_all_with_state(input_array[i.frame], pre_game_state) #update game_state using old (guessed or actual) input during rollback resimulation 			
			if start_rollback == true:
				i.game_state = pre_game_state #update Frame_States with updated game_state value.
			state_index += 1
			
	current_frame_arrival_array.push_back(current_frame_arrival) #reinsert current frame's arrival boolean (for next frame's prev_frame_arrival_array)
	current_frame_arrival_array.pop_front() #remove oldest frame's arrival boolean (needed for rollback condition comparison, but unwanted for next frame's prev_frame_arrival_array)
	
	input_array_mutex.lock()
	#if the input for the current frame has not been received
	if input_arrival_array[frame_num] == false:
		current_input = Inputs.new()
		
		#implement guess of empty input (can be replaced with input-guessing algorithm)
		current_input.local_input = input_array[frame_num].local_input.duplicate()
		input_array[frame_num].net_input = current_input.net_input

		#implement guess of last input used
#		current_input.local_input = input_array[frame_num].local_input.duplicate()
#		input_array[frame_num].net_input = input_array[frame_num - 1].net_input.duplicate()
#		current_input.net_input = input_array[frame_num].net_input
		
		actual_input = false
	else: #else (if the input for the current frame has been received), proceed with true, actual input
		current_input = input_array[frame_num]
	
	input_arrival_array[frame_num - (rollback + 120)] = false #reset input arrival boolean for old frame
	input_array_mutex.unlock()
	
	input_local_saved_array_mutex.lock()
	input_local_saved_array[frame_num - (rollback + 120)] = false #reset viable local input boolean
	input_local_saved_array_mutex.unlock()

	if start_rollback == true:
		pre_game_state = get_game_state()
		
	update_all_with_state(current_input, pre_game_state) #update with current input
	execute_all() #implement all applied updates/inputs to all child objects
	
	#store current frame state into queue
	state_queue.append(Frame_State.new(input_array[frame_num].local_input, current_input.net_input, frame_num, pre_game_state, actual_input))
	
	#remove oldest state from queue if queue has exceeded size limit
	if len(state_queue) > rollback:
		state_queue.pop_front()

	prev_frame_arrival_array = current_frame_arrival_array #store current input arrival array for comaparisons in next frame
	frame_num = (frame_num + 1)%256 #increment frame_num


func update_all_with_state(input, game_state):
	for child in get_children():
		child.input_update(input, game_state)