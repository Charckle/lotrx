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
		"music_active": true,
		"main_volume": 1.0,
		"music_volume": 1.0,
		"sfx_volume": 0.6
	},
	"gameplay": {
		"attack_rage": false,
		"agression_rage": false,
		"show_ai_POI": false
	},
	"video": {
		"weather_show": true,
		"fullscreen": true
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
	_apply_audio_volumes()
	_apply_video_settings()


func _apply_audio_volumes() -> void:
	var audio = global_options["audio"]
	_set_bus_volume_db("Master", audio.get("main_volume", 1.0))
	_set_bus_volume_db("music", audio.get("music_volume", 1.0))
	_set_bus_volume_db("sfx", audio.get("sfx_volume", 1.0))


func _set_bus_volume_db(bus_name: String, linear: float) -> void:
	var idx = AudioServer.get_bus_index(bus_name)
	if idx == -1:
		return
	# Map 0..1 to -80..0 dB (mute at 0, full at 1)
	var db = linear_to_db(clampf(linear, 0.0001, 1.0))
	AudioServer.set_bus_volume_db(idx, db)


func set_audio_bus_volume(bus_name: String, linear: float) -> void:
	linear = clampf(linear, 0.0, 1.0)
	if bus_name == "Master":
		global_options["audio"]["main_volume"] = linear
	elif bus_name == "music":
		global_options["audio"]["music_volume"] = linear
	elif bus_name == "sfx":
		global_options["audio"]["sfx_volume"] = linear
	_set_bus_volume_db(bus_name, linear)


func _apply_video_settings() -> void:
	var fullscreen: bool = global_options["video"].get("fullscreen", true)
	var win := get_tree().root
	win.mode = Window.MODE_FULLSCREEN if fullscreen else Window.MODE_WINDOWED


func set_fullscreen(enabled: bool) -> void:
	global_options["video"]["fullscreen"] = enabled
	_apply_video_settings()

func reset_to_defaults():
	my_faction = 1
	friendly_factions = []
	game_stats = null
	faction_colors = {
		1: {"red":0, "green": 100, "blue": 255},
		2: {"red": 255, "green": 255, "blue": 100},
		99: {"red":255, "green": 255, "blue": 255},
	}
	map_options = null
	multiplayer_data = {
		"players": {},
		"map_to_load": null
	}

func generate_random_color() -> Dictionary:
	var color = Color.from_hsv(randf(), randf_range(0.5, 1.0), randf_range(0.7, 1.0))
	return {"red": int(color.r * 255), "green": int(color.g * 255), "blue": int(color.b * 255)}
