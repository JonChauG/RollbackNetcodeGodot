extends "res://2D/LocalPlayer2D.gd"

func input_update(input):
	#calculate state of object for the current frame
	if input.net_input['W']:
		updateY += 7
		
	if input.net_input['A']:
		updateX += 7
		
	if input.net_input['S']:
		updateY -= 7
		
	if input.net_input['D']:
		updateX -= 7
		
	if !input.net_input['SPACE']:
		updateCounter += 1
	else:
		updateCounter = updateCounter/2