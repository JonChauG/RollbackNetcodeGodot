extends "res://3D/LocalPlayer3D.gd"

func input_update(input):
	#calculate state of object for the current frame
	if input.net_input['W']:
		updateZ += 0.5
		
	if input.net_input['A']:
		updateX += 0.5
		
	if input.net_input['S']:
		updateZ -= 0.5
		
	if input.net_input['D']:
		updateX -= 0.5
		
	if !input.net_input['SPACE']:
		updateCounter += 1
	else:
		updateCounter = updateCounter/2