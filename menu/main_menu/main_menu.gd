extends Node2D

var loaded_music_player = false

@onready var other_menus = $"other_menus"
@onready var music_player = load("res://audio/music_player/music_player.tscn")

# Called when the node enters the scene tree for the first time.
func _ready():
	if GlobalSettings.host_disconnected_message != "":
		$host_disconnect_popup/message_label.text = GlobalSettings.host_disconnected_message
		$host_disconnect_popup.visible = true
		GlobalSettings.host_disconnected_message = ""

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if not loaded_music_player:
		var existing = get_tree().root.get_node_or_null("MusicPlayer")
		if existing:
			# Music player already exists (e.g. returning from lobby), keep it playing
			music_player = existing
		else:
			music_player = music_player.instantiate()
			get_tree().root.add_child(music_player)
			music_player.play_menu_music()
		loaded_music_player = true

func _on_button_pressed():
	get_tree().quit()


func close_all_other_menus():
	var other_menus = other_menus.get_children()
	
	for menu in other_menus:
		menu.visible = false


func _on_about_menu_pressed():
	close_all_other_menus()
	other_menus.get_node("about_panel").visible = true

func _on_settings_menu_pressed():
	close_all_other_menus()
	other_menus.get_node("settings_panel").visible = true

func _on_multiplayer_menu_pressed() -> void:
	close_all_other_menus()
	other_menus.get_node("MutiplayerMenu").visible = true

func _on_host_disconnect_ok_pressed():
	$host_disconnect_popup.visible = false
