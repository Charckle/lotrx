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
var faction_set_externally = false

var my_units_on_map = []
var unit_groups: Dictionary = {}

var own_forces_center = Vector2.ZERO

# Open-map attack: rally then engage; recalc only every X sec or on arrival
enum OpenAttackPhase { ADVANCING, ENGAGING }
var open_attack_phase = OpenAttackPhase.ADVANCING
var enemy_forces_center = Vector2.ZERO
var last_rally_recalc_time = 0.0
const RALLY_RECALC_INTERVAL_SEC := 4.0
var current_target_world = Vector2.ZERO
var open_attack_waypoints: Array = []
var current_waypoint_index = 0
const ARRIVAL_THRESHOLD_CELLS := 2
const SEGMENT_LENGTH_CELLS := 8
const MARGIN_OUTSIDE_RANGE_CELLS := 2

# Open-map dynamic defense: chokepoint / crescent formation (decide once, move there, defend)
const DEFENSE_FLOOD_RADIUS := 10
const DEFENSE_SEARCH_RADIUS := 4
const DEFENSE_APPROACH_SAMPLE_HALF := 6
var computed_defense_positions: Dictionary = {}  # unit_id -> [Vector2, ...]

var lost = false

var base_unit_group = {"units": [],
				"task": null}

var doors = []

# Siege defense: regions from checkpoints, doors as boundaries, fallback on breach
var siege_defense_built = false
var door_id_to_tiles: Dictionary = {}  # siege_id -> Array[Vector2i]
var all_door_tiles: Dictionary = {}   # Vector2i -> true for fast lookup
var siege_regions: Array = []        # [{ region_id, tiles, center_world, rally, breached }]
var region_by_tile: Dictionary = {}  # Vector2i -> region_id (int)
var breach_fallback_region: Dictionary = {}  # region_id -> fallback_region_id
var siege_slot_tiles: Array = []     # [Vector2i, ...] per slot index
var door_to_regions: Dictionary = {} # siege_id -> Array[region_id]
const SIEGE_REGION_FLOOD_MAX := 500  # max tiles per checkpoint region
@export var debug_regions = false
# 0 = move ranged + castle units this tick; 1 = move melee next tick (stagger)
var siege_defense_phase = 0
const CASTLE_WALL_UNIT_IDS := [8]  # cauldron / boiling oil; move to wall next to siege slots and outer door
const ENEMY_RAM_UNIT_ID := 7
const ENEMY_SIEGE_TOWER_UNIT_ID := 9

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
	if debug_regions and map_type == MapTypes.CASTLE:
		queue_redraw()

func _draw():
	if not debug_regions or map_type != MapTypes.CASTLE or siege_regions.is_empty():
		return
	var tilemap = root_map.first_tilemap_layer
	var radius = 4.0
	for reg in siege_regions:
		var color = Color.RED if reg["breached"] else Color.from_hsv(fmod(reg["region_id"] * 0.13, 1.0), 0.7, 0.9)
		for t in reg["tiles"]:
			var world_pos = tilemap.map_to_local(t) + tilemap.global_position
			var local_pos = to_local(world_pos)
			draw_circle(local_pos, radius, color)

func set_faction():
	# If faction was set externally (e.g. spawned from multiplayer lobby), don't override
	if not faction_set_externally:
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
				if "stance" in unit_obj and unit_obj.unit_id not in GlobalSettings.get_list_of_ranged():
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
			last_rally_recalc_time = 0.0
			open_attack_phase = OpenAttackPhase.ADVANCING
		else:
			current_state = State.DEFENDING
			computed_defense_positions.clear()
			print("Starting Defense!")
	else:
		if current_state == State.ATTACKING:
			# if their > own * 1.2 = defense
			if their_side > my_side * 1.2:
				current_state = State.DEFENDING
				computed_defense_positions.clear()
				print("Starting Defense!")
			else:
				current_state = State.ATTACKING
				print("Still Attacking!")
		else:
			# if own > their * 1.2 = attack
			if my_side > their_side * 1.2:
				print("Starting Attack!")
				current_state = State.ATTACKING
				last_rally_recalc_time = 0.0
				open_attack_phase = OpenAttackPhase.ADVANCING
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
	set_unit_groups()
	if map_type == MapTypes.CASTLE:
		call_deferred("build_siege_defense_data")

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
	if map_type == MapTypes.CASTLE:
		set_center_ow_own_forces()
		var neerest_enemy = get_neerest_enemy()
		if neerest_enemy != null:
			attack_unit_w_all(neerest_enemy)
		return

	# Open map: rally then engage; recalc only every RALLY_RECALC_INTERVAL_SEC (or on first run)
	var t = Time.get_ticks_msec() / 1000.0
	if last_rally_recalc_time > 0.0 and (t - last_rally_recalc_time) < RALLY_RECALC_INTERVAL_SEC:
		return  # no recalc this tick; do nothing

	set_center_ow_own_forces()
	var enemies = all_enemy_units()
	if enemies.is_empty():
		return

	if open_attack_phase == OpenAttackPhase.ENGAGING:
		var nearest = get_neerest_enemy()
		if nearest != null:
			attack_unit_w_all(nearest)
		last_rally_recalc_time = t
		return

	var arr = get_enemy_forces_center_and_max_range()
	enemy_forces_center = arr[0]
	var max_enemy_range_px: float = arr[1]
	var dir = (enemy_forces_center - own_forces_center)
	var dist = dir.length()
	var cell_size = float(root_map.m_cell_size)
	var arrival_px = ARRIVAL_THRESHOLD_CELLS * cell_size
	var dist_small_threshold = (SEGMENT_LENGTH_CELLS * 2) * cell_size

	if dist < dist_small_threshold:
		open_attack_phase = OpenAttackPhase.ENGAGING
		var nearest = get_neerest_enemy()
		if nearest != null:
			attack_unit_w_all(nearest)
		last_rally_recalc_time = t
		return

	open_attack_waypoints = build_open_attack_waypoints(own_forces_center, enemy_forces_center, max_enemy_range_px)
	if open_attack_waypoints.is_empty():
		open_attack_phase = OpenAttackPhase.ENGAGING
		var nearest = get_neerest_enemy()
		if nearest != null:
			attack_unit_w_all(nearest)
		last_rally_recalc_time = t
		return

	# Find first waypoint we haven't arrived at (waypoints are fresh each recalc)
	current_waypoint_index = 0
	while current_waypoint_index < open_attack_waypoints.size():
		current_target_world = open_attack_waypoints[current_waypoint_index]
		if own_forces_center.distance_to(current_target_world) > arrival_px:
			break
		current_waypoint_index += 1

	if current_waypoint_index >= open_attack_waypoints.size():
		open_attack_phase = OpenAttackPhase.ENGAGING
		var nearest = get_neerest_enemy()
		if nearest != null:
			attack_unit_w_all(nearest)
		current_waypoint_index = 0
		last_rally_recalc_time = t
		return

	current_target_world = open_attack_waypoints[current_waypoint_index]
	move_all_to_position(current_target_world)
	last_rally_recalc_time = t

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


func get_enemy_forces_center_and_max_range() -> Array:
	var enemies = all_enemy_units()
	if enemies.is_empty():
		return [Vector2.ZERO, 0.0]
	var sum_pos = Vector2.ZERO
	var max_range_cells: float = 0.0
	for unit in enemies:
		sum_pos += unit.global_position
		var attack_r = unit.get("attack_range")
		var aggro_r = unit.get("agression_range")
		var r = 1.0
		if attack_r != null:
			r = maxf(r, float(attack_r))
		if aggro_r != null:
			r = maxf(r, float(aggro_r))
		if r > max_range_cells:
			max_range_cells = r
	var center = sum_pos / enemies.size()
	var max_range_px = max_range_cells * root_map.m_cell_size
	return [center, max_range_px]


## Flood fill from seed tile, returns {area: int, tiles: Array} with walkable tiles within max_radius.
func _flood_fill_area(seed_tile: Vector2i, max_radius: int) -> Dictionary:
	var astar = root_map.astar_grid
	if not astar.is_in_boundsv(seed_tile) or astar.is_point_solid(seed_tile):
		return {"area": 0, "tiles": []}
	var visited := {}
	var queue: Array[Vector2i] = [seed_tile]
	var tiles: Array[Vector2i] = []
	while queue.size() > 0:
		var tile: Vector2i = queue.pop_back()
		if visited.has(tile):
			continue
		if not astar.is_in_boundsv(tile):
			continue
		if astar.is_point_solid(tile):
			continue
		var dist = seed_tile.distance_to(tile)
		if dist > max_radius:
			continue
		visited[tile] = true
		tiles.append(tile)
		for offset in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
			queue.append(tile + offset)
	return {"area": tiles.size(), "tiles": tiles}

## Flood fill from seed; do not step on tiles in blocked_tiles (e.g. door tiles). No radius limit by default; cap at max_tiles.
func _flood_fill_blocked(seed_tile: Vector2i, blocked_tiles: Dictionary, max_tiles: int) -> Array[Vector2i]:
	var astar = root_map.astar_grid
	if not astar.is_in_boundsv(seed_tile):
		return []
	if blocked_tiles.has(seed_tile):
		return []
	var visited := {}
	var queue: Array[Vector2i] = [seed_tile]
	var tiles: Array[Vector2i] = []
	while queue.size() > 0 and tiles.size() < max_tiles:
		var tile: Vector2i = queue.pop_back()
		if visited.has(tile):
			continue
		if not astar.is_in_boundsv(tile):
			continue
		if blocked_tiles.has(tile):
			continue
		# Treat solid on astar as blocked (walls, etc.) unless we're only blocking doors
		if astar.is_point_solid(tile):
			continue
		visited[tile] = true
		tiles.append(tile)
		for offset in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
			queue.append(tile + offset)
	return tiles

func build_siege_defense_data():
	if siege_defense_built:
		return
	var tilemap = root_map.first_tilemap_layer
	var astar = root_map.astar_grid
	door_id_to_tiles.clear()
	all_door_tiles.clear()
	siege_regions.clear()
	region_by_tile.clear()
	breach_fallback_region.clear()
	siege_slot_tiles.clear()

	# 1) Door tiles from all door-like units (same faction + castle structures)
	for unit in root_map.get_node("units").get_children():
		if unit.get("siege_id") == null:
			continue
		var uid = unit.get("unit_id")
		var is_door = unit.get("is_small_door") != null or (uid != null and uid in [500, 501, 502])
		if not is_door:
			continue
		if unit.faction != faction:
			continue
		var pos = unit.get("unit_position")
		if pos == null:
			pos = tilemap.local_to_map(unit.global_position)
		var sid = unit.siege_id
		if not door_id_to_tiles.has(sid):
			door_id_to_tiles[sid] = []
		door_id_to_tiles[sid].append(pos)
		all_door_tiles[pos] = true

	# 2) Regions from checkpoints (flood fill, door tiles blocked; units removed so no unit holes)
	var checkpoints_node = root_map.get_node_or_null("checkpoints")
	if checkpoints_node == null:
		siege_defense_built = true
		return
	var freed = _temp_free_unit_positions()
	var flags = checkpoints_node.get_children()
	for i in flags.size():
		var flag = flags[i]
		var seed_tile = tilemap.local_to_map(flag.global_position)
		var tiles_arr = _flood_fill_blocked(seed_tile, all_door_tiles, SIEGE_REGION_FLOOD_MAX)
		if tiles_arr.is_empty():
			tiles_arr = [seed_tile]
		var sum_v = Vector2.ZERO
		for t in tiles_arr:
			sum_v += tilemap.map_to_local(t)
			region_by_tile[t] = i
		var center_world = sum_v / tiles_arr.size()
		siege_regions.append({
			"region_id": i,
			"tiles": tiles_arr,
			"center_world": center_world,
			"rally": center_world,
			"flag_position": flag.global_position,
			"breached": false
		})
	_temp_restore_unit_positions(freed)

	# 3) Door -> which regions border this door
	door_to_regions.clear()
	for sid in door_id_to_tiles:
		var reg_set = {}
		for t in door_id_to_tiles[sid]:
			for offset in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
				var n = t + offset
				if region_by_tile.has(n):
					reg_set[region_by_tile[n]] = true
		door_to_regions[sid] = reg_set.keys()

	# 4) Fallback from door_closure: when outer door is destroyed, fallback = region containing inner door
	var map_rules = root_map.get_node_or_null("map_rules")
	if map_rules != null and map_rules.get("defense_script") != null and map_rules.defense_script.has("door_closure"):
		for rule in map_rules.defense_script["door_closure"]:
			var to_destroy = rule.get("doors_to_te_destroyed", [])
			var to_close = rule.get("doors_tc_close", [])
			var inner_region_id = -1
			for door_id in to_close:
				if not door_id_to_tiles.has(door_id):
					continue
				for t in door_id_to_tiles[door_id]:
					if region_by_tile.has(t):
						inner_region_id = region_by_tile[t]
						break
				if inner_region_id >= 0:
					break
			if inner_region_id < 0:
				continue
			for door_id in to_destroy:
				if not door_to_regions.has(door_id):
					continue
				for rid in door_to_regions[door_id]:
					if rid != inner_region_id:
						breach_fallback_region[rid] = inner_region_id

	# 5) Siege wall slots (available_loc)
	var loc_node = root_map.get_node_or_null("siege_walls/available_loc")
	if loc_node != null:
		for child in loc_node.get_children():
			siege_slot_tiles.append(tilemap.local_to_map(child.global_position))

	siege_defense_built = true

func _get_castle_wall_positions() -> Array[Vector2]:
	var tilemap = root_map.first_tilemap_layer
	var seen: Dictionary = {}
	var out: Array[Vector2] = []
	const CARDINALS := [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]
	for slot_tile in siege_slot_tiles:
		for off in CARDINALS:
			var n = slot_tile + off
			if region_by_tile.has(n) and not seen.has(n):
				seen[n] = true
				out.append(tilemap.map_to_local(n) + tilemap.global_position)
	var map_rules = root_map.get_node_or_null("map_rules")
	if map_rules != null and map_rules.get("defense_script") != null and map_rules.defense_script.has("door_closure"):
		for rule in map_rules.defense_script["door_closure"]:
			for door_id in rule.get("doors_to_te_destroyed", []):
				if not door_id_to_tiles.has(door_id):
					continue
				for t in door_id_to_tiles[door_id]:
					for off in CARDINALS:
						var n = t + off
						if region_by_tile.has(n) and not seen.has(n):
							seen[n] = true
							out.append(tilemap.map_to_local(n) + tilemap.global_position)
	return out

## Enemy siege weapon positions for cauldron threat sorting
func _get_enemy_ram_positions() -> Array[Vector2]:
	var out: Array[Vector2] = []
	for unit in all_enemy_units():
		if unit.get("unit_id") == ENEMY_RAM_UNIT_ID:
			out.append(unit.global_position)
	return out

func _get_enemy_siege_tower_positions() -> Array[Vector2]:
	var out: Array[Vector2] = []
	for unit in all_enemy_units():
		if unit.get("unit_id") == ENEMY_SIEGE_TOWER_UNIT_ID:
			out.append(unit.global_position)
	var placed_node = root_map.get_node_or_null("siege_walls/placed_loc")
	if placed_node != null:
		for child in placed_node.get_children():
			if child is Node2D:
				out.append(child.global_position)
	return out

## One position per siege wall slot, sorted by distance to nearest siege tower (closest threat first).
func _get_castle_wall_slots_sorted_by_tower_threat() -> Array[Vector2]:
	var tilemap = root_map.first_tilemap_layer
	const CARDINALS := [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]
	var tower_positions = _get_enemy_siege_tower_positions()
	var slots_with_dist: Array = []  # { position, distance }
	for slot_tile in siege_slot_tiles:
		var best_pos: Vector2 = tilemap.map_to_local(slot_tile) + tilemap.global_position
		var found = false
		for off in CARDINALS:
			var n = slot_tile + off
			if region_by_tile.has(n):
				found = true
				best_pos = tilemap.map_to_local(n) + tilemap.global_position
				break
		if not found:
			continue
		var dist := INF
		if tower_positions.is_empty():
			dist = 0.0
		else:
			for tp in tower_positions:
				var d = best_pos.distance_to(tp)
				if d < dist:
					dist = d
		slots_with_dist.append({"position": best_pos, "distance": dist})
	slots_with_dist.sort_custom(func(a, b): return a["distance"] < b["distance"])
	var out: Array[Vector2] = []
	for entry in slots_with_dist:
		out.append(entry["position"])
	return out

## One position per outer door (doors_to_te_destroyed), sorted by distance to nearest ram (closest threat first).
func _get_castle_door_positions_sorted_by_ram_threat() -> Array[Vector2]:
	var tilemap = root_map.first_tilemap_layer
	const CARDINALS := [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]
	var ram_positions = _get_enemy_ram_positions()
	var map_rules = root_map.get_node_or_null("map_rules")
	if map_rules == null or map_rules.get("defense_script") == null or not map_rules.defense_script.has("door_closure"):
		return []
	var seen_door_ids: Dictionary = {}
	var doors_with_dist: Array = []
	for rule in map_rules.defense_script["door_closure"]:
		for door_id in rule.get("doors_to_te_destroyed", []):
			if not door_id_to_tiles.has(door_id) or seen_door_ids.has(door_id):
				continue
			seen_door_ids[door_id] = true
			var best_pos: Vector2 = Vector2.ZERO
			var found = false
			for t in door_id_to_tiles[door_id]:
				for off in CARDINALS:
					var n = t + off
					if region_by_tile.has(n):
						found = true
						best_pos = tilemap.map_to_local(n) + tilemap.global_position
						break
				if found:
					break
			if not found:
				continue
			var dist := INF
			if ram_positions.is_empty():
				dist = 0.0
			else:
				for rp in ram_positions:
					var d = best_pos.distance_to(rp)
					if d < dist:
						dist = d
			doors_with_dist.append({"position": best_pos, "distance": dist})
	doors_with_dist.sort_custom(func(a, b): return a["distance"] < b["distance"])
	var out: Array[Vector2] = []
	for entry in doors_with_dist:
		out.append(entry["position"])
	return out

func _is_siege_slot_breached(slot_tile: Vector2i) -> bool:
	var placed = root_map.get_node_or_null("siege_walls/placed_loc")
	if placed == null:
		return false
	for child in placed.get_children():
		var t = root_map.first_tilemap_layer.local_to_map(child.global_position)
		if t.distance_to(slot_tile) <= 1:
			return true
	return false

func _update_siege_breached_regions():
	if not siege_defense_built or siege_regions.is_empty():
		return
	var map_rules = root_map.get_node_or_null("map_rules")
	var door_closure_rules = []
	if map_rules != null and map_rules.get("defense_script") != null and map_rules.defense_script.has("door_closure"):
		door_closure_rules = map_rules.defense_script["door_closure"]

	# Reset breached
	for i in siege_regions.size():
		siege_regions[i]["breached"] = false

	# Mark breached: outer door gone or linked siege slot has tower
	for rule in door_closure_rules:
		var to_destroy = rule.get("doors_to_te_destroyed", [])
		var slot_indices = rule.get("siege_slots_that_breach", [])
		if slot_indices is String and slot_indices == "all":
			slot_indices = range(siege_slot_tiles.size()).duplicate()
		var should_close = false
		for door_id in to_destroy:
			var found_alive = false
			for door_wr in doors:
				var d = gr(door_wr)
				if d != null and d.siege_id == door_id:
					found_alive = true
					break
			if not found_alive:
				should_close = true
				break
		if not should_close and slot_indices is Array:
			for idx in slot_indices:
				if idx >= 0 and idx < siege_slot_tiles.size() and _is_siege_slot_breached(siege_slot_tiles[idx]):
					should_close = true
					break
		if not should_close:
			continue
		var to_close = rule.get("doors_tc_close", [])
		var inner_region_id = -1
		for door_id in to_close:
			if not door_id_to_tiles.has(door_id):
				continue
			for t in door_id_to_tiles[door_id]:
				if region_by_tile.has(t):
					inner_region_id = region_by_tile[t]
					break
			if inner_region_id >= 0:
				break
		# Mark outer region(s) that border the destroyed door as breached
		for door_id in to_destroy:
			if not door_to_regions.has(door_id):
				continue
			for rid in door_to_regions[door_id]:
				if rid != inner_region_id and rid < siege_regions.size():
					siege_regions[rid]["breached"] = true

## Temporarily free all own unit positions from astar so we see terrain-only solids.
## Returns list of positions freed; call _temp_restore_unit_positions with it after.
func _temp_free_unit_positions() -> Array:
	var astar = root_map.astar_grid
	var freed: Array[Vector2i] = []
	for unit_wr in all_own_units():
		var u = gr(unit_wr)
		if u == null:
			continue
		var pos = u.unit_position
		if astar.is_point_solid(pos):
			astar.set_point_solid(pos, false)
			freed.append(pos)
	return freed

## Restore unit positions to astar after terrain-only analysis.
func _temp_restore_unit_positions(freed: Array) -> void:
	var astar = root_map.astar_grid
	for pos in freed:
		astar.set_point_solid(pos)

## Count guarded sides (terrain/map edge) with directional weighting: rear > flank > front.
func _count_guarded_sides_weighted(center_tile: Vector2i, away_from_enemy: Vector2) -> float:
	var astar = root_map.astar_grid
	const CARDINALS = [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]
	var score := 0.0
	for offset in CARDINALS:
		var n = center_tile + offset
		if not astar.is_in_boundsv(n) or astar.is_point_solid(n):
			var dir = Vector2(offset.x, offset.y).normalized()
			var dot = dir.dot(away_from_enemy)
			if dot > 0.3:
				score += 3.0
			elif dot < -0.3:
				score += 1.0
			else:
				score += 2.0
	return score

## Measure approach width: how many walkable tiles along a perpendicular line (from enemy side).
## Lower = better chokepoint.
func _measure_approach_width(center_tile: Vector2i, away_from_enemy: Vector2) -> int:
	var astar = root_map.astar_grid
	var perp = Vector2(-away_from_enemy.y, away_from_enemy.x)
	var width_count := 0
	for i in range(-DEFENSE_APPROACH_SAMPLE_HALF, DEFENSE_APPROACH_SAMPLE_HALF + 1):
		var tile = center_tile + Vector2i(roundi(perp.x * i), roundi(perp.y * i))
		if astar.is_in_boundsv(tile) and not astar.is_point_solid(tile):
			width_count += 1
	return width_count

## Find best defense center near own_forces_center: fits unit_count, maximizes chokepoint score.
## Returns {center_tile, tiles} or empty dict if none found.
func _find_best_defense_center(own_center_world: Vector2, enemy_center_world: Vector2, unit_count: int) -> Dictionary:
	var tilemap = root_map.first_tilemap_layer
	var astar = root_map.astar_grid
	var center_tile = tilemap.local_to_map(own_center_world)
	var enemy_dir := Vector2.ZERO
	if own_center_world.distance_to(enemy_center_world) > 1.0:
		enemy_dir = (own_center_world - enemy_center_world).normalized()
	else:
		enemy_dir = Vector2(0, 1)
	var away_from_enemy = enemy_dir
	var best: Dictionary = {}
	var best_score := -INF
	for dx in range(-DEFENSE_SEARCH_RADIUS, DEFENSE_SEARCH_RADIUS + 1):
		for dy in range(-DEFENSE_SEARCH_RADIUS, DEFENSE_SEARCH_RADIUS + 1):
			var seed_t = center_tile + Vector2i(dx, dy)
			if not astar.is_in_boundsv(seed_t):
				continue
			if astar.is_point_solid(seed_t):
				continue
			var result = _flood_fill_area(seed_t, DEFENSE_FLOOD_RADIUS)
			var area = result["area"]
			if area < unit_count:
				continue
			var approach_width = _measure_approach_width(seed_t, away_from_enemy)
			var bottleneck_ratio = area / maxf(approach_width, 1)
			var guarded_score = _count_guarded_sides_weighted(seed_t, away_from_enemy)
			var score = -approach_width * 2.0 + bottleneck_ratio * 0.5 + guarded_score
			if score > best_score:
				best_score = score
				best = {"center_tile": seed_t, "tiles": result["tiles"], "away_from_enemy": away_from_enemy}
	if best.is_empty():
		return {}
	return best

## Build crescent formation: ranged further from enemy, melee in arc in front.
## Returns {unit_id: [Vector2, ...]}.
func _build_dynamic_defense_positions() -> Dictionary:
	set_center_ow_own_forces()
	var enemies = all_enemy_units()
	var own_center = own_forces_center
	var enemy_center: Vector2 = own_center + Vector2(100, 0)
	if not enemies.is_empty():
		var arr = get_enemy_forces_center_and_max_range()
		enemy_center = arr[0]
	var unit_count = 0
	for unit_id in unit_groups:
		for group in unit_groups[unit_id]:
			for unit_wr in group["units"]:
				if gr(unit_wr) != null:
					unit_count += 1
	if unit_count == 0:
		return {}
	var freed = _temp_free_unit_positions()
	var best = _find_best_defense_center(own_center, enemy_center, unit_count)
	_temp_restore_unit_positions(freed)
	var tilemap = root_map.first_tilemap_layer
	var ranged_ids = GlobalSettings.get_list_of_ranged()
	if ranged_ids == null:
		ranged_ids = []
	if best.is_empty():
		best = {"center_tile": tilemap.local_to_map(own_center), "tiles": [tilemap.local_to_map(own_center)], "away_from_enemy": (own_center - enemy_center).normalized() if own_center.distance_to(enemy_center) > 1.0 else Vector2(0, 1)}
	var away = best["away_from_enemy"]
	var center_world = tilemap.map_to_local(best["center_tile"])
	var tiles_arr: Array = best["tiles"]
	tiles_arr.sort_custom(func(a, b): return center_world.distance_squared_to(tilemap.map_to_local(a)) < center_world.distance_squared_to(tilemap.map_to_local(b)))
	var melee_positions: Array[Vector2] = []
	var ranged_positions: Array[Vector2] = []
	for i in tiles_arr.size():
		var t: Vector2i = tiles_arr[i]
		var w = tilemap.map_to_local(t)
		var along = (w - center_world).dot(away)
		if along > 0:
			ranged_positions.append(w)
		else:
			melee_positions.append(w)
	if ranged_positions.is_empty() and melee_positions.is_empty():
		melee_positions.append(center_world)
	if ranged_positions.is_empty():
		ranged_positions = melee_positions.duplicate()
	if melee_positions.is_empty():
		melee_positions = ranged_positions.duplicate()
	var out: Dictionary = {}
	for unit_id in unit_groups:
		var is_ranged = ranged_ids != null and unit_id in ranged_ids
		var positions: Array[Vector2] = ranged_positions.duplicate() if is_ranged else melee_positions.duplicate()
		var list: Array = []
		for p in positions:
			list.append(p)
		out[unit_id] = list
	return out

func build_open_attack_waypoints(own_center: Vector2, enemy_center: Vector2, max_enemy_range_px: float) -> Array:
	var tilemap = root_map.first_tilemap_layer
	var cell_size = float(root_map.m_cell_size)
	var dir = (enemy_center - own_center)
	var dist = dir.length()
	if dist < 1.0:
		return []
	dir = dir.normalized()
	var segment_px = SEGMENT_LENGTH_CELLS * cell_size
	var margin_px = MARGIN_OUTSIDE_RANGE_CELLS * cell_size
	var last_hop_dist = dist - max_enemy_range_px - margin_px
	if last_hop_dist <= 0.0:
		return []
	var waypoints: Array = []
	var traveled = 0.0
	while traveled < last_hop_dist:
		traveled += segment_px
		if traveled > last_hop_dist:
			traveled = last_hop_dist
		var wp_world = own_center + dir * traveled
		var wp_tile = tilemap.local_to_map(wp_world)
		wp_world = tilemap.map_to_local(wp_tile)
		waypoints.append(wp_world)
		if traveled >= last_hop_dist:
			break
	return waypoints


func move_all_to_position(world_pos: Vector2):
	for unit_wr in all_own_units():
		var u = gr(unit_wr)
		if u != null:
			u.set_move(world_pos)


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
	if map_type == MapTypes.OPEN:
		move_to_computed_defense_positions()
	else:
		if siege_defense_built and not siege_regions.is_empty():
			_update_siege_breached_regions()
			if siege_defense_phase == 0:
				move_archers_to_walls_by_enemy()
				move_castle_units_to_wall()
				siege_defense_phase = 1
			else:
				move_melee_to_siege_regions()
				siege_defense_phase = 0

func move_to_computed_defense_positions():
	if computed_defense_positions.is_empty():
		computed_defense_positions = _build_dynamic_defense_positions()
		if computed_defense_positions.is_empty():
			return
		for unit_id in unit_groups:
			var positions = computed_defense_positions.get(unit_id, [])
			if positions.is_empty():
				continue
			var to_pos_index = 0
			for group in unit_groups[unit_id]:
				for unit_wr in group["units"]:
					var u = gr(unit_wr)
					if u == null:
						continue
					var pos: Vector2 = positions[to_pos_index % positions.size()]
					u.set_move(pos)
					to_pos_index += 1

func move_melee_to_siege_regions():
	var ranged_ids = GlobalSettings.get_list_of_ranged()
	if ranged_ids == null:
		ranged_ids = []
	var target_flag_positions: Array[Vector2] = []
	for rid in siege_regions.size():
		var reg = siege_regions[rid]
		if reg["breached"] and breach_fallback_region.has(rid):
			var fallback_id = breach_fallback_region[rid]
			if fallback_id < siege_regions.size():
				target_flag_positions.append(siege_regions[fallback_id]["flag_position"])
		elif not reg["breached"]:
			target_flag_positions.append(reg["flag_position"])
	if target_flag_positions.is_empty():
		return
	var pos_index = 0
	for unit_id in unit_groups:
		if unit_id in ranged_ids or unit_id in CASTLE_WALL_UNIT_IDS:
			continue
		for group in unit_groups[unit_id]:
			for unit_wr in group["units"]:
				var u = gr(unit_wr)
				if u == null:
					continue
				var flag_pos = target_flag_positions[pos_index % target_flag_positions.size()]
				u.set_move(flag_pos)
				pos_index += 1

func move_castle_units_to_wall():
	var wall_slots := _get_castle_wall_slots_sorted_by_tower_threat()
	var door_positions := _get_castle_door_positions_sorted_by_ram_threat()
	# Alternate between the two lists; if one runs out, keep taking from the other
	var positions: Array[Vector2] = []
	var n_wall = wall_slots.size()
	var n_door = door_positions.size()
	var i = 0
	while i < n_wall or i < n_door:
		if i < n_wall:
			positions.append(wall_slots[i])
		if i < n_door:
			positions.append(door_positions[i])
		i += 1
	if positions.is_empty():
		# Fallback: no slots/doors or no threat data
		positions = _get_castle_wall_positions()
	if positions.is_empty():
		return
	var pos_index = 0
	for unit_id in CASTLE_WALL_UNIT_IDS:
		if unit_id not in unit_groups:
			continue
		for group in unit_groups[unit_id]:
			for unit_wr in group["units"]:
				var u = gr(unit_wr)
				if u == null:
					continue
				var pos = positions[pos_index % positions.size()]
				u.set_move(pos)
				pos_index += 1

func move_archers_to_walls_by_enemy():
	var ranged_ids = GlobalSettings.get_list_of_ranged()
	if ranged_ids == null:
		ranged_ids = []
	if siege_regions.is_empty():
		return
	var enemy_center = own_forces_center + Vector2(200, 0)
	var enemies = all_enemy_units()
	if not enemies.is_empty():
		var arr = get_enemy_forces_center_and_max_range()
		enemy_center = arr[0]
	var flag_positions: Array = []
	for reg in siege_regions:
		flag_positions.append(reg["flag_position"])
	flag_positions.sort_custom(func(a, b): return enemy_center.distance_squared_to(a) < enemy_center.distance_squared_to(b))
	var pos_index = 0
	for unit_id in ranged_ids:
		if unit_id not in unit_groups:
			continue
		for group in unit_groups[unit_id]:
			for unit_wr in group["units"]:
				var u = gr(unit_wr)
				if u == null:
					continue
				var pos = flag_positions[pos_index % flag_positions.size()]
				u.set_move(pos)
				pos_index += 1

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
	var map_rules = root_map.get_node("map_rules")
	if map_rules.get("defense_script") == null or not map_rules.defense_script.has("door_closure"):
		return
	for door_rule in map_rules.defense_script["door_closure"]:
		var to_destroy = door_rule.get("doors_to_te_destroyed", [])
		var slot_indices = door_rule.get("siege_slots_that_breach", [])
		if slot_indices is String and slot_indices == "all":
			slot_indices = range(siege_slot_tiles.size()).duplicate()
		var should_close = false
		for door_id in to_destroy:
			var is_destroyed = true
			for door_wr in doors:
				var door = gr(door_wr)
				if door == null:
					continue
				if door_id == door.siege_id:
					is_destroyed = false
					break
			if is_destroyed:
				should_close = true
				break
		if not should_close and slot_indices is Array:
			for idx in slot_indices:
				if idx >= 0 and idx < siege_slot_tiles.size() and _is_siege_slot_breached(siege_slot_tiles[idx]):
					should_close = true
					break
		if should_close:
			for door_id_2 in door_rule.get("doors_tc_close", []):
				set_doors(door_id_2, 0)


func get_all_doors():
	doors.clear()
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
