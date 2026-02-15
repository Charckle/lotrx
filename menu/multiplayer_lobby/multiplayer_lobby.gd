extends Node2D

@onready var multiplayer_menu = get_tree().root.get_node("MutiplayerMenu")
@onready var multiplayer_lobby = get_tree().root.get_node("MultiplayerLobby")

@onready var chat_panel = $CanvasLayer/main_panel/chat_panel
@onready var selected_map_name = $CanvasLayer/main_panel/bottom_panel/selected_map_name
@onready var player_gui_cont = $CanvasLayer/main_panel/player_panel/ScrollContainer/VBoxContainer

# AI player IDs start at a high number to avoid collision with real peer IDs
const AI_PLAYER_ID_START = 9001
var next_ai_id = AI_PLAYER_ID_START

var _updating_color = false

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


@rpc("any_peer", "call_local", "reliable")
func start_game():
	# Register all player colors and build ai_factions list
	var ai_factions = []
	var taken_factions = []
	for player_id in GlobalSettings.multiplayer_data["players"]:
		var player = GlobalSettings.multiplayer_data["players"][player_id]
		var fac = player.get("faction", 0)
		# Register color for every player (human and AI)
		if player.has("color") and fac != 0:
			GlobalSettings.faction_colors[fac] = player["color"]
		if fac != 0:
			taken_factions.append(fac)
		if player.get("is_ai", false):
			if fac != 0:
				ai_factions.append(fac)

	# Auto-assign AI to any playable factions that have no player (human or AI)
	if GlobalSettings.map_options != null:
		var playable = GlobalSettings.map_options.get("playabe_factions", [])
		for fac_id in playable:
			if fac_id not in taken_factions:
				ai_factions.append(fac_id)

	# The first AI faction goes to map_rules.ai_faction (for the embedded AI node),
	# the rest go to ai_factions (spawned dynamically)
	if GlobalSettings.map_options != null:
		if ai_factions.size() > 0:
			GlobalSettings.map_options["ai_faction"] = ai_factions[0]
			GlobalSettings.map_options["ai_factions"] = ai_factions.slice(1)
		else:
			GlobalSettings.map_options["ai_faction"] = 0
			GlobalSettings.map_options["ai_factions"] = []

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
	if map_options != null:
		GlobalSettings.map_options = map_options
		
	for child in player_gui_cont.get_children():
		player_gui_cont.remove_child(child)
		child.queue_free()
	
	for player_id in GlobalSettings.multiplayer_data["players"]:
		var player = GlobalSettings.multiplayer_data["players"][player_id]
		var is_ai = player.get("is_ai", false)
		var grid = GridContainer.new()
		grid.name = str(player_id)
		
		if is_ai:
			grid.columns = 4  # name, faction, color, remove
		else:
			grid.columns = 3  # name, faction, color
		
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		var label = Label.new()
		label.text = player["name"]
		label.custom_minimum_size = Vector2(150, 0)

		var option_button = OptionButton.new()
		option_button.custom_minimum_size = Vector2(130, 0)

		if GlobalSettings.map_options != null:
			for faction_id in GlobalSettings.map_options["playabe_factions"]:
				var fact_name = ("Faction " + str(faction_id))
				option_button.name = str(player_id)
				option_button.add_item(fact_name, faction_id)
			option_button.item_selected.connect(_on_option_button_item_selected.bind(player_id))
			
			# Restore previously selected faction
			var saved_faction = player.get("faction", 0)
			if saved_faction != 0:
				for i in range(option_button.item_count):
					if option_button.get_item_id(i) == saved_faction:
						option_button.select(i)
						break
			else:
				option_button.select(0)
				# Set default faction in player data
				if option_button.item_count > 0:
					player["faction"] = option_button.get_item_id(0)
		
		else:
			var fact_name = "No faction available"
			option_button.add_item(fact_name, 0)
			option_button.select(0)
		
		grid.add_child(label)
		grid.add_child(option_button)
		
		# Color picker for all players (human and AI)
		var color_picker = ColorPickerButton.new()
		color_picker.custom_minimum_size = Vector2(40, 30)
		color_picker.edit_alpha = false
		# Restore saved color or use default white
		var saved_color = player.get("color", {"red": 255, "green": 255, "blue": 255})
		color_picker.color = Color(saved_color["red"] / 255.0, saved_color["green"] / 255.0, saved_color["blue"] / 255.0)
		color_picker.color_changed.connect(_on_player_color_changed.bind(player_id))
		grid.add_child(color_picker)
		
		# AI-specific: remove button
		if is_ai:
			var remove_btn = Button.new()
			remove_btn.text = "X"
			remove_btn.pressed.connect(_on_remove_ai_pressed.bind(player_id))
			if not multiplayer.is_server():
				remove_btn.visible = false
			grid.add_child(remove_btn)

		player_gui_cont.add_child(grid)
	
	# Add "Add AI Player" button at the bottom (server only)
	if multiplayer.is_server():
		var add_ai_btn = Button.new()
		add_ai_btn.text = "+ Add AI Player"
		add_ai_btn.pressed.connect(_on_add_ai_pressed)
		player_gui_cont.add_child(add_ai_btn)


func _get_next_available_faction() -> int:
	# Find a faction not already taken by another player
	if GlobalSettings.map_options == null:
		return 0
	var playable = GlobalSettings.map_options.get("playabe_factions", [])
	var taken = []
	for pid in GlobalSettings.multiplayer_data["players"]:
		var fac = GlobalSettings.multiplayer_data["players"][pid].get("faction", 0)
		if fac != 0:
			taken.append(fac)
	for fac_id in playable:
		if fac_id not in taken:
			return fac_id
	# All factions taken, default to first available
	if playable.size() > 0:
		return playable[0]
	return 0


func _on_add_ai_pressed():
	if not multiplayer.is_server():
		return
	var ai_info = {
		"name": "AI " + str(next_ai_id - AI_PLAYER_ID_START + 1),
		"is_ai": true,
		"faction": _get_next_available_faction(),
		"color": GlobalSettings.generate_random_color()
	}
	GlobalSettings.multiplayer_data["players"][next_ai_id] = ai_info
	next_ai_id += 1
	_sync_players.rpc(GlobalSettings.multiplayer_data["players"])
	
	var msg = ai_info["name"] + " was added to the game."
	send_smg(msg)


func _on_remove_ai_pressed(player_id: int):
	if not multiplayer.is_server():
		return
	var ai_name = GlobalSettings.multiplayer_data["players"][player_id]["name"]
	GlobalSettings.multiplayer_data["players"].erase(player_id)
	_sync_players.rpc(GlobalSettings.multiplayer_data["players"])
	
	var msg = ai_name + " was removed from the game."
	send_smg(msg)


@rpc("authority", "call_local", "reliable")
func _sync_players(all_players):
	GlobalSettings.multiplayer_data["players"] = all_players
	set_player_list_gui(GlobalSettings.map_options)


func _on_player_color_changed(color: Color, player_id: int):
	if _updating_color:
		return
	change_player_color.rpc(player_id, color.r8, color.g8, color.b8)

@rpc("any_peer", "call_local", "reliable")
func change_player_color(player_id, r, g, b):
	GlobalSettings.multiplayer_data["players"][player_id]["color"] = {"red": r, "green": g, "blue": b}
	# Update color picker on all clients
	_updating_color = true
	for grid_container in player_gui_cont.get_children():
		if grid_container is GridContainer and str(grid_container.name) == str(player_id):
			for child in grid_container.get_children():
				if child is ColorPickerButton:
					child.color = Color(r / 255.0, g / 255.0, b / 255.0)
	_updating_color = false


func _on_option_button_item_selected(index: int, player_id: int):
	var button_index = index
	change_faction.rpc(player_id, button_index)

@rpc("any_peer", "call_local", "reliable")
func change_faction(player_id, button_index):
	var faction_id = 0
	for grid_container in player_gui_cont.get_children():
		if grid_container is GridContainer and int(str(grid_container.name)) == player_id:
			grid_container.get_child(1).selected = button_index
			faction_id = grid_container.get_child(1).get_item_id(button_index)

	# Persist faction in player data
	if GlobalSettings.multiplayer_data["players"].has(player_id):
		GlobalSettings.multiplayer_data["players"][player_id]["faction"] = faction_id

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
