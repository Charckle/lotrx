extends Node

var my_faction = 1
var friendly_factions = []

#var game_unit_count_start = null
#var game_unit_count_current = null
var game_stats = null

var show_path = false
var show_solid_tiles = false
#var show_ranges = true

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
		"show_ai_POI": false,
		"global_debug": true
	}
}

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

