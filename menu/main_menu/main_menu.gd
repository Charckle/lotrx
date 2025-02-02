extends Node2D

@onready var other_menus = $"other_menus"
@onready var audio_player = $"AudioPlayer"


# Called when the node enters the scene tree for the first time.
func _ready():
	if GlobalSettings.global_options["audio"]["music_active"] == true:
		self.audio_player.play()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


func _on_button_pressed():
	get_tree().quit()


func _on_open_maps_pressed():
	close_all_other_menus()
	other_menus.get_node("open_maps").visible = true

func close_all_other_menus():
	var other_menus = other_menus.get_children()
	
	for menu in other_menus:
		menu.visible = false


func _on_castle_maps_pressed():
	close_all_other_menus()
	other_menus.get_node("castles_maps").visible = true


func _on_attack_pressed_small_test_map():
	#GlobalSettings.map_options["attacking"] = true
	GlobalSettings.map_options = {
		"user_faction": 1,
		"ai_faction": 2}
	
	get_tree().change_scene_to_file("uid://f367vqq2srko")


func _on_defend_pressed_small_test_map():
	#GlobalSettings.map_options["attacking"] = false
	GlobalSettings.map_options = {
		"user_faction": 2,
		"ai_faction": 1}
	
	get_tree().change_scene_to_file("uid://f367vqq2srko")


func _on_about_menu_pressed():
	close_all_other_menus()
	other_menus.get_node("about_panel").visible = true


func _on_settings_menu_pressed():
	close_all_other_menus()
	other_menus.get_node("settings_panel").visible = true


func _on_multiplayer_menu_pressed() -> void:
	close_all_other_menus()
	other_menus.get_node("MutiplayerMenu").visible = true
