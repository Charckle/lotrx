extends Node2D

var ai_faction = 1
var ai_factions = []
var map_type = "castle"

var defense_script = {}

# Called when the node enters the scene tree for the first time.
func _ready():
	pass

# parent nodes execute _ready only when the child nodes execute theirs. _enter tree comes in handy, since its executed as soon as its loaded.
func _enter_tree():
	initialize_map()

func initialize_map():
	var map_options = {"user_faction": 2,
						"ai_faction": 1}
	
	if GlobalSettings.map_options != null:
		map_options = GlobalSettings.map_options
	
	self.ai_faction = map_options.get("ai_faction", 0)
	
	# Multiplayer AI: spawn controllers for each AI faction from the lobby
	# Use call_deferred so the full scene (including units) is loaded before AI runs
	if map_options.has("ai_factions"):
		self.ai_factions = map_options["ai_factions"]
		call_deferred("spawn_ai_controllers")
	
	initialize_ai_defense_script()

func spawn_ai_controllers():
	for ai_fac in self.ai_factions:
		var ai_scene = load("res://AI/basic_ai_v1/ai_v_1.tscn").instantiate()
		ai_scene.faction = ai_fac
		ai_scene.faction_set_externally = true
		get_parent().add_child(ai_scene)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


func initialize_ai_defense_script():
	self.defense_script = {
		"door_closure": [
			{
				"doors_to_te_destroyed": [300],
				"doors_tc_close": [200],
				# optional: when a siege tower is placed at one of these slot indices (siege_walls/available_loc child index), close inner doors too
				# "siege_slots_that_breach": [0, 1, 2],
				# or use "all" to treat any placed siege tower as breach for this rule:
				# "siege_slots_that_breach": "all",
			},
		]
	}
