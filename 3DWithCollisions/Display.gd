extends Spatial

var localPlayer = null
var netPlayer = null
var localLabel = null
var netLabel = null
var camera = null

func _ready():
	localPlayer = get_node("InputControl/LocalPlayer")
	netPlayer = get_node("InputControl/NetPlayer")
	localLabel = get_node("Display/LocalLabel")
	netLabel = get_node("Display/NetLabel")
	camera = get_node("Camera")

	#var offset = Vector2(label.get_size().width/2, 0)

# warning-ignore:unused_argument
func _process(delta):
	localLabel.text = str(localPlayer.counter)
	netLabel.text = str(netPlayer.counter)
	localLabel.set_position(camera.unproject_position(localPlayer.get_translation()))
	netLabel.set_position(camera.unproject_position(netPlayer.get_translation()))