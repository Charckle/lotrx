extends Node2D

var ai_faction = 2
var map_type = "castle"

var defense_script = {}

# Called when the node enters the scene tree for the first time.
func _ready():
	pass

# parent nodes execute _ready only when the child nodes execute theirs. _enter tree comes in handy, since its executed as soon as its loaded.
func _enter_tree():
	initialize_map()

func initialize_map():
	var map_options = {"user_faction": 1,
						"ai_faction": 2}
	
	if GlobalSettings.map_options != null:
		map_options = GlobalSettings.map_options
	
	self.ai_faction = map_options["ai_faction"]
	
	initialize_ai_defense_script()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


func initialize_ai_defense_script():
	self.defense_script = {
		"door_closure": [
			{"doors_to_te_destroyed": [300],
			"doors_tc_close": [200]},
			]
	}
