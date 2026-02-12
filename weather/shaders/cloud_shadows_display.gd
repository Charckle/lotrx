extends Sprite2D

@onready var camera: Camera2D = get_tree().root.get_node("game").get_node("UI").get_node("camera")

func _process(_delta):
	# Follow the camera so the shadow overlay always covers the visible area
	global_position = camera.get_screen_center_position()
