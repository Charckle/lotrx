extends Panel

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


func _on_music_enable_button_toggled(toggled_on):
	var music_player = get_tree().root.get_node("MusicPlayer")
	
	if toggled_on == true:
		GlobalSettings.global_options["audio"]["music_active"] = true
		music_player.play()
	else:
		GlobalSettings.global_options["audio"]["music_active"] = false
		music_player.stop()


func _on_agression_range_button_toggled(toggled_on):
	if toggled_on == true:
		GlobalSettings.global_options["gameplay"]["agression_rage"] = true
	else:
		GlobalSettings.global_options["gameplay"]["agression_rage"] = false


func _on_attack_range_button_toggled(toggled_on):
	if toggled_on == true:
		GlobalSettings.global_options["gameplay"]["attack_rage"] = true
	else:
		GlobalSettings.global_options["gameplay"]["attack_rage"] = false


func _on_show_ai_poi_button_toggled(toggled_on):
	if toggled_on == true:
		GlobalSettings.global_options["gameplay"]["show_ai_POI"] = true
	else:
		GlobalSettings.global_options["gameplay"]["show_ai_POI"] = false


func _on_show_weather_toggled(toggled_on):
	if toggled_on == true:
		GlobalSettings.global_options["video"]["weather_show"] = true
	else:
		GlobalSettings.global_options["video"]["weather_show"] = false
