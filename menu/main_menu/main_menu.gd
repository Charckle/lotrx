extends Node2D

var loaded_music_player = false

@onready var other_menus = $"other_menus"
@onready var music_player = load("res://audio/music_player/music_player.tscn")
var button_sound = preload("res://audio/sounds/menu/click-151673.mp3")

# Called when the node enters the scene tree for the first time.
func _ready():
	pass

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if not loaded_music_player:
		music_player = music_player.instantiate()
		get_tree().root.add_child(music_player)
		music_player.play_menu_music()
		loaded_music_player = true

func _on_quit_button_mouse_entered() -> void:
	play_click()
	
func _on_button_pressed():
	
	get_tree().quit()


func close_all_other_menus():
	var other_menus = other_menus.get_children()
	
	for menu in other_menus:
		menu.visible = false



func _on_about_menu_pressed():
	play_click()
	close_all_other_menus()
	other_menus.get_node("about_panel").visible = true

func _on_about_menu_mouse_entered() -> void:
	play_click()

func _on_settings_menu_mouse_entered() -> void:
	play_click()
	
func _on_settings_menu_pressed():
	play_click()
	close_all_other_menus()
	other_menus.get_node("settings_panel").visible = true


func _on_multiplayer_menu_mouse_entered() -> void:
	play_click()

func _on_multiplayer_menu_pressed() -> void:
	play_click()
	close_all_other_menus()
	other_menus.get_node("MutiplayerMenu").visible = true


func play_click():
	var sound = AudioStreamPlayer2D.new()
	sound.stream = button_sound
	get_tree().current_scene.add_child(sound)
	sound.play()
	sound.finished.connect(sound.queue_free)  # Remove when done playing
