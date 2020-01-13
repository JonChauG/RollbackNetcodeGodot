#By Jon Chau
#Note: imperfect example: desync may occur, possibly due to differing collision checks for either player
extends "res://3DWithCollisions/LocalPlayer3DCollisions.gd"

func input_update(input, game_state):
	#calculate state of object for the current frame
	var vect = Vector3(0, -0.05, 0)

	#Rect2 intersection for moving objects that can pass through
	for sibling in game_state:
		if sibling != name:
			if collisionMaskXZ.intersects(game_state[sibling]['collisionMaskXZ']) && collisionMaskXY.intersects(game_state[sibling]['collisionMaskXY']):
				updateCounter += 1
#				print("NetPlayer) Rect2 intersection! counter is: " + str(counter) + ", updateCounter is: " + str(updateCounter))


	if input.net_input[0]: #W
		vect.z += 0.2
		
	if input.net_input[1]: #A
		vect.x += 0.2
		
	if input.net_input[2]: #S
		vect.z -= 0.2
		
	if input.net_input[3]: #D
		vect.x -= 0.2
		
	if input.net_input[4]: #SPACE
		updateCounter = updateCounter/2

	#move_and_collide for "solid" stationary objects
	var collision = move_and_collide(vect)
	if collision:
		vect = vect.slide(collision.normal)
		move_and_collide(vect)
	
	collisionMaskXY = Rect2(Vector2(translation.x - radius, translation.y - height), Vector2(radius, height) * 2)
	collisionMaskXZ = Rect2(Vector2(translation.x - radius, translation.z - radius), Vector2(radius, radius) * 2)
