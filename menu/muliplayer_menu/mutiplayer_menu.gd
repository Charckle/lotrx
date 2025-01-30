extends Control

var DEFAULT_SERVER_IP = "127.0.0.1"
var PORT = 9898
var MAX_CONNECTIONS = 2
var player_info = {"name": "Name"}

var players = {}
var players_loaded = 0

# Called when the node enters the scene tree for the first time.
func _ready():
	multiplayer.peer_connected.connect(_on_player_connected) # runs on every peer as a new user is connected
	multiplayer.peer_disconnected.connect(_on_player_disconnected)
	multiplayer.connected_to_server.connect(_local_on_connected_ok) # emmited on the clinet ONLY
	multiplayer.connection_failed.connect(_local_on_connected_fail) # emmited on the clinet ONLY
	multiplayer.server_disconnected.connect(_local_on_server_disconnected) # emmited on the clinet ONLY


func _on_player_connected(id):
	_register_player.rpc_id(id, player_info)

@rpc("any_peer", "reliable")
func _register_player(new_player_info):
	var new_player_id = multiplayer.get_remote_sender_id()
	players[new_player_id] = new_player_info
	print(new_player_info)
	#player_connected.emit(new_player_id, new_player_info)


func _on_player_disconnected(id):
	players.erase(id)
	#player_disconnected.emit(id)


func _local_on_connected_ok():
	var peer_id = multiplayer.get_unique_id()
	players[peer_id] = player_info
	#player_connected.emit(peer_id, player_info)
	print("Connected successfully")


func _local_on_connected_fail():
	multiplayer.multiplayer_peer = null
	print("Failed to connect to server")


func _local_on_server_disconnected():
	multiplayer.multiplayer_peer = null
	players.clear()
	print("Disconected from server")
	#server_disconnected.emit()

func _on_host_button_down():
	create_game()

func create_game():
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(PORT, MAX_CONNECTIONS)
	if error:
		return error
	
	multiplayer.multiplayer_peer = peer

	players[1] = player_info
	print("Waiting for players to connect")
	#player_connected.emit(1, player_info)

func _on_join_button_down():
	join_game()

func join_game(address = ""):
	if address.is_empty():
		address = DEFAULT_SERVER_IP
	
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_client(address, PORT)
	
	if error:
		return error
	
	multiplayer.multiplayer_peer = peer

func _on_start_button_down():
	if multiplayer.is_server():
		give_users_their_settings()
		start_game.rpc()

# this function is to slow or speed up the ticks on too fast or too slow clients, to try to match the servers
@rpc("any_peer", "call_local", "reliable")
func start_game():
	var scene = load("res://maps/castles/slo/socerb/socerb.tscn").instantiate()
	get_tree().root.add_child(scene)
	self.hide()


func give_users_their_settings():
	var faction = 1
	for key in players:
		var map_options = {
			"user_faction": faction,
			"ai_faction": 0}
		print(key)
		print(map_options)
		set_map_config.rpc_id(key, map_options)

		if faction == 2:
			faction = 1
		else:
			faction = 2
		
@rpc("any_peer", "call_local", "reliable")
func set_map_config(map_options):
	GlobalSettings.map_options = map_options
