#By Jon Chau
#Note: imperfect example: desync may occur, possibly due to differing collision checks for either player
extends KinematicBody

var counter = -1 #test value for checking if rollback and saving states is working properly
var updateCounter = null
var height = null
var radius = null
var collisionMaskXY = null
var collisionMaskXZ = null
var label = null

func _ready():
	updateCounter = counter
	height = get_node("CollisionShape").shape.get_height() #assuming constant capsule CollisionShape
	radius = get_node("CollisionShape").shape.get_radius() #assuming constant capsule CollisionShape
	collisionMaskXY = Rect2(Vector2(translation.x - radius, translation.y - height), Vector2(radius, height) * 2)
	collisionMaskXZ = Rect2(Vector2(translation.x - radius, translation.z - radius), Vector2(radius, radius) * 2)


func reset_state(game_state):
	if game_state.has(name):
		#set xyz to state's saved position directly
		translation.x = game_state[name]['x']
		translation.y = game_state[name]['y']
		translation.z = game_state[name]['z']
		updateCounter = game_state[name]['counter']
		collisionMaskXY = game_state[name]['collisionMaskXY']
		collisionMaskXZ = game_state[name]['collisionMaskXZ']
	#check if this object exists within the loaded game_state
	else:
		free() #delete from memory


func frame_start():
	#set update vars to current values
	updateCounter = counter
	collisionMaskXY = Rect2(Vector2(translation.x - radius, translation.y - height), Vector2(radius, height) * 2)
	collisionMaskXZ = Rect2(Vector2(translation.x - radius, translation.z - radius), Vector2(radius, radius) * 2)


func input_update(input, game_state):
	#calculate state of object for the current frame
	var vect = Vector3(0, -0.05, 0)

	#Rect2 intersection for moving objects that can pass through
	for sibling in game_state:
		if sibling != name:
			if collisionMaskXZ.intersects(game_state[sibling]['collisionMaskXZ']) && collisionMaskXY.intersects(game_state[sibling]['collisionMaskXY']):
				updateCounter += 1
#				print("LocalPlayer) Rect2 intersection! counter is: " + str(counter) + ", updateCounter is: " + str(updateCounter))


	if input.local_input[0]: #W
		vect.z -= 0.2
		
	if input.local_input[1]: #A
		vect.x -= 0.2
		
	if input.local_input[2]: #S
		vect.z += 0.2
		
	if input.local_input[3]: #D
		vect.x += 0.2
		
	if input.local_input[4]: #SPACE
		updateCounter = updateCounter/2

	#move_and_collide for "solid" stationary objects
	var collision = move_and_collide(vect)
	if collision:
		vect = vect.slide(collision.normal)
		move_and_collide(vect)
	
	collisionMaskXY = Rect2(Vector2(translation.x - radius, translation.y - height), Vector2(radius, height) * 2)
	collisionMaskXZ = Rect2(Vector2(translation.x - radius, translation.z - radius), Vector2(radius, radius) * 2)


func input_execute():
	#execute calculated state of object for current frame
	counter = updateCounter


func get_state():
	#return dict of relevant state variables to be stored in Frame_States
	return {'x': translation.x, 'y': translation.y, 'z': translation.z, 'counter': updateCounter, 'collisionMaskXY': collisionMaskXY, 'collisionMaskXZ': collisionMaskXZ}