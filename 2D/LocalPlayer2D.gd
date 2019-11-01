extends KinematicBody2D

var counter = -1  #test value for checking if rollback and saving states is working properly
var updateX = null
var updateY = null
var updateCounter = null

func _ready():
	updateX = position.x
	updateY = position.y
	updateCounter = counter


func reset_state(game_state):
	if game_state.has(name):
		updateX = game_state[name]['x']
		updateY = game_state[name]['y']
		updateCounter = game_state[name]['counter']
	#check if this object exists within the loaded game_state
	else:
		free() #delete from memory


func frame_start():
	#set update vars to current values
	updateX = position.x
	updateY = position.y
	updateCounter = counter


func input_update(input):
	#calculate state of object for the current frame
	if input.local_input['W']:
		updateY -= 7
		
	if input.local_input['A']:
		updateX -= 7
		
	if input.local_input['S']:
		updateY += 7
		
	if input.local_input['D']:
		updateX += 7
		
	if !input.local_input['SPACE']:
		updateCounter += 1
	else:
		updateCounter = updateCounter/2


func input_execute():
	#execute calculated state of object for current frame
	set_position(Vector2(updateX, updateY))
	counter = updateCounter


func get_state():
	#return dict of relevant state variables to be stored in Frame_States
	return {'x': updateX, 'y': updateY, 'counter': updateCounter}