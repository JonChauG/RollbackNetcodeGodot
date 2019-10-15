extends "res://2DWithCollisions/LocalPlayer2DCollisions.gd"

func input_update(input):
	#calculate state of object for the current frame
	var vect = Vector2(0, 0)
	
	if input.net_input['W']:
		vect.y += 7
		
	if input.net_input['A']:
		vect.x += 7
		
	if input.net_input['S']:
		vect.y -= 7
		
	if input.net_input['D']:
		vect.x -= 7
		
	if !input.net_input['SPACE']:
		updateCounter += 1
	else:
		updateCounter = updateCounter/2
	
	var collision = move_and_collide(vect)
	if collision:
		vect = vect.slide(collision.normal)
		move_and_collide(vect)