extends Node2D

var state_ = 0 #  0 iddle, 1 attack, 2 defend
@export var is_siege = false
@export var is_siege_defending = false

@export var faction = 2
@export var friendly_factions = []

var markers: Dictionary = {}
var unit_groups: Dictionary = {}

var base_unit_group = {"units": [],
				"task": null}

@onready var root_map = get_tree().root.get_child(1) # 0 je global properties autoloader :/

# Called when the node enters the scene tree for the first time.
func _ready():
	evaluate_threat()
	initial_setup()
	for gr in unit_groups:
		print("unit: " + str(gr))
		print(unit_groups[gr].size())
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
	

func evaluate_threat():
	print("evaluating_threats")
	var units_on_map = root_map.get_all_units()
	
	var my_side = 0
	var their_side = 0
	
	for unit in units_on_map:
		if unit.faction == self.faction or unit.faction in self.friendly_factions:
			my_side += unit.unit_strenght
		else:
			their_side += unit.unit_strenght
	print("my side: " + str(my_side))
	print("their side: " + str(their_side))
	set_state(my_side, their_side)

func set_state(my_side, their_side):
	if my_side > their_side:
		print("Starting Attack!")
		state_ = 1
	else:
		state_ = 2
		print("Starting Defense!")
		


func _on_timer_timeout():
	evaluate_threat()

func initial_setup():
	var units_on_map = root_map.get_all_units()
	
	set_markers(units_on_map)
	set_unit_groups(units_on_map)

func set_markers(units_on_map):
	# check all own units
	#var units_on_map = root_map.get_all_units()
	for unit in units_on_map:
		if unit.faction == self.faction:
			var unit_id = unit.unit_id
			if not markers.has(unit_id):
				#var unit_wr = weakref(unit)
				markers[unit_id] = []
			

	
	for marker in root_map.get_all_ai_markers():
		var unit_id_ = marker.unit_type
		markers[unit_id_].append(marker)
	print("current markers on map:")
	print(markers)

func set_unit_groups(units_on_map):
	#var units_on_map = root_map.get_all_units()
	for unit in units_on_map:
		if unit.faction == self.faction:
			var unit_id = unit.unit_id
			var unit_wr = weakref(unit)
			var unit_wr_obj = unit_wr.get_ref()
			
			# create a base group array
			if not unit_groups.has(unit_id):
				#var unit_wr = weakref(unit)
				var new_group = base_unit_group.duplicate(true)
				unit_groups[unit_id] = [new_group]
			
			add_unit_to_group(unit_wr)

func add_unit_to_group(unit_wr):
	var unit_id = unit_wr.get_ref().unit_id
	if unit_groups[unit_id][-1]["units"].size() < 4:
		unit_groups[unit_id][-1]["units"].append(unit_wr)
	else:
		var new_group = base_unit_group.duplicate(true)
		new_group["units"].append(unit_wr)
		unit_groups[unit_id].append(new_group)
	
func gr(weak_refer):
	if weak_refer == null:
		return null
	if weak_refer.get_ref() == null:
		return null
	else:
		return weak_refer.get_ref()
