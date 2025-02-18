extends Node

var my_faction = 1
var friendly_factions = []

#var game_unit_count_start = null
#var game_unit_count_current = null
var game_stats = null

var faction_colors = {1: {"red":0, "green": 100, "blue": 255}, 2: {"red": 255, "green": 255, "blue": 100},
					  99: {"red":255, "green": 255, "blue": 255},}

var map_options = null

var global_options = {
	"audio": {
		"music_active": true
	},
	"gameplay": {
		"attack_rage": false,
		"agression_rage": false,
		"show_ai_POI": false
	},
	"video": {
		"weather_show": true
	},
	"debug": {
		"show_solid_tiles": false,
		"show_path": false,
		"global_debug": false
	}
}

var multiplayer_data = {
	"players": {},
	"map_to_load": null
}

var units_ = {
		0: "peasant",
		1: "archer",
		2: "crossbow",
		3: "knight",
		4: "maceman",
		5: "pikeman",
		6: "swordsman",
		7: "ram",
		8: "cauldron",
		9: "siege_tower",
		500: "small_door",
		501: "portcullis",
		502: "draw_bridge"
	}

func get_list_of_ranged():
	return [1,2]

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.
