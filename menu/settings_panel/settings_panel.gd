extends Panel

signal closed


func _ready():
	# Initialize toggle states from GlobalSettings without triggering signals
	$GridContainer/music_enable_button.set_pressed_no_signal(GlobalSettings.global_options["audio"]["music_active"])
	$GridContainer2/agression_range_button.set_pressed_no_signal(GlobalSettings.global_options["gameplay"]["agression_rage"])
	$GridContainer2/attack_range_button.set_pressed_no_signal(GlobalSettings.global_options["gameplay"]["attack_rage"])
	$GridContainer2/show_ai_poi_button.set_pressed_no_signal(GlobalSettings.global_options["gameplay"]["show_ai_POI"])
	$GridContainer3/show_weather.set_pressed_no_signal(GlobalSettings.global_options["video"]["weather_show"])


func _on_music_enable_button_toggled(toggled_on):
	var music_player = get_tree().root.get_node_or_null("MusicPlayer")
	if music_player == null:
		return
	if toggled_on:
		GlobalSettings.global_options["audio"]["music_active"] = true
		music_player.play()
	else:
		GlobalSettings.global_options["audio"]["music_active"] = false
		music_player.stop()


func _on_agression_range_button_toggled(toggled_on):
	GlobalSettings.global_options["gameplay"]["agression_rage"] = toggled_on


func _on_attack_range_button_toggled(toggled_on):
	GlobalSettings.global_options["gameplay"]["attack_rage"] = toggled_on


func _on_show_ai_poi_button_toggled(toggled_on):
	GlobalSettings.global_options["gameplay"]["show_ai_POI"] = toggled_on


func _on_show_weather_toggled(toggled_on):
	GlobalSettings.global_options["video"]["weather_show"] = toggled_on


func _on_close_button_pressed():
	self.visible = false
	closed.emit()
