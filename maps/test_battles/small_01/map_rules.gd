extends Node2D

var ai_faction = 99
var ai_factions = []
var map_type = "open"

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
	
	#GlobalSettings.my_faction = map_options["user_faction"]
	self.ai_faction = map_options.get("ai_faction", 0)
	
	# Multiplayer AI: spawn controllers for each AI faction from the lobby
	# Use call_deferred so the full scene (including units) is loaded before AI runs
	if map_options.has("ai_factions"):
		self.ai_factions = map_options["ai_factions"]
		call_deferred("spawn_ai_controllers")

func spawn_ai_controllers():
	for ai_fac in self.ai_factions:
		var ai_scene = load("res://AI/basic_ai_v1/ai_v_1.tscn").instantiate()
		ai_scene.faction = ai_fac
		ai_scene.faction_set_externally = true
		get_parent().add_child(ai_scene)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
