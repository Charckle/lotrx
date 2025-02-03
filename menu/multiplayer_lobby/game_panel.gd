extends Panel


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
	var map_Desc_element = $map_details_panel/ScrollContainer/map_description
	map_Desc_element.text = map_settings_dic["desc"]
	GlobalSettings.multiplayer_data["mapt_to_load"] = map_settings_dic["path"]

func get_all_maps():
	var maps = []
	
	var small_test_map = {
		"name": "open: Small test map 01",
		"desc": "A small forest map.",
		"path" : "uid://f367vqq2srko",
		"attacking_faction": 1,
		"defending_faction": 2
	}
	maps.append(small_test_map)
	
	var castle_socerb = {
		"name": "siege: Socerb castle",
		"desc": "A siege of the small castle Socerb",
		"path" : "uid://dpq75kochn3i",
		"attacking_faction": 1,
		"defending_faction": 2
	}
	maps.append(castle_socerb)
	
	return maps
