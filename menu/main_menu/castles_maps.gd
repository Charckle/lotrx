extends Panel


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


func _on_attack_pressed_socerb():
	GlobalSettings.map_options = {
		"user_faction": 1,
		"ai_faction": 2}
	
	get_tree().change_scene_to_file("uid://dpq75kochn3i")


func _on_defend_pressed_socerb():
	GlobalSettings.map_options = {
		"user_faction": 2,
		"ai_faction": 1}
	
	get_tree().change_scene_to_file("uid://dpq75kochn3i")
