extends Control

var DEFAULT_SERVER_IP = "127.0.0.1"
var PORT = 49152
var MAX_CONNECTIONS = 2
var player_info = {"name": ""}

var players = {}
var players_loaded = 0

@onready var error_msg = $error_msg

@onready var main_menu = get_tree().root.get_node("MainMenu")
@onready var multiplayer_loby = get_tree().root.get_node("MultiplayerLobby")

@onready var multiplayer_lobby = load("res://menu/multiplayer_lobby/multiplayer_lobby.tscn")

# Called when the node enters the scene tree for the first time.
func _ready():
	multiplayer.peer_connected.connect(_on_player_connected) # runs on every peer as a new user is connected
	multiplayer.peer_disconnected.connect(_on_player_disconnected)
	multiplayer.connected_to_server.connect(_local_on_connected_ok) # emmited on the clinet ONLY
	multiplayer.connection_failed.connect(_local_on_connected_fail) # emmited on the clinet ONLY
	multiplayer.server_disconnected.connect(_local_on_server_disconnected) # emmited on the clinet ONLY


func _on_player_connected(id):
	#_register_player.rpc_id(id, player_info)
	pass
	# runs on every client, the new client runs it
	
	

@rpc("any_peer", "reliable")
func _register_player_NOT_IN_USE(new_player_info):
	var new_player_id = multiplayer.get_remote_sender_id()
	
	GlobalSettings.multiplayer_data["players"][new_player_id] = new_player_info
	print(new_player_info)
	#player_connected.emit(new_player_id, new_player_info)


func _on_player_disconnected(id):
	GlobalSettings.multiplayer_data["players"].erase(id)
	#player_disconnected.emit(id)
	print("player " + str(id) + " disconnected.")


func _local_on_connected_ok():
	#var peer_id = multiplayer.get_unique_id()
	var player_name = $type_multiplayer_panel/player_name.text
	
	player_info["name"] = player_name
	
	#GlobalSettings.multiplayer_data["players"][peer_id] = player_info
	print(player_info)
	_register_player_on_server.rpc_id(1, player_info)
	#player_connected.emit(peer_id, player_info)
	#print("Connected successfully")

@rpc("any_peer", "call_remote", "reliable")
func _register_player_on_server(new_player_info):
	var new_player_id = multiplayer.get_remote_sender_id()
	
	new_player_info["name"] = return_valid_player_name(new_player_info["name"])
	
	GlobalSettings.multiplayer_data["players"][new_player_id] = new_player_info
	#print(new_player_info)
	_update_players_data_on_clients.rpc(GlobalSettings.multiplayer_data["players"])
	
	var msg = new_player_info["name"] + " joined the game."
	get_tree().root.get_node("MultiplayerLobby").send_smg(msg)


@rpc("authority", "call_remote", "reliable")
func _update_players_data_on_clients(all_player_info):
	#var new_player_id = multiplayer.get_remote_sender_id()
	var peer_id = multiplayer.get_unique_id()

	GlobalSettings.multiplayer_data["players"] = all_player_info
	player_info = all_player_info[peer_id]


func _local_on_connected_fail():
	multiplayer.multiplayer_peer = null
	print("Failed to connect to server")


func _local_on_server_disconnected():
	multiplayer.multiplayer_peer = null
	GlobalSettings.multiplayer_data["players"].clear()
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
	
	var player_name = $type_multiplayer_panel/player_name.text
	player_name = return_valid_player_name(player_name)
	
	player_info["name"] = player_name
	GlobalSettings.multiplayer_data["players"][1] = player_info
	
	var scene = multiplayer_lobby.instantiate()
	
	get_tree().root.add_child(scene)
	
	# send message for joined player
	var msg = player_info["name"] + " created the game."
	print(msg)
	print(GlobalSettings.multiplayer_data["players"])
	scene.send_smg(msg)
	
	# hide the rest
	main_menu.hide()
	
	print("Waiting for players to connect")
	#player_connected.emit(1, player_info)

func _on_join_button_down():
	var ip_text = $type_multiplayer_panel/join_ip_address.text
	if ip_text.is_empty():
		var text_to_display = "The IP cannot be blank"
		show_error_panel(text_to_display)
	elif not is_valid_ipv4(ip_text):
		var text_to_display = "Not a valid IPv4 address"
		show_error_panel(text_to_display)
	else:
		join_game()

func join_game(address = ""):
	if address.is_empty():
		address = DEFAULT_SERVER_IP
	
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_client(address, PORT)
	
	if error:
		return error
	
	multiplayer.multiplayer_peer = peer
	
	print("successfully joined multiplayer game")
	
	var scene = multiplayer_lobby.instantiate()
	get_tree().root.add_child(scene)
	main_menu.hide()


func show_error_panel(text_to_display:String):
	error_msg.visible = true
	var error_text = error_msg.get_node("error_text")
	error_text.text = text_to_display
	get_tree().paused = true



func is_valid_ipv4(ip: String) -> bool:
	var ipv4_regex = RegEx.create_from_string(r"^(\d{1,3}\.){3}\d{1,3}$")
	
	if not ipv4_regex.search(ip):
		return false  # Doesn't match basic format

	var parts = ip.split(".")
	for part in parts:
		var num = part.to_int()
		if num < 0 or num > 255:  # Ensure each octet is within range
			return false

	return true  # Valid IPv4 address

func return_valid_player_name(player_name):
	var new_player_name = player_name.strip_edges()
	
	if new_player_name == "":
		var seq_num = len(GlobalSettings.multiplayer_data["players"]) + 1
		var name_ok = true
		
		while true:
			new_player_name = "Player" + str(seq_num)
			
			for player in GlobalSettings.multiplayer_data["players"]:
				if player.has("name") and player["name"] == "alfred":
					name_ok = false
					break
			if name_ok == true:
				break
			else:
				seq_num

	return new_player_name
