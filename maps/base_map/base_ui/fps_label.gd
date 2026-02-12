extends Label

var fps

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	fps = Engine.get_frames_per_second()
	text = "FPS: " + str(fps)
