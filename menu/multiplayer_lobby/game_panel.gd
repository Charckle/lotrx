extends Panel

@onready var multiplayer_lobby = get_tree().root.get_node("MultiplayerLobby")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	populate_maps()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func populate_maps():
	#var build_menu = build_menu.instantiate()
	
	for map in get_all_maps():
		var button = Button.new()
		button.text = map["name"]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_load_map_settings.bind(map))
		$map_selection_panel/map_buttons/VBoxContainer.add_child(button)

func _load_map_settings(map_settings_dic):
	var map_desc_element = $map_details_panel/ScrollContainer/map_description
	map_desc_element.text = map_settings_dic["desc"]
	
	if multiplayer.is_server():
		set_selected_map.rpc(map_settings_dic["name"], map_settings_dic["path"])
		var map_options = map_settings_dic["map_options"]
		multiplayer_lobby.set_player_list_gui.rpc(map_options)

@rpc("authority", "call_local", "reliable")
func set_selected_map(map_name, map_resource):
	var selected_map_name = multiplayer_lobby.selected_map_name
	selected_map_name.text = "Selected map: " + map_name
	GlobalSettings.multiplayer_data["map_to_load"] = map_resource


func get_all_maps():
	var maps = []
	
	var small_test_map = {
		"name": "open: Small test map 01",
		"desc": "A small forest map.",
		"path" : "uid://f367vqq2srko",
		"map_options": {
			"ai_faction": 0,
			"playabe_factions": [1,2]
			}
	}
	maps.append(small_test_map)
	
	var castle_socerb = {
		"name": "siege: Socerb castle",
		"desc": "A siege of the small castle Socerb, which withstood and repelled a venetian army inflicting them 3000 casualties.",
		"path" : "uid://dpq75kochn3i",
		"map_options": {
			"ai_faction": 0,
			"playabe_factions": [1,2]
			}
	}
	maps.append(castle_socerb)
	
	return maps
