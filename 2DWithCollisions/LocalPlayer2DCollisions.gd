extends KinematicBody2D

var counter = -1  #test value for checking if rollback and saving states is working properly
var updateCounter = null

func _ready():
	updateCounter = counter


func reset_state(game_state):
	if game_state.has(name):
		#set x and y to state's saved position directly
		position.x = game_state[name]['x']
		position.y = game_state[name]['y']
		updateCounter = game_state[name]['counter']
	#check if this object exists within the loaded game_state
	else:
		free() #delete from memory


func frame_start():
	#set update vars to current values
	updateCounter = counter


func input_update(input):
	#calculate state of object for the current frame
	var vect = Vector2(0, 0)
	
	if input.local_input['W']:
		vect.y -= 7
		
	if input.local_input['A']:
		vect.x -= 7
		
	if input.local_input['S']:
		vect.y += 7
		
	if input.local_input['D']:
		vect.x += 7
		
	if !input.local_input['SPACE']:
		updateCounter += 1
	else:
		updateCounter = updateCounter/2
	
	var collision = move_and_collide(vect)
	if collision:
		vect = vect.slide(collision.normal)
		move_and_collide(vect)


func input_execute():
	#execute calculated state of object for current frame
	pass #state already calculated by move_and_collide


func get_state():
	#return dict of relevant state variables to be stored in Frame_States
	return {'x': position.x, 'y': position.y, 'counter': updateCounter}