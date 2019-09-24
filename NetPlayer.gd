extends "res://LocalPlayer.gd"
#local_input = {'W': false, 'A': false, 'S': false, 'D': false, 'SPACE': false}

func update(input):
	#print("update input :" + str(input))
	#print("update input.local_input :" + str(input.local_input))
	#print("update input.local_input['W'] :" + str(input.local_input['W']))
	#print("pre-update, updateX: " + str(updateX))
	#print("pre-update, updateY: " + str(updateY))
	#print("pre-update, updateZ: " + str(updateZ))
	#print("pre-update, updateCounter: " + str(updateCounter))
	#calculate state of object for the current frame
	if input.net_input['W']:
#		updateY += 2
		#print("update input.local_input['W'] : PRESSED PRESSED PRESSED PRESSED PRESSED")
		updateZ += 0.5
		
	if input.net_input['A']:
#		updateX -= 2
		updateX += 0.5
		
	if input.net_input['S']:
#		updateY -= 2
		updateZ -= 0.5
		
	if input.net_input['D']:
#		updateX += 2
		updateX -= 0.5
		
	if !input.net_input['SPACE']:
		updateCounter += 1
	else:
		updateCounter = updateCounter/2
	#print("post-update, updateX: " + str(updateX))
	#print("post-update, updateY: " + str(updateY))
	#print("post-update, updateZ: " + str(updateZ))
	#print("post-update, updateCounter: " + str(updateCounter))