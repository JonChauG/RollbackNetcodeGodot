extends KinematicBody
#local_input = {'W': false, 'A': false, 'S': false, 'D': false, 'SPACE': false}

export var mute = false
var counter = -1
var updateX
var updateY
var updateZ
var updateCounter

func _ready():
	#get initial position (safety/redundant)
	updateX = translation.x
	updateY = translation.y
	updateZ = translation.z
	updateCounter = counter


func reset_state(game_state):
	#simulate starting at a given state (for rollback)
	#print("pre-reset_state, updateX: " + str(updateX))
	#print("pre-reset_state, updateY: " + str(updateY))
	#print("pre-reset_state, updateZ: " + str(updateZ))
	#print("pre-reset_state, updateCounter: " + str(updateCounter))
	if game_state.has(name):
		updateX = game_state[name]['x']
		updateY = game_state[name]['y']
		updateZ = game_state[name]['z']
		updateCounter = game_state[name]['counter']
	#check if self exists(look at keys of state dictionary/JSON)?
	else:
		free() #delete from memory


func frame_start():
	#set update vars to current values
	updateX = translation.x
	updateY = translation.y
	updateZ = translation.z
	updateCounter = counter
	#print("frame_start, updateX: " + str(updateX))
	#print("frame_start, updateY: " + str(updateY))
	#print("frame_start, updateZ: " + str(updateZ))
	#print("frame_start, updateCounter: " + str(updateCounter))
#	updateX = 0
#	updateY = 0
#	updateZ = 0


func update(input):
	#print("update input :" + str(input))
	#print("update input.local_input :" + str(input.local_input))
	#print("update input.local_input['W'] :" + str(input.local_input['W']))
	#print("pre-update, updateX: " + str(updateX))
	#print("pre-update, updateY: " + str(updateY))
	#print("pre-update, updateZ: " + str(updateZ))
	#print("pre-update, updateCounter: " + str(updateCounter))
	#calculate state of object for the current frame
	if input.local_input['W']:
#		updateY += 2
		#print("update input.local_input['W'] : PRESSED PRESSED PRESSED PRESSED PRESSED")
		updateZ -= 0.5
		
	if input.local_input['A']:
#		updateX -= 2
		updateX -= 0.5
		
	if input.local_input['S']:
#		updateY -= 2
		updateZ += 0.5
		
	if input.local_input['D']:
#		updateX += 2
		updateX += 0.5
		
	if !input.local_input['SPACE']:
		updateCounter += 1
	else:
		updateCounter = updateCounter/2
	#print("post-update, updateX: " + str(updateX))
	#print("post-update, updateY: " + str(updateY))
	#print("post-update, updateZ: " + str(updateZ))
	#print("post-update, updateCounter: " + str(updateCounter))


func execute():
	#print("pre-execute, updateX: " + str(updateX))
	#print("pre-execute, updateY: " + str(updateY))
	#print("pre-execute, updateZ: " + str(updateZ))
	#print("pre-execute, updateCounter: " + str(updateCounter))
	#execute calculated state of object for current frame
	set_translation(Vector3(updateX, updateY, updateZ))
	#print("post-execute, position: " + str(get_translation()))
	#print("post-execute, counter: " + str(counter))
	#test_move
	
	
	

func get_state():
	#return dict of relevant state variables to be stored in Frame_States
#	print("pre-get_state, updateX: " + str(updateX))
#	print("pre-get_state, updateY: " + str(updateY))
#	print("pre-get_state, updateZ: " + str(updateZ))
#	print("pre-get_state, updateCounter: " + str(updateCounter))
	return {'x': updateX, 'y': updateY, 'z': updateZ, 'counter': updateCounter}