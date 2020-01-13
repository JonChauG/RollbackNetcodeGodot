#By Jon Chau
extends "res://3D/LocalPlayer3D.gd"

func input_update(input):
	#calculate state of object for the current frame
	if input.net_input[0]: #W
		updateZ += 0.5
		
	if input.net_input[1]: #A
		updateX += 0.5
		
	if input.net_input[2]: #S
		updateZ -= 0.5
		
	if input.net_input[3]: #D
		updateX -= 0.5
		
	if !input.net_input[4]: #SPACE
		updateCounter += 1
	else:
		updateCounter = updateCounter/2