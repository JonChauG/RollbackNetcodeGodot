#By Jon Chau
extends "res://2D/LocalPlayer2D.gd"

func input_update(input):
	#calculate state of object for the current frame
	if input.net_input[0]: #W
		updateY += 7
		
	if input.net_input[1]: #A
		updateX += 7
		
	if input.net_input[2]: #S
		updateY -= 7
		
	if input.net_input[3]: #D
		updateX -= 7
		
	if !input.net_input[4]: #SPACE
		updateCounter += 1
	else:
		updateCounter = updateCounter/2