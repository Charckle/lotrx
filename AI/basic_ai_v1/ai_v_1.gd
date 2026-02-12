extends Node2D

enum MapTypes { OPEN, CASTLE }
var map_type = MapTypes.OPEN

enum State { IDLE, ATTACKING, DEFENDING }
var current_state = State.IDLE # ATM just for digging
var state_ = 0 #  0 iddle, 1 attack, 2 defend
@export var is_siege = false
@export var is_siege_defending = false

@export var faction = 99
@export var friendly_factions = []

var my_units_on_map = []
var markers: Dictionary = {}
var unit_groups: Dictionary = {}

var initial_units_to_markers = false

var own_forces_center = Vector2.ZERO

var lost = false

var base_unit_group = {"units": [],
				"task": null}

var doors = []

@onready var root_map = get_tree().root.get_node("game") # 0 je global properties autoloader :/

# Called when the node enters the scene tree for the first time.
func _ready():
	if root_map.get_node("map_rules").map_type == "castle":
		map_type = MapTypes.CASTLE
	
	set_faction()
	get_my_units()
	set_units_to_defense_stance()
	evaluate_threat(true)
	initial_setup()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func set_faction():
	self.faction = root_map.get_node("map_rules").ai_faction

func get_my_units():
	for unit in root_map.get_all_units():
		if unit.faction == self.faction:
			my_units_on_map.append(weakref(unit))

func set_units_to_defense_stance():
	if map_type == MapTypes.CASTLE:
		for unit in my_units_on_map:
			var unit_obj = gr(unit)
			if unit_obj != null:
				if unit_obj.unit_id not in GlobalSettings.get_list_of_ranged():
					unit_obj.stance = 1

func print_units_groups():
	for gr in unit_groups:
		print("unit: " + str(gr))
		print(unit_groups[gr].size())


func evaluate_threat(first:bool):
	# evaluates who is winning and who is loosing
	#print("evaluating_threats")
	var units_on_map = root_map.get_all_units()
	
	var my_side = 0
	var their_side = 0
	
	for unit in units_on_map:
		if unit.faction == self.faction or unit.faction in self.friendly_factions:
			my_side += unit.unit_strenght
		else:
			their_side += unit.unit_strenght
	#print("my side: " + str(my_side))
	#print("their side: " + str(their_side))
	set_state(my_side, their_side, first)

func set_state(my_side, their_side, first: bool):
	if first:
		if my_side > their_side:
			print("Starting Attack!")
			current_state = State.ATTACKING
		else:
			current_state = State.DEFENDING
			print("Starting Defense!")
	else:
		if current_state == State.ATTACKING:
			# if their > own * 1.2 = defense
			if their_side > my_side * 1.2:
				current_state = State.DEFENDING
				print("Starting Defense!")
			else:
				current_state = State.ATTACKING
				print("Still Attacking!")
		else:
			# if own > their * 1.2 = attack
			if my_side > their_side * 1.2:
				print("Starting Attack!")
				current_state = State.ATTACKING
			else:
				current_state = State.DEFENDING
				print("Still Defending!")


func _on_timer_timeout():
	empty_dead_units()
	set_inner_doors(1)
	
	if self.lost == false:
		evaluate_threat(false)
		
		if self.current_state == State.ATTACKING:
			manage_attack()
		if self.current_state == State.DEFENDING:
			if map_type == MapTypes.CASTLE:
				manage_defense_castle()
			else:
				manage_defense_markers()

	else:
		print("GG!")

func initial_setup():	
	set_markers()
	set_unit_groups()

func set_markers():
	# check all markers on the map and adds them locall, for faster access

	# check all own units
	#var units_on_map = root_map.get_all_units()
	for unit in root_map.get_all_units():
		var unit_id = unit.unit_id
		if not markers.has(unit_id):
			#var unit_wr = weakref(unit)
			markers[unit_id] = []
	
	for marker in root_map.get_all_ai_markers():
		if marker.faction == self.faction:
			var unit_id_ = marker.unit_type
			markers[unit_id_].append(marker)
	#print("current markers on map:")
	#print(markers)

func set_unit_groups(units_on_map=null):
	# create base groups for the units and add them to them
	#var units_on_map = root_map.get_all_units()
	if units_on_map == null:
		units_on_map = self.my_units_on_map
	
	for unit_wr in units_on_map:
		var unit_obj = gr(unit_wr)
		if unit_obj != null:
			var unit_id = unit_obj.unit_id
			
			# create a base group array
			if not unit_groups.has(unit_id):
				#var unit_wr = weakref(unit)
				var new_group = base_unit_group.duplicate(true)
				unit_groups[unit_id] = [new_group]
			
			add_unit_to_group(unit_wr)

func add_unit_to_group(unit_wr):
	# create groups of size 4
	var unit_id = unit_wr.get_ref().unit_id
	
	if unit_groups[unit_id][-1]["units"].size() < 4:
		unit_groups[unit_id][-1]["units"].append(unit_wr)
	else:
		var new_group = base_unit_group.duplicate(true)
		new_group["units"].append(unit_wr)
		unit_groups[unit_id].append(new_group)


func manage_defense_markers():
	send_groups_to_markers()
	
	check_range_units_pinned()
	
func manage_defense_castle():
	
	send_groups_to_markers()
	
	check_range_units_pinned()
	
	manage_doors()
	
func manage_attack():
	set_center_ow_own_forces()
	var neerest_enemy = get_neerest_enemy()
	
	if neerest_enemy != null:
		attack_unit_w_all(neerest_enemy)

func set_center_ow_own_forces():
	var total_position = Vector2.ZERO
	var all_units = 0
	
	for unit_wr in self.all_own_units():
		var unit = gr(unit_wr)
		if unit == null:
			continue
		total_position += unit.global_position  # Sum up global positions
		all_units += 1

	self.own_forces_center = total_position / all_units


func get_neerest_enemy():
	var all_enemy_units = all_enemy_units()
	var nearest_node: Node2D = null
	var shortest_distance: float = INF  # Start with an infinitely large distance
	
	for unit in all_enemy_units:
		var distance = self.own_forces_center.distance_to(unit.global_position)
		
		if distance < shortest_distance:
			shortest_distance = distance
			nearest_node = unit
	
	return nearest_node


func attack_unit_w_all(enemy: Node2D):
	var own_units = all_own_units()
	
	for unit_wr in own_units:
		var enemy_wr = weakref(enemy)
		if gr(unit_wr) == null:
			continue
		gr(unit_wr).set_attack(enemy.map_unique_id)
	
func all_own_units():
	var own_units = []
	
	for unit_id in self.unit_groups:
		for group in self.unit_groups[unit_id]:
			for unit_wr in group["units"]:
				own_units.append(unit_wr)
	
	return own_units
	
func all_enemy_units():
	var all_units = root_map.get_all_units()
	var all_enemy_units = []
	
	for unit in all_units:
		if not (unit.faction == self.faction or unit.faction in self.friendly_factions):
			all_enemy_units.append(unit)
	
	return all_enemy_units

func send_groups_to_markers():
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
					if gr(unit_wr) == null:
						continue
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
	# or to send archers
	pass

func check_range_units_pinned():
	# check all ranged unit groups for being pinned
	# if they are pinned, check available unit goups around, if they are not already defending pinned
	# units, and send them to defend the ranged
	var ranged_units_ids= GlobalSettings.get_list_of_ranged()
	
	for unit_id in ranged_units_ids:
		if unit_id not in unit_groups:
			continue
		for group in unit_groups[unit_id]:
			var pinned_unit = null
			for unit_wr in group["units"]:
				var unit = gr(unit_wr)
				if unit == null:
					continue
				elif unit.is_pinned == true:
					pinned_unit = unit_wr
			if pinned_unit != null:
				# check which unit is pinning it at attack
				var pinning_unit_wr = gr(pinned_unit).units_pining_me[0]
				# all group target that guy
				group_sttack_unit(group, pinning_unit_wr)
				# and the closest other group
				var group_helping = get_neerest_group_help(pinned_unit, group)
				if group_helping != null:
					group_sttack_unit(group_helping, pinning_unit_wr)

func get_neerest_group_help(unit_in_need_wr, group_seeking_help):
	var groups_by_distance = []
	var unit_in_need_obj = gr(unit_in_need_wr)
	
	for type_group in unit_groups:
		for group in unit_groups[type_group]:
			if group != group_seeking_help:
				var units_by_distance = []
				
				for unit_wr in group["units"]:
					var unit_obj = gr(unit_wr)
					if unit_obj != null:
						var distance = int(unit_in_need_obj.global_position.distance_to(unit_obj.global_position))
						units_by_distance.append([unit_obj, distance])
					
					if units_by_distance.size() != 0:
						units_by_distance.sort_custom(func(a, b): return a[1] < b[1])
						groups_by_distance.append([group, units_by_distance[0][1]])
	
	groups_by_distance.sort_custom(func(a, b): return a[1] < b[1])
	# check if they are not defending a pinning yet
	# ...
	if groups_by_distance.size() == 0:
		return null
	else:
		return groups_by_distance[0][0]


func group_sttack_unit(group, unit_to_attack_wr):
	for unit_wr in group["units"]:
		var unit = gr(unit_wr)
		var unit_to_attack = gr(unit_to_attack_wr)
		if unit != null and unit_to_attack != null:
			unit.set_attack(unit_to_attack.map_unique_id)

func manage_doors():
	for door_rule in root_map.get_node("map_rules").defense_script["door_closure"]:	
		for door_id in door_rule["doors_to_te_destroyed"]:
			var is_destroyed = true
			
			for door_wr in doors:
				var door = gr(door_wr)
				
				if door == null:
					continue
				elif door_id == door.siege_id:
					is_destroyed = false
			
			# if didnt find the door on the map
			if is_destroyed == true:
				for door_id_2 in door_rule["doors_tc_close"]:
					for door_wr in doors:
						var door = gr(door_wr)
						if door == null:
							continue
						elif door_id_2 == door.siege_id:
							set_doors(door_id_2, 0)


func get_all_doors():
	for unit in root_map.get_node("units").get_children():
		if "is_small_door" in unit and unit.faction == faction:
			doors.append(weakref(unit))

func set_inner_doors(state:int):
	# 1 is open, 0 is closed
	
	get_all_doors()
	for unit_wr in doors:
		var unit = gr(unit_wr)
		if unit == null:
			continue
		if unit.faction == faction:
			if unit.main_door == false:
				unit.get_node("actions").set_state(state)
				
func set_doors(siege_id, state:int):
	# 1 is open, 0 is closed
	for unit_wr in doors:
		var unit = gr(unit_wr)
		if unit == null:
			continue
		elif unit.siege_id == siege_id and unit.faction == faction:
			unit.get_node("actions").set_state(state)


func empty_dead_units():
	# remove dead units from control groups
	var all_units_count = 0
	
	for type_group in unit_groups:
		for group in unit_groups[type_group]:
			for unit_wr in group["units"]:
				if gr(unit_wr) == null:
					var index_ = group["units"].find(unit_wr)
					group["units"].remove_at(index_)
				else:
					all_units_count += 1
	
	#remove destroyed doors
	for unit_wr in doors:
		if gr(unit_wr) == null:
			var index_ = doors.find(unit_wr)
			doors.remove_at(index_)
	
	if all_units_count == 0:
		self.lost = true

func gr(weak_refer):
	if weak_refer == null:
		return null
	if weak_refer.get_ref() == null:
		return null
	else:
		return weak_refer.get_ref()
