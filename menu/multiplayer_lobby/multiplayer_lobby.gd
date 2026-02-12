extends Node2D

@onready var multiplayer_menu = get_tree().root.get_node("MutiplayerMenu")
@onready var multiplayer_lobby = get_tree().root.get_node("MultiplayerLobby")

@onready var chat_panel = $CanvasLayer/main_panel/chat_panel
@onready var selected_map_name = $CanvasLayer/main_panel/bottom_panel/selected_map_name
@onready var player_gui_cont = $CanvasLayer/main_panel/player_panel/ScrollContainer/VBoxContainer

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if not multiplayer.is_server():
		$CanvasLayer/main_panel/bottom_panel/start_game.visible = false


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_start_game_pressed() -> void:
	if GlobalSettings.multiplayer_data["map_to_load"] != null:
		start_game.rpc()
	else:
		var msg = "Cannot start the game before selecting a map."
		send_smg(msg)


# this function is to slow or speed up the ticks on too fast or too slow clients, to try to match the servers
@rpc("any_peer", "call_local", "reliable")
func start_game():
	var scene = load(GlobalSettings.multiplayer_data["map_to_load"]).instantiate()
	get_tree().root.add_child(scene)
	$CanvasLayer.hide()


func give_users_their_settings_NOT_IN_USE():
	var faction = 1
	for key in GlobalSettings.multiplayer_data["players"]:
		var map_options = {
			"user_faction": faction,
			"ai_faction": 0,
			"all_factions": [1,2]
			}
		
		set_map_config.rpc_id(key, map_options)

		if faction == 2:
			faction = 1
		else:
			faction = 2

@rpc("authority", "call_local", "reliable")
func set_map_config(map_options):
	GlobalSettings.map_options = map_options


@rpc("authority", "call_local", "reliable")
func set_player_list_gui(map_options=null):
	GlobalSettings.map_options = map_options
		
	for child in player_gui_cont.get_children():
		player_gui_cont.remove_child(child)
		child.queue_free()
	
	# čekiraj katere fakcije so v konfigih. ČE ni nobene, daš no No faction
	
	for player_id in GlobalSettings.multiplayer_data["players"]:
		var player =  GlobalSettings.multiplayer_data["players"][player_id]
		var grid = GridContainer.new()
		grid.name = str(player_id)
		grid.columns = 2  # Set columns to 2
		#grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		var label = Label.new()
		label.text = player["name"]

		var option_button = OptionButton.new()

		if GlobalSettings.map_options != null:
			for faction_id in GlobalSettings.map_options["playabe_factions"]:
				var fact_name = ("Faction " + str(faction_id))
				option_button.name = str(player_id)
				option_button.add_item(fact_name, faction_id)
			option_button.item_selected.connect(_on_option_button_item_selected.bind(player_id))
		
		else:
			var fact_name = "No faction available"
			option_button.add_item(fact_name, 0)
		option_button.select(0)
		
		grid.add_child(label)
		grid.add_child(option_button)

		# Add GridContainer to the scene (assuming it's inside a parent node)
		player_gui_cont.add_child(grid)

func _on_option_button_item_selected(index: int, player_id: int):
	var button_index = index
	change_faction.rpc(player_id, button_index)

@rpc("any_peer", "call_local", "reliable")
func change_faction(player_id, button_index):
	var faction_id = 0
	for grid_container in player_gui_cont.get_children():

		if int(str(grid_container.name)) == player_id:
			#grid_container.get_child(1).name = ("Faction " + str(faction_id))
			#grid_container.get_child(1).id = faction_id
			grid_container.get_child(1).selected = button_index
			faction_id = grid_container.get_child(1).get_item_id(button_index)

	if player_id == multiplayer.get_unique_id():
		GlobalSettings.my_faction = faction_id


func send_smg(msg: String):
	chat_panel.receive_chat_message.rpc(msg)

func remove_multiplayer_peer():
	GlobalSettings.multiplayer_data["players"].clear()
	multiplayer.multiplayer_peer = null
	GlobalSettings.map_options = null

func _on_leave_game_pressed() -> void:
	remove_multiplayer_peer()
	multiplayer_lobby.queue_free()
	get_tree().change_scene_to_file("uid://ceun5xdoedpjf") # go to main menu
