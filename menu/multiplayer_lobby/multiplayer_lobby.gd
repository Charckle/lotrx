extends Node2D

@onready var multiplayer_menu = get_tree().root.get_node("MutiplayerMenu")
@onready var multiplayer_lobby = get_tree().root.get_node("MultiplayerLobby")

@onready var chat_panel = $CanvasLayer/main_panel/chat_panel

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if not multiplayer.is_server():
		$CanvasLayer/main_panel/bottom_panel/start_game.visible = false


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_start_game_pressed() -> void:
	give_users_their_settings()
	start_game.rpc()


# this function is to slow or speed up the ticks on too fast or too slow clients, to try to match the servers
@rpc("any_peer", "call_local", "reliable")
func start_game():
	var scene = load(GlobalSettings.multiplayer_data["mapt_to_load"]).instantiate()
	get_tree().root.add_child(scene)
	$CanvasLayer.hide()


func give_users_their_settings():
	var faction = 1
	for key in GlobalSettings.multiplayer_data["players"]:
		var map_options = {
			"user_faction": faction,
			"ai_faction": 0}
		
		set_map_config.rpc_id(key, map_options)

		if faction == 2:
			faction = 1
		else:
			faction = 2
		
@rpc("any_peer", "call_local", "reliable")
func set_map_config(map_options):
	GlobalSettings.map_options = map_options


func send_smg(msg: String):
	chat_panel.receive_chat_message.rpc(msg)

func remove_multiplayer_peer():
	GlobalSettings.multiplayer_data["players"].clear()
	multiplayer.multiplayer_peer = null

func _on_leave_game_pressed() -> void:
	remove_multiplayer_peer()
	multiplayer_lobby.queue_free()
	get_tree().change_scene_to_file("uid://ceun5xdoedpjf") # go to main menu
