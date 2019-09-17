extends KinematicBody
#local_input = {'W': false, 'A': false, 'S': false, 'D': false, 'SPACE': false}

var updateX
var updateY
var updateZ

func _ready():
	#get initial position (safety/redundant)
#	updateX = translation.x
#	updateY = translation.y
#	updateZ = translation.z
##	updateX = 0
##	updateY = 0
##	updateZ = 0
	pass


func reset_state(game_state):
#	#simulate starting at a given state (for rollback)
#	if game_state.has(name):
#		updateX = game_state[name]['x']
#		updateY = game_state[name]['y']
#		updateZ = game_state[name]['z']
#	#check if self exists(look at keys of state dictionary/JSON)?
#	else:
#		free() #delete from memory
	pass

func frame_start():
	#set update vars to current values
#	updateX = translation.x
#	updateY = translation.y
#	updateZ = translation.z
##	updateX = 0
##	updateY = 0
##	updateZ = 0
	pass

func update(input):
	#calculate state of object for the current frame
#	if input.local_input['W']:
##		updateY += 2
#		updateY -= 2
#	if input.local_input['A']:
##		updateX -= 2
#		updateX -=2
#	if input.local_input['S']:
##		updateY -= 2
#		updateY += 2
#	if input.local_input['D']:
##		updateX += 2
#		updateX += 2
	pass

func execute():
	#execute calculated state of object for current frame
#	to_global(Vector3(updateX, updateY, updateZ))
	#test_move
	pass
	

func get_state():
	#return dict of relevant state variables to be stored in Frame_States
	return {'x': translation.x, 'y': translation.y, 'z': translation.z}