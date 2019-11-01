extends "res://2DWithCollisions/LocalPlayer2DCollisions.gd"

func input_update(input, game_state):
	#calculate state of object for the current frame
	var vect = Vector2(0, 0)

	#Rect2 intersection for moving objects that can pass through
	for sibling in game_state:
		if sibling != name:
			if collisionMask.intersects(game_state[sibling]['collisionMask']):
				updateCounter += 1
				print("NetPlayer) Rect2 intersection! counter is: " + str(counter) + ", updateCounter is: " + str(updateCounter))

	if input.net_input['W']:
		vect.y += 7

	if input.net_input['A']:
		vect.x += 7

	if input.net_input['S']:
		vect.y -= 7

	if input.net_input['D']:
		vect.x -= 7

	if input.local_input['SPACE']:
		updateCounter = updateCounter/2

	#move_and_collide for "solid" stationary objects
	var collision = move_and_collide(vect)
	if collision:
		vect = vect.slide(collision.normal)
		move_and_collide(vect)

	collisionMask = Rect2(Vector2(position.x - rectExtents.x, position.y - rectExtents.y), Vector2(rectExtents.x, rectExtents.y) * 2)