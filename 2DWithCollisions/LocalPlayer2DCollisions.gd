extends KinematicBody2D

var counter = -1  #test value for checking if rollback and saving states is working properly
var updateCounter = null
var rectExtents = null
var collisionMask = null
var label = null


func _ready():
	updateCounter = counter
	label = get_node("Label")
	rectExtents = get_node("CollisionShape2D").shape.get_extents() #assuming constant rectangle CollisionShape2D
	collisionMask = Rect2(Vector2(position.x - rectExtents.x, position.y - rectExtents.y), Vector2(rectExtents.x, rectExtents.y) * 2)

func reset_state(game_state):
	if game_state.has(name):
		#set x and y to state's saved position directly
		position.x = game_state[name]['x']
		position.y = game_state[name]['y']
		updateCounter = game_state[name]['counter']
		collisionMask = game_state[name]['collisionMask']
	#check if this object exists within the loaded game_state
	else:
		free() #delete from memory


func frame_start():
	#set update vars to current values
	updateCounter = counter
	collisionMask = Rect2(Vector2(position.x - rectExtents.x, position.y - rectExtents.y), Vector2(rectExtents.x, rectExtents.y) * 2)


func input_update(input, game_state):
	#calculate state of object for the current frame
	var vect = Vector2(0, 0)
	
	#Rect2 intersection for moving objects that can pass through
	for sibling in game_state:
		if sibling != name:
			if collisionMask.intersects(game_state[sibling]['collisionMask']):
				updateCounter += 1
#				print("LocalPlayer) Rect2 intersection! counter is: " + str(counter) + ", updateCounter is: " + str(updateCounter))
	
	if input.local_input['W']:
		vect.y -= 7
		
	if input.local_input['A']:
		vect.x -= 7
		
	if input.local_input['S']:
		vect.y += 7
		
	if input.local_input['D']:
		vect.x += 7
		
	if input.local_input['SPACE']:
		updateCounter = updateCounter/2

	#move_and_collide for "solid" stationary objects
	var collision = move_and_collide(vect)
	if collision:
		vect = vect.slide(collision.normal)
		move_and_collide(vect)
	
	collisionMask = Rect2(Vector2(position.x - rectExtents.x, position.y - rectExtents.y), Vector2(rectExtents.x, rectExtents.y) * 2)


func input_execute():
	#execute calculated state of object for current frame
	counter = updateCounter
	label.text = str(counter)
	


func get_state():
	#return dict of relevant state variables to be stored in Frame_States
	return {'x': position.x, 'y': position.y, 'counter': updateCounter, 'collisionMask': collisionMask}