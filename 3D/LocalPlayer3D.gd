#No rollback with collision simulation implemented in 3D!
extends KinematicBody

var counter = -1
var updateX
var updateY
var updateZ
var updateCounter

func _ready():
	updateX = translation.x
	updateY = translation.y
	updateZ = translation.z
	updateCounter = counter


func reset_state(game_state):
	if game_state.has(name):
		updateX = game_state[name]['x']
		updateY = game_state[name]['y']
		updateZ = game_state[name]['z']
		updateCounter = game_state[name]['counter']
	#check if this object exists within the loaded game_state
	else:
		free() #delete from memory


func frame_start():
	#set update vars to current values
	updateX = translation.x
	updateY = translation.y
	updateZ = translation.z
	updateCounter = counter


func input_update(input):
	#calculate state of object for the current frame
	if input.local_input['W']:
		updateZ -= 0.5
		
	if input.local_input['A']:
		updateX -= 0.5
		
	if input.local_input['S']:
		updateZ += 0.5
		
	if input.local_input['D']:
		updateX += 0.5
		
	if !input.local_input['SPACE']:
		updateCounter += 1
	else:
		updateCounter = updateCounter/2


func input_execute():
	#execute calculated state of object for current frame
	set_translation(Vector3(updateX, updateY, updateZ))


func get_state():
	#return dict of relevant state variables to be stored in Frame_States
	return {'x': updateX, 'y': updateY, 'z': updateZ, 'counter': updateCounter}