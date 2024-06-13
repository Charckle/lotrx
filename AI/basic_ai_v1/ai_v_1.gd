extends Node2D

var state_ = 0 #  0 iddle, 1 attack, 2 defend
@export var is_siege = false
@export var is_siege_defending = false

@export var faction = 2
@export var friendly_factions = []

var markers: Dictionary = {}
var unit_groups: Dictionary = {}

var initial_units_to_markers = false

var base_unit_group = {"units": [],
				"task": null}

@onready var root_map = get_tree().root.get_child(1) # 0 je global properties autoloader :/

# Called when the node enters the scene tree for the first time.
func _ready():
	evaluate_threat()
	initial_setup()

	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if state_ == 2:
		manage_defense()
	empty_dead_units()
	
func print_units_groups():
	for gr in unit_groups:
		print("unit: " + str(gr))
		print(unit_groups[gr].size())

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


func manage_defense():
	if initial_units_to_markers == false:
		move_to_initial_markers()
		initial_units_to_markers = true

func move_to_initial_markers():
	for unit_id in markers:
		var number_of_markers = markers[unit_id].size()
		if number_of_markers > 0:
			var to_marker_number = 0
			for group in unit_groups[unit_id]:
				for unit_wr in group["units"]:
					var market_position = markers[unit_id][to_marker_number].global_position
					gr(unit_wr).set_move(market_position)
				to_marker_number += 1
				if to_marker_number >= number_of_markers:
					to_marker_number = 0

func set_unit_groups_position():
	pass

func get_central_point(points: Array) -> Vector2:
	var total_x = 0.0
	var total_y = 0.0
	var count = points.size()

	if count == 0:
		return Vector2()

	for point in points:
		total_x += point.x
		total_y += point.y

	var centroid_x = total_x / count
	var centroid_y = total_y / count

	return Vector2(centroid_x, centroid_y)

func check_being_shot_at():
	# units should have I AM BEING SHOT AT variable
	# if a unit is being shot at, send that unit to attack the source
	# check sorounding cells of the attacking unit to see how many forces to send
	pass

func check_range_units_pinned():
	# check all ranged unit groups for being pinned
	# if they are pinned, check available unit goups around, if they are not already defending pinned
	# units, and send them to defend the ranged
	var ranged_units_ids= [1,2]
	
	for unit_id in ranged_units_ids:
		for group in unit_groups[unit_id]:
			var pinned_unit = null
			for unit_wr in group["units"]:
				if gr(unit_wr).is_pinned == true:
					pinned_unit = unit_wr
			if pinned_unit != null:
				# check which unit is pinning it at attack
				pass

func empty_dead_units():
	# remove dead units from control groups
	for type_group in unit_groups:
		for group in unit_groups[type_group]:
			for unit_wr in group["units"]:
				if gr(unit_wr) == null:
					var index_ = group["units"].find(unit_wr)
					group["units"].remove_at(index_)

func gr(weak_refer):
	if weak_refer == null:
		return null
	if weak_refer.get_ref() == null:
		return null
	else:
		return weak_refer.get_ref()
