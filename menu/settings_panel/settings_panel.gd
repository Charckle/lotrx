extends Panel

signal closed


func _ready():
	# Initialize toggle states from GlobalSettings without triggering signals
	$TabContainer/Audio/GridContainer/music_enable_button.set_pressed_no_signal(GlobalSettings.global_options["audio"]["music_active"])
	$TabContainer/Audio/GridContainer/main_volume_slider.set_value_no_signal(GlobalSettings.global_options["audio"].get("main_volume", 1.0))
	$TabContainer/Audio/GridContainer/music_volume_slider.set_value_no_signal(GlobalSettings.global_options["audio"].get("music_volume", 1.0))
	$TabContainer/Audio/GridContainer/sfx_volume_slider.set_value_no_signal(GlobalSettings.global_options["audio"].get("sfx_volume", 1.0))
	$TabContainer/Gameplay/GridContainer2/agression_range_button.set_pressed_no_signal(GlobalSettings.global_options["gameplay"]["agression_rage"])
	$TabContainer/Gameplay/GridContainer2/attack_range_button.set_pressed_no_signal(GlobalSettings.global_options["gameplay"]["attack_rage"])
	$TabContainer/Gameplay/GridContainer2/show_ai_poi_button.set_pressed_no_signal(GlobalSettings.global_options["gameplay"]["show_ai_POI"])
	$TabContainer/Video/GridContainer3/show_weather.set_pressed_no_signal(GlobalSettings.global_options["video"]["weather_show"])


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


func _on_main_volume_slider_value_changed(value: float) -> void:
	GlobalSettings.set_audio_bus_volume("Master", value)


func _on_music_volume_slider_value_changed(value: float) -> void:
	GlobalSettings.set_audio_bus_volume("music", value)


func _on_sfx_volume_slider_value_changed(value: float) -> void:
	GlobalSettings.set_audio_bus_volume("sfx", value)


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
