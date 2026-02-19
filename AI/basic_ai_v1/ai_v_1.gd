extends Node2D

enum MapTypes { OPEN, CASTLE }
var map_type = MapTypes.OPEN

enum State { IDLE, ATTACKING, DEFENDING }
var current_state = State.IDLE # ATM just for digging
var state_ = 0 #  0 iddle, 1 attack, 2 defend
@export var is_siege = false
@export var is_siege_defending = true
@export var ai_paused := false  # set true in inspector to disable all AI (for FPS testing)

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
const FREE_ALL_FACTIONS := -1  # pass to _temp_free_unit_positions to free all units regardless of faction
@export var debug_regions = false
# One-time assignment: move units to walls/checkpoints only once at start; do not reassign when units die
var siege_defense_positions_assigned = false
# Delay before closing inner doors after breach so defenders can fall back (ms)
const BREACH_DOOR_CLOSE_DELAY_MS := 5000
var breach_close_allowed_at: Dictionary = {}  # door_rule index -> time (msec) when we may close
# Melee: which region each unit was assigned to (map_unique_id -> region_id) for fallback-only moves
var melee_unit_assigned_region: Dictionary = {}
const CASTLE_WALL_UNIT_IDS := [8]  # cauldron / boiling oil; move to wall next to siege slots and outer door
const CASTLE_DOOR_UNIT_IDS := [500, 501, 502]  # door/structure units (base_castle_unit); no set_move, skip in melee/archer assignment
const ENEMY_RAM_UNIT_ID := 7
const ENEMY_SIEGE_TOWER_UNIT_ID := 9
const OWN_RAM_UNIT_ID := 7
const OWN_SIEGE_TOWER_UNIT_ID := 9

# Besieger (attacker) state: phased advance toward gate, hold while siege engines work, assault breached regions, or full breach
enum BesiegerPhase { APPROACHING, HOLDING_AT_GATE, ASSAULT_BREACHED_REGIONS, BREACHED }
var besieger_phase = BesiegerPhase.APPROACHING
var besieger_attack_data_built = false
var enemy_door_units: Array = []   # [weakref(door), ...] doors to destroy (from defense_script doors_to_te_destroyed)
var besieger_gate_position = Vector2.ZERO  # rally point for non-siege blob
var besieger_slot_world_positions: Array = []  # [Vector2, ...] for siege towers
const BESIEGER_HOLD_THRESHOLD_CELLS := 5.0  # close enough to wait position = holding
const BESIEGER_WAIT_OFFSET_CELLS := 23.0  # non-siege wait this many cells back from the gate so they don't cluster at the wall
var besieger_tower_slot_assigned: Dictionary = {}  # unit map_unique_id -> slot index (so we don't reassign every tick)
# Besieger region data: when we have a tower at a breach slot, we have access to these regions (inside the wall)
var besieger_region_by_tile: Dictionary = {}  # Vector2i -> region_id
var besieger_region_rally: Array = []  # [Vector2] index = region_id, world rally position
var besieger_region_tiles: Dictionary = {}  # region_id -> Array[Vector2i] for "enemy in region" check
var besieger_outer_region_ids: Array = []  # region ids that border doors we're destroying (we can enter when wall breached)
var besieger_door_id_to_region_ids: Dictionary = {}  # door siege_id -> Array[region_id]; used to know which regions are accessible after a door is destroyed
var besieger_breach_slot_indices: Array = []  # slot indices that count as breach (from defense_script siege_slots_that_breach)
var besieger_accessible_region_ids: Array = []  # runtime: region ids we can enter this tick (door-breached or tower breach)
var besieger_outer_door_ids: Array = []   # siege_ids of outer doors (doors_to_te_destroyed) - rams only target these
var besieger_inner_door_ids: Array = []   # siege_ids of inner doors (doors_tc_close) - units destroy these after outer is breached
# Decision-tree state for non-siege besieger behaviour
var besieger_current_attack_target_id: int = -1   # map_unique_id of unit we're focusing; -1 if none
var besieger_region_attacking_id: int = -1       # region id we're focusing; -1 if none

@onready var root_map = get_tree().root.get_node("game") # 0 je global properties autoloader :/

# Called when the node enters the scene tree for the first time.
func _ready():
	if root_map.get_node("map_rules").map_type == "castle":
		map_type = MapTypes.CASTLE
	
	set_faction()
	get_my_units()
	var alive_at_ready = 0
	for u in my_units_on_map:
		if gr(u) != null:
			alive_at_ready += 1
	print("[AI faction %s] _ready: my_units_on_map=%s, alive=%s" % [faction, my_units_on_map.size(), alive_at_ready])
	set_units_to_defense_stance()
	# Defer first threat evaluation so spawners (and other deferred inits) can add units before we decide ATTACKING vs DEFENDING (and thus whether to open all doors)
	call_deferred("evaluate_threat", true)
	initial_setup()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if ai_paused:
		return
	# Debug region overlay redraws only when data changes (see build_siege_defense_data, _update_siege_breached_regions)

func _draw():
	if not debug_regions or map_type != MapTypes.CASTLE:
		return
	var tilemap = root_map.first_tilemap_layer
	var radius = 4.0
	# Defender: draw siege_regions (breached = red, else hue by region_id)
	if not siege_regions.is_empty():
		for reg in siege_regions:
			var color = Color.RED if reg["breached"] else Color.from_hsv(fmod(reg["region_id"] * 0.13, 1.0), 0.7, 0.9)
			for t in reg["tiles"]:
				var world_pos = tilemap.map_to_local(t) + tilemap.global_position
				var local_pos = to_local(world_pos)
				draw_circle(local_pos, radius, color)
	# Besieger: draw the 2 accessible regions (tower/door breach) with distinct colors
	if not is_siege_defending and besieger_attack_data_built and not besieger_accessible_region_ids.is_empty():
		var accessible_colors = [Color.GREEN, Color.CYAN]
		for idx in besieger_accessible_region_ids.size():
			var rid = besieger_accessible_region_ids[idx]
			var color = accessible_colors[idx] if idx < accessible_colors.size() else Color.from_hsv(fmod(rid * 0.2, 1.0), 1.0, 1.0)
			for t in besieger_region_tiles.get(rid, []):
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
		if unit.faction == self.faction or (self.friendly_factions != null and unit.faction in self.friendly_factions):
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
			if map_type == MapTypes.CASTLE:
				call_deferred("open_all_doors")
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
				if map_type == MapTypes.CASTLE:
					call_deferred("open_all_doors")
			else:
				current_state = State.DEFENDING
				print("Still Defending!")


func _on_timer_timeout():
	if ai_paused:
		return
	empty_dead_units()
	add_new_units_to_control()
	var alive = 0
	for u in my_units_on_map:
		if gr(u) != null:
			alive += 1
	var groups_total = 0
	for uid in unit_groups:
		for g in unit_groups[uid]:
			groups_total += g["units"].size()
	print("[AI faction %s] timer: my_units_on_map=%s alive=%s unit_groups_entries=%s" % [faction, my_units_on_map.size(), alive, groups_total])
	set_inner_doors(1)
	if self.lost:
		print("GG!")
		return
	evaluate_threat(false)
	# Branch by map type first, then state; on castle also by is_siege_defending
	if map_type == MapTypes.OPEN:
		if self.current_state == State.ATTACKING:
			open_map_attack()
		else:
			open_map_defend()
	else:
		# CASTLE
		if is_siege_defending:
			if self.current_state == State.ATTACKING:
				castle_defender_attack()
			else:
				print("[AI faction %s] defense stage 1: entering castle_defender_defend" % faction)
				castle_defender_defend()
		else:
			if self.current_state == State.ATTACKING:
				castle_besieger_attack()
			else:
				castle_besieger_defend()

func _on_cauldrin_timer_timeout():
	if ai_paused:
		return
	if map_type != MapTypes.CASTLE or not siege_defense_built or siege_regions.is_empty():
		return
	if current_state != State.DEFENDING:
		return
	_update_siege_breached_regions()
	move_castle_units_to_wall()

func initial_setup():	
	set_unit_groups()
	if map_type == MapTypes.CASTLE:
		call_deferred("build_siege_defense_data")
		if not is_siege_defending:
			call_deferred("build_siege_attack_data")

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


# --- Open map: attack / defend ---
func open_map_attack():
	var t = Time.get_ticks_msec() / 1000.0
	if last_rally_recalc_time > 0.0 and (t - last_rally_recalc_time) < RALLY_RECALC_INTERVAL_SEC:
		return
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

func open_map_defend():
	send_groups_to_markers()
	check_range_units_pinned()

# --- Castle: defender (holds the castle) ---
func castle_defender_attack():
	set_center_ow_own_forces()
	var neerest_enemy = get_neerest_enemy()
	if neerest_enemy != null:
		attack_unit_w_all(neerest_enemy)

func castle_defender_defend():
	print("[AI faction %s] defense stage 2: calling send_groups_to_markers" % faction)
	send_groups_to_markers()
	check_range_units_pinned()
	manage_doors()

# --- Castle: besieger (attacking the castle) ---
func castle_besieger_attack():
	if not besieger_attack_data_built:
		build_siege_attack_data()
	set_center_ow_own_forces()
	var tilemap = root_map.first_tilemap_layer
	var alive_doors = _get_alive_enemy_doors()
	var cell_size = float(root_map.m_cell_size)
	var wait_position = _get_besieger_wait_position(cell_size)
	var dist_to_wait = own_forces_center.distance_to(wait_position) if (own_forces_center != Vector2.ZERO) else INF
	var hold_threshold_px = BESIEGER_HOLD_THRESHOLD_CELLS * cell_size

	# Regions we can enter because their door was destroyed (ram breached it)
	var alive_door_siege_ids: Dictionary = {}
	for d in alive_doors:
		alive_door_siege_ids[d.siege_id] = true
	var door_breached_region_ids: Array = []
	for door_id in besieger_door_id_to_region_ids:
		if door_id in alive_door_siege_ids:
			continue
		for rid in besieger_door_id_to_region_ids[door_id]:
			if rid not in door_breached_region_ids:
				door_breached_region_ids.append(rid)
	var door_breached_rally_positions: Array = []
	for rid in door_breached_region_ids:
		if rid >= 0 and rid < besieger_region_rally.size():
			door_breached_rally_positions.append(besieger_region_rally[rid])
	# Accessible = door-breached regions; if we also have tower breach, we can target all outer regions
	var tower_breach_rally = _get_besieger_breached_region_rally_positions()
	var accessible_color_names = ["GREEN", "CYAN"]
	if not tower_breach_rally.is_empty():
		besieger_accessible_region_ids = besieger_outer_region_ids.duplicate()
		var color_list = []
		for idx in besieger_accessible_region_ids.size():
			var rid = besieger_accessible_region_ids[idx]
			var cname = accessible_color_names[idx] if idx < accessible_color_names.size() else ("hue_" + str(rid))
			color_list.append("rid %d=%s" % [rid, cname])
		print("[castle_besieger_attack] set accessible from TOWER_BREACH, count: ", besieger_accessible_region_ids.size(), " | ", ", ".join(color_list))
	else:
		besieger_accessible_region_ids = door_breached_region_ids.duplicate()
		var color_list = []
		for idx in besieger_accessible_region_ids.size():
			var rid = besieger_accessible_region_ids[idx]
			var cname = accessible_color_names[idx] if idx < accessible_color_names.size() else ("hue_" + str(rid))
			color_list.append("rid %d=%s" % [rid, cname])
		print("[castle_besieger_attack] set accessible from DOOR_BREACHED, count: ", besieger_accessible_region_ids.size(), " | ", ", ".join(color_list))
	if debug_regions:
		queue_redraw()

	# Phase: full breach (no doors) -> attack; wall breach or door breached -> assault regions (units clear region, ram goes to next door); else hold or approach
	var breached_rally_positions: Array = tower_breach_rally.duplicate()
	for rp in door_breached_rally_positions:
		breached_rally_positions.append(rp)
	if alive_doors.is_empty():
		besieger_phase = BesiegerPhase.BREACHED
	elif not breached_rally_positions.is_empty():
		besieger_phase = BesiegerPhase.ASSAULT_BREACHED_REGIONS
	else:
		if dist_to_wait <= hold_threshold_px:
			besieger_phase = BesiegerPhase.HOLDING_AT_GATE
		else:
			besieger_phase = BesiegerPhase.APPROACHING

	# 1) Rams: send to outer doors only (skip if no outer doors - ram's job done)
	var alive_outer_doors = _get_alive_outer_doors()
	if not alive_outer_doors.is_empty():
		var rams: Array = []
		for unit_wr in all_own_units():
			var u = gr(unit_wr)
			if u != null and u.get("unit_id") == OWN_RAM_UNIT_ID:
				rams.append(unit_wr)
		for unit_wr in rams:
			var ram = gr(unit_wr)
			if ram == null:
				continue
			var current_target = ram.get_right_target()
			var actual_target = gr(current_target) if current_target != null else null
			var valid_door_target = false
			if actual_target != null:
				for d in alive_outer_doors:
					if d == actual_target:
						valid_door_target = true
						break
			if valid_door_target:
				continue
			var ram_tile = ram.unit_position
			var best_door = null
			var best_path_len = INF
			for door in alive_outer_doors:
				var door_tile = door.get("unit_position")
				if door_tile == null:
					door_tile = tilemap.local_to_map(door.global_position)
				var adj_tile = _get_adjacent_walkable_tile_to_door(door_tile)
				var path_len = _get_path_length_cells_for_ram(ram_tile, adj_tile)
				if path_len >= INF:
					continue
				if path_len < best_path_len:
					best_path_len = path_len
					best_door = door
			if best_door != null:
				var door_tile = best_door.get("unit_position")
				if door_tile == null:
					door_tile = tilemap.local_to_map(best_door.global_position)
				# set_move first (clears target), then set_attack (so ram keeps target to attack when in range)
				ram.set_move(_get_adjacent_walkable_to_door(door_tile))
				ram.set_attack(best_door.map_unique_id)

	# 2) Siege towers: move to wall slots
	var placed_node = root_map.get_node_or_null("siege_walls/placed_loc")
	for uid in besieger_tower_slot_assigned.duplicate().keys():
		var found = false
		for unit_wr in all_own_units():
			var u = gr(unit_wr)
			if u != null and u.map_unique_id == uid:
				found = true
				break
		if not found:
			besieger_tower_slot_assigned.erase(uid)
	var used_slot_indices: Dictionary = {}
	if placed_node != null:
		for child in placed_node.get_children():
			if child is Node2D:
				var pt = tilemap.local_to_map(child.global_position)
				for i in besieger_slot_world_positions.size():
					if tilemap.local_to_map(besieger_slot_world_positions[i]).distance_to(pt) <= 1:
						used_slot_indices[i] = true
						break
	for uid in besieger_tower_slot_assigned:
		used_slot_indices[besieger_tower_slot_assigned[uid]] = true
	for unit_wr in all_own_units():
		var u = gr(unit_wr)
		if u == null or u.get("unit_id") != OWN_SIEGE_TOWER_UNIT_ID:
			continue
		var slot_idx = besieger_tower_slot_assigned.get(u.map_unique_id, -1)
		if slot_idx >= 0 and slot_idx < besieger_slot_world_positions.size():
			u.set_move(besieger_slot_world_positions[slot_idx])
			continue
		var best_slot = -1
		var best_dist = INF
		for i in besieger_slot_world_positions.size():
			if used_slot_indices.get(i, false):
				continue
			var d = u.global_position.distance_to(besieger_slot_world_positions[i])
			if d < best_dist:
				best_dist = d
				best_slot = i
		if best_slot >= 0:
			besieger_tower_slot_assigned[u.map_unique_id] = best_slot
			used_slot_indices[best_slot] = true
			u.set_move(besieger_slot_world_positions[best_slot])

	# 3) Non-siege: decision tree (rams/towers handled above)
	var path_from_tile = _get_besieger_non_siege_path_from_tile()

	# --- 1) Have a target: validate path, re-issue attack or clear and proceed ---
	if besieger_current_attack_target_id >= 0:
		var target_node = root_map.all_units_w_unique_id.get(besieger_current_attack_target_id)
		if target_node == null:
			besieger_current_attack_target_id = -1
		else:
			if _besieger_has_path_to_unit(path_from_tile, target_node):
				attack_non_siege_only(target_node)
				return
			besieger_current_attack_target_id = -1

	# --- 2) Region marked as attacking ---
	if besieger_region_attacking_id >= 0:
		var enemies_in_region = _get_enemies_in_region(besieger_region_attacking_id)
		if enemies_in_region.is_empty():
			besieger_region_attacking_id = -1
			besieger_current_attack_target_id = -1
		else:
			# Current target (if any) was already validated in step 1; here we need a target in this region
			var region_tiles = besieger_region_tiles.get(besieger_region_attacking_id, [])
			var tiles_set: Dictionary = {}
			for t in region_tiles:
				tiles_set[t] = true
			var current_valid = false
			if besieger_current_attack_target_id >= 0:
				var cur = root_map.all_units_w_unique_id.get(besieger_current_attack_target_id)
				if cur != null:
					var pt = cur.get("unit_position")
					if pt != null and tiles_set.get(pt, false):
						current_valid = true
			if current_valid:
				var cur = root_map.all_units_w_unique_id.get(besieger_current_attack_target_id)
				attack_non_siege_only(cur)
				return
			var nearest: Node2D = null
			var best_d = INF
			for en in enemies_in_region:
				var d = own_forces_center.distance_to(en.global_position)
				if d < best_d:
					best_d = d
					nearest = en
			if nearest != null:
				besieger_current_attack_target_id = nearest.map_unique_id
				attack_non_siege_only(nearest)
				return

	# --- 3) No region attacking: pick an accessible region with units and mark it ---
	var rid_with_units = _get_one_accessible_region_with_units()
	if rid_with_units >= 0:
		besieger_region_attacking_id = rid_with_units
		return

	# --- 4) Enemies outside regions (walkable tiles not in any region) ---
	var outside_enemies = _get_enemies_on_walkable_outside_regions()
	if not outside_enemies.is_empty():
		var nearest_out: Node2D = null
		var best_d = INF
		for en in outside_enemies:
			var d = own_forces_center.distance_to(en.global_position)
			if d < best_d:
				best_d = d
				nearest_out = en
		if nearest_out != null:
			attack_non_siege_only(nearest_out)
			return

	# --- 5) Outside doors not breached: rams or units attack outer door ---
	if not _besieger_outside_doors_breached():
		if not _has_any_rams() and not alive_outer_doors.is_empty():
			var nearest_door: Node2D = null
			var best_d = INF
			for d in alive_outer_doors:
				var dist = own_forces_center.distance_to(d.global_position)
				if dist < best_d:
					best_d = dist
					nearest_door = d
			if nearest_door != null:
				_attack_door_with_melee_only(nearest_door)
				_attack_door_with_ranged_only(nearest_door)
				return
		move_non_siege_to_position(wait_position)
		return

	# --- 6) No accessible enemies: attack any reachable door ---
	var reachable_doors = _get_besieger_reachable_doors()
	if not reachable_doors.is_empty():
		var nearest_door: Node2D = null
		var best_d = INF
		for d in reachable_doors:
			var dist = own_forces_center.distance_to(d.global_position)
			if dist < best_d:
				best_d = dist
				nearest_door = d
		if nearest_door != null:
			_attack_door_with_melee_only(nearest_door)
			_attack_door_with_ranged_only(nearest_door)
			return

	# --- 7) No reachable doors and no enemies: game won / wait for other systems ---
	return

func castle_besieger_defend():
	# Retreat to own PlayerStartLoc and defend there (open-map style formation).
	var rally = get_own_player_start_loc_position()
	if rally != null:
		computed_defense_positions = _build_defense_positions_around_center(rally)
	move_to_computed_defense_positions()
	check_range_units_pinned()

func set_center_ow_own_forces():
	var total_position = Vector2.ZERO
	var all_units = 0
	
	for unit_wr in self.all_own_units():
		var unit = gr(unit_wr)
		if unit == null:
			continue
		total_position += unit.global_position  # Sum up global positions
		all_units += 1

	if all_units > 0:
		self.own_forces_center = total_position / all_units
	# else leave own_forces_center unchanged to avoid division by zero

## Returns global position of the PlayerStartLoc for this AI's faction, or null if none.
func get_own_player_start_loc_position() -> Variant:
	var othr = root_map.get_node_or_null("othr")
	if othr == null:
		return null
	for child in othr.get_children():
		if child.get("faction") == self.faction:
			return child.global_position
	return null

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
	if debug_regions and map_type == MapTypes.CASTLE:
		queue_redraw()

func build_siege_attack_data():
	if besieger_attack_data_built or is_siege_defending:
		return
	if not siege_defense_built:
		build_siege_defense_data()
	var tilemap = root_map.first_tilemap_layer
	var map_rules = root_map.get_node_or_null("map_rules")
	# Order: outer doors (to_te_destroyed) first, then inner doors (tc_close)
	# Rams only target outer doors; units destroy inner doors after outer is breached
	var doors_to_destroy: Array = []
	besieger_outer_door_ids.clear()
	besieger_inner_door_ids.clear()
	if map_rules != null and map_rules.get("defense_script") != null and map_rules.defense_script.has("door_closure"):
		for rule in map_rules.defense_script["door_closure"]:
			for door_id in rule.get("doors_to_te_destroyed", []):
				if door_id not in doors_to_destroy:
					doors_to_destroy.append(door_id)
				if door_id not in besieger_outer_door_ids:
					besieger_outer_door_ids.append(door_id)
			for door_id in rule.get("doors_tc_close", []):
				if door_id not in doors_to_destroy:
					doors_to_destroy.append(door_id)
				if door_id not in besieger_inner_door_ids:
					besieger_inner_door_ids.append(door_id)
	enemy_door_units.clear()
	var gate_sum = Vector2.ZERO
	var gate_count = 0
	var all_enemy_door_tiles: Dictionary = {}
	var enemy_door_id_to_tiles: Dictionary = {}
	for unit in root_map.get_node("units").get_children():
		if unit.get("siege_id") == null:
			continue
		if unit.faction == faction or (friendly_factions != null and unit.faction in friendly_factions):
			continue
		if unit.siege_id not in doors_to_destroy:
			continue
		var uid = unit.get("unit_id")
		var is_door = unit.get("is_small_door") != null or (uid != null and uid in [500, 501, 502])
		if not is_door:
			continue
		enemy_door_units.append(weakref(unit))
		gate_sum += unit.global_position
		gate_count += 1
		var pos = unit.get("unit_position")
		if pos == null:
			pos = tilemap.local_to_map(unit.global_position)
		all_enemy_door_tiles[pos] = true
		if not enemy_door_id_to_tiles.has(unit.siege_id):
			enemy_door_id_to_tiles[unit.siege_id] = []
		enemy_door_id_to_tiles[unit.siege_id].append(pos)
	if gate_count > 0:
		besieger_gate_position = gate_sum / gate_count
	else:
		besieger_gate_position = root_map.global_position
	besieger_slot_world_positions.clear()
	for t in siege_slot_tiles:
		besieger_slot_world_positions.append(tilemap.map_to_local(t) + tilemap.global_position)

	# Besieger region data: same checkpoint flood fill but with enemy doors as blocked (so we know "inside" regions)
	besieger_region_by_tile.clear()
	besieger_region_rally.clear()
	besieger_region_tiles.clear()
	besieger_outer_region_ids.clear()
	besieger_breach_slot_indices.clear()
	var checkpoints_node = root_map.get_node_or_null("checkpoints")
	if checkpoints_node != null:
		var freed = _temp_free_unit_positions(FREE_ALL_FACTIONS)
		var flags = checkpoints_node.get_children()
		for i in flags.size():
			var flag = flags[i]
			var seed_tile = tilemap.local_to_map(flag.global_position)
			var tiles_arr = _flood_fill_blocked(seed_tile, all_enemy_door_tiles, SIEGE_REGION_FLOOD_MAX)
			if tiles_arr.is_empty():
				tiles_arr = [seed_tile]
			var sum_v = Vector2.ZERO
			for t in tiles_arr:
				sum_v += tilemap.map_to_local(t)
				besieger_region_by_tile[t] = i
			var center_world = (sum_v / tiles_arr.size()) + tilemap.global_position
			besieger_region_rally.append(center_world)
			besieger_region_tiles[i] = tiles_arr
		_temp_restore_unit_positions(freed)
		# Which regions border the doors we're destroying?
		var besieger_door_to_regions: Dictionary = {}
		for sid in enemy_door_id_to_tiles:
			var reg_set = {}
			for t in enemy_door_id_to_tiles[sid]:
				for offset in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
					var n = t + offset
					if besieger_region_by_tile.has(n):
						reg_set[besieger_region_by_tile[n]] = true
			besieger_door_to_regions[sid] = reg_set.keys()
		besieger_door_id_to_region_ids = besieger_door_to_regions.duplicate(true)
		for door_id in doors_to_destroy:
			if besieger_door_to_regions.has(door_id):
				for rid in besieger_door_to_regions[door_id]:
					if rid not in besieger_outer_region_ids:
						besieger_outer_region_ids.append(rid)
		# Breach slot indices from defense_script
		if map_rules != null and map_rules.get("defense_script") != null and map_rules.defense_script.has("door_closure"):
			for rule in map_rules.defense_script["door_closure"]:
				var slot_indices = rule.get("siege_slots_that_breach", [])
				if slot_indices is String and slot_indices == "all":
					besieger_breach_slot_indices = range(siege_slot_tiles.size()).duplicate()
					break
				elif slot_indices is Array:
					for idx in slot_indices:
						if idx not in besieger_breach_slot_indices:
							besieger_breach_slot_indices.append(idx)

	besieger_attack_data_built = true

## Returns list of door nodes (alive, health > 0) that are "to be destroyed". Caller can use for rams / breach check.
func _get_alive_enemy_doors() -> Array:
	var out: Array = []
	for door_wr in enemy_door_units:
		var door = gr(door_wr)
		if door != null:
			var h = door.get("health")
			if h != null and h <= 0:
				continue  # dead but not yet freed
			out.append(door)
	return out

## Returns alive outer doors only (doors_to_te_destroyed). Rams target these.
func _get_alive_outer_doors() -> Array:
	var all_alive = _get_alive_enemy_doors()
	var out: Array = []
	for d in all_alive:
		if d.siege_id in besieger_outer_door_ids:
			out.append(d)
	return out

## Returns alive inner doors only (doors_tc_close). Units destroy these after outer door is breached.
func _get_alive_inner_doors() -> Array:
	var all_alive = _get_alive_enemy_doors()
	var out: Array = []
	for d in all_alive:
		if d.siege_id in besieger_inner_door_ids:
			out.append(d)
	return out

## World position where non-siege units wait (further back from the gate so they don't cluster at the wall).
func _get_besieger_wait_position(cell_size: float) -> Vector2:
	var start_pos = get_own_player_start_loc_position()
	if start_pos == null:
		start_pos = own_forces_center
	var dir_to_gate = (besieger_gate_position - start_pos)
	var len = dir_to_gate.length()
	if len < 1.0:
		return besieger_gate_position
	dir_to_gate = dir_to_gate / len
	var offset_px = BESIEGER_WAIT_OFFSET_CELLS * cell_size
	return besieger_gate_position - dir_to_gate * offset_px

## One walkable tile adjacent to door_tile for ram to stand. Returns world position.
func _get_adjacent_walkable_to_door(door_tile: Vector2i) -> Vector2:
	var tilemap = root_map.first_tilemap_layer
	var adj = _get_adjacent_walkable_tile_to_door(door_tile)
	return tilemap.map_to_local(adj) + tilemap.global_position

## One walkable tile adjacent to door_tile (for pathfinding). Returns tile coords.
func _get_adjacent_walkable_tile_to_door(door_tile: Vector2i) -> Vector2i:
	var astar = root_map.astar_grid
	const CARDINALS := [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]
	for off in CARDINALS:
		var n = door_tile + off
		if astar.is_in_boundsv(n) and not astar.is_point_solid(n):
			return n
	return door_tile

## True if we have a siege tower deployed at the given slot index (wall breach from our side).
func _is_besieger_slot_breached(slot_idx: int) -> bool:
	if slot_idx < 0 or slot_idx >= siege_slot_tiles.size():
		return false
	var placed = root_map.get_node_or_null("siege_walls/placed_loc")
	if placed == null:
		return false
	var slot_tile = siege_slot_tiles[slot_idx]
	var tilemap = root_map.first_tilemap_layer
	for child in placed.get_children():
		if child is Node2D:
			var t = tilemap.local_to_map(child.global_position)
			if t.distance_to(slot_tile) <= 1:
				return true
	return false

## If we have a tower at any breach slot, returns world rally positions for regions we can now enter. Else empty.
func _get_besieger_breached_region_rally_positions() -> Array:
	var out: Array = []
	for idx in besieger_breach_slot_indices:
		if _is_besieger_slot_breached(idx):
			for rid in besieger_outer_region_ids:
				if rid >= 0 and rid < besieger_region_rally.size():
					out.append(besieger_region_rally[rid])
			break
	return out

## Enemies that are inside a region we have breached (tower at breach slot). Empty if no breach.
func _get_enemies_in_besieger_breached_regions() -> Array:
	var rally_positions = _get_besieger_breached_region_rally_positions()
	if rally_positions.is_empty():
		return []
	return _get_enemies_in_besieger_accessible_regions()

## Enemies currently in the region(s) we can enter (door gone or wall breached).
## Uses besieger_accessible_region_ids (set each tick: door-breached regions, or all outer if tower breach).
func _get_enemies_in_besieger_accessible_regions() -> Array:
	var out: Array = []
	var region_ids_to_use = besieger_accessible_region_ids if not besieger_accessible_region_ids.is_empty() else besieger_outer_region_ids
	if region_ids_to_use.is_empty():
		return out
	for unit in all_enemy_units():
		var pos = unit.get("unit_position")
		if pos == null:
			continue
		if not besieger_region_by_tile.has(pos):
			continue
		var rid = besieger_region_by_tile[pos]
		if rid in region_ids_to_use:
			out.append(unit)
	return out

## Tile to use as path-from for besieger non-siege (one of our units or gate).
func _get_besieger_non_siege_path_from_tile() -> Vector2i:
	var tilemap = root_map.first_tilemap_layer
	for unit_wr in all_own_units():
		var u = gr(unit_wr)
		if u == null or u.get("unit_id") == OWN_RAM_UNIT_ID or u.get("unit_id") == OWN_SIEGE_TOWER_UNIT_ID:
			continue
		var pos = u.get("unit_position")
		if pos != null:
			return pos
	return tilemap.local_to_map(besieger_gate_position)

## True if there is a path from from_tile to the unit's tile (for non-siege pathfinding).
func _besieger_has_path_to_unit(from_tile: Vector2i, unit: Node2D) -> bool:
	var pos = unit.get("unit_position")
	if pos == null:
		pos = root_map.first_tilemap_layer.local_to_map(unit.global_position)
	return _get_path_length_cells(from_tile, pos) < INF

## Enemies on tiles that are not inside any besieger region (e.g. in front of gate, approach).
func _get_enemies_on_walkable_outside_regions() -> Array:
	var out: Array = []
	for unit in all_enemy_units():
		var pos = unit.get("unit_position")
		if pos == null:
			continue
		if besieger_region_by_tile.has(pos):
			continue
		out.append(unit)
	return out

## Enemies whose unit_position is in the given region's tiles.
func _get_enemies_in_region(region_id: int) -> Array:
	if not besieger_region_tiles.has(region_id):
		return []
	var tiles_set: Dictionary = {}
	for t in besieger_region_tiles[region_id]:
		tiles_set[t] = true
	var out: Array = []
	for unit in all_enemy_units():
		var pos = unit.get("unit_position")
		if pos == null:
			continue
		if tiles_set.get(pos, false):
			out.append(unit)
	return out

## Accessible region ids that have path from our side and at least one enemy. Picks one at random when multiple.
func _get_one_accessible_region_with_units() -> int:
	var from_tile = _get_besieger_non_siege_path_from_tile()
	var tilemap = root_map.first_tilemap_layer
	var candidates: Array = []
	var skipped_no_path := 0
	var skipped_no_enemies := 0
	var all_enemies = all_enemy_units()
	for rid in besieger_accessible_region_ids:
		if rid < 0 or rid >= besieger_region_rally.size():
			continue
		var rally_world = besieger_region_rally[rid]
		var rally_tile = tilemap.local_to_map(rally_world)
		if _get_path_length_cells_ignore_units(from_tile, rally_tile) >= INF:
			skipped_no_path += 1
			continue
		var enemies_in_rid = _get_enemies_in_region(rid)
		if enemies_in_rid.is_empty():
			skipped_no_enemies += 1
			# Debug: why no enemies? total enemies vs in-region count, and sample enemy tile
			var region_tiles = besieger_region_tiles.get(rid, [])
			var tiles_set: Dictionary = {}
			for t in region_tiles:
				tiles_set[t] = true
			var in_region_count := 0
			for unit in all_enemies:
				var pos = unit.get("unit_position")
				if pos == null:
					continue
				var t = Vector2i(pos.x, pos.y)
				if tiles_set.get(t, false):
					in_region_count += 1
			print("[_get_one_accessible_region_with_units] rid ", rid, " | total_enemies: ", all_enemies.size(), " | in_region: ", in_region_count, " | region_tiles_count: ", region_tiles.size())
			if all_enemies.size() > 0 and in_region_count == 0:
				var sample = all_enemies[0]
				var pos = sample.get("unit_position")
				if pos == null:
					pos = tilemap.local_to_map(sample.global_position)
				var t = Vector2i(pos.x, pos.y)
				var in_set = tiles_set.get(t, false)
				var in_by_tile = besieger_region_by_tile.get(t, -999)
				print("  sample enemy tile: ", t, " | in_region_tiles: ", in_set, " | besieger_region_by_tile[t]: ", in_by_tile)
			continue
		candidates.append(rid)
	var result = -1 if candidates.is_empty() else candidates[randi() % candidates.size()]
	print("[_get_one_accessible_region_with_units] considered: ", besieger_accessible_region_ids.size(), " | skipped_no_path: ", skipped_no_path, " | skipped_no_enemies: ", skipped_no_enemies, " | candidates: ", candidates.size(), " | return rid: ", result)
	return result

## Alive enemy doors that have a path from our path-from tile (any door: outer or inner).
func _get_besieger_reachable_doors() -> Array:
	var from_tile = _get_besieger_non_siege_path_from_tile()
	var alive = _get_alive_enemy_doors()
	var out: Array = []
	for door in alive:
		var door_tile = door.get("unit_position")
		if door_tile == null:
			door_tile = root_map.first_tilemap_layer.local_to_map(door.global_position)
		var adj = _get_adjacent_walkable_tile_to_door(door_tile)
		if _get_path_length_cells(from_tile, adj) >= INF:
			continue
		out.append(door)
	return out

## True if outer doors have been breached (we have access to at least one region via door or tower).
func _besieger_outside_doors_breached() -> bool:
	return not besieger_accessible_region_ids.is_empty()

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
## When there are no siege towers, returns empty so cauldrins are sent to doors (ram threat) only.
func _get_castle_wall_slots_sorted_by_tower_threat() -> Array[Vector2]:
	var tower_positions = _get_enemy_siege_tower_positions()
	if tower_positions.is_empty():
		return []
	var tilemap = root_map.first_tilemap_layer
	const CARDINALS := [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]
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

## Path length in number of cells from start tile to end tile; INF if no path.
func _get_path_length_cells(from_tile: Vector2i, to_tile: Vector2i) -> float:
	var astar = root_map.astar_grid
	if not astar.is_in_boundsv(from_tile) or not astar.is_in_boundsv(to_tile):
		return INF
	var path = astar.get_id_path(from_tile, to_tile, false)
	if path.is_empty():
		return INF
	return float(path.size())

## Path length ignoring tiles blocked by units (so we know if a region is accessible but currently blocked).
func _get_path_length_cells_ignore_units(from_tile: Vector2i, to_tile: Vector2i) -> float:
	var astar = root_map.astar_grid
	if not astar.is_in_boundsv(from_tile) or not astar.is_in_boundsv(to_tile):
		return INF
	var unit_tiles: Dictionary = {}
	for unit in root_map.get_all_units():
		var pos = unit.get("unit_position")
		if pos == null:
			pos = root_map.first_tilemap_layer.local_to_map(unit.global_position)
		var t = Vector2i(pos.x, pos.y)
		if astar.is_in_boundsv(t) and not unit_tiles.has(t):
			unit_tiles[t] = astar.is_point_solid(t)
			astar.set_point_solid(t, false)
	var path = astar.get_id_path(from_tile, to_tile, false)
	for t in unit_tiles:
		astar.set_point_solid(t, unit_tiles[t])
	if path.is_empty():
		return INF
	return float(path.size())

## Returns tiles that rams must never path through (wall breach openings).
func _get_ram_blocked_tiles() -> Dictionary:
	var blocked: Dictionary = {}
	var placed = root_map.get_node_or_null("siege_walls/placed_loc")
	if placed == null:
		return blocked
	const CARDINALS := [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]
	for idx in besieger_breach_slot_indices:
		if not _is_besieger_slot_breached(idx):
			continue
		var slot_tile = siege_slot_tiles[idx]
		blocked[slot_tile] = true
		for off in CARDINALS:
			blocked[slot_tile + off] = true
	return blocked

## Path length for ram: same as _get_path_length_cells but breach tiles are unwalkable.
func _get_path_length_cells_for_ram(from_tile: Vector2i, to_tile: Vector2i) -> float:
	var astar = root_map.astar_grid
	if not astar.is_in_boundsv(from_tile) or not astar.is_in_boundsv(to_tile):
		return INF
	var blocked = _get_ram_blocked_tiles()
	if blocked.has(from_tile) or blocked.has(to_tile):
		return INF
	# Temporarily mark breach tiles solid
	var saved: Dictionary = {}  # tile -> was_solid
	for t in blocked:
		if astar.is_in_boundsv(t):
			saved[t] = astar.is_point_solid(t)
			astar.set_point_solid(t, true)
	var path = astar.get_id_path(from_tile, to_tile, false)
	# Restore
	for t in saved:
		astar.set_point_solid(t, saved[t])
	if path.is_empty():
		return INF
	return float(path.size())

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
	if debug_regions and map_type == MapTypes.CASTLE:
		queue_redraw()

## Temporarily free unit positions from astar so we see terrain-only solids.
## factions_to_free: null = own faction only; FREE_ALL_FACTIONS (-1) = all units; int = that faction; Array[int] = those factions.
## Returns list of positions freed; call _temp_restore_unit_positions with it after.
func _temp_free_unit_positions(factions_to_free: Variant = null) -> Array:
	var astar = root_map.astar_grid
	var freed: Array[Vector2i] = []
	var units_to_consider: Array = []
	if factions_to_free == null:
		for unit_wr in all_own_units():
			var u = gr(unit_wr)
			if u != null:
				units_to_consider.append(u)
	elif factions_to_free == FREE_ALL_FACTIONS:
		units_to_consider = root_map.get_all_units()
	elif factions_to_free is int:
		for unit in root_map.get_all_units():
			if unit.get("faction") == factions_to_free:
				units_to_consider.append(unit)
	elif factions_to_free is Array:
		for unit in root_map.get_all_units():
			if unit.get("faction") in factions_to_free:
				units_to_consider.append(unit)
	for unit in units_to_consider:
		var pos = unit.get("unit_position")
		if pos == null:
			continue
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

## Same formation as _build_dynamic_defense_positions but centered on a fixed world position (e.g. PlayerStartLoc).
func _build_defense_positions_around_center(center_world: Vector2) -> Dictionary:
	var enemies = all_enemy_units()
	var enemy_center: Vector2 = center_world + Vector2(100, 0)
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
	var best = _find_best_defense_center(center_world, enemy_center, unit_count)
	_temp_restore_unit_positions(freed)
	var tilemap = root_map.first_tilemap_layer
	var ranged_ids = GlobalSettings.get_list_of_ranged()
	if ranged_ids == null:
		ranged_ids = []
	if best.is_empty():
		best = {"center_tile": tilemap.local_to_map(center_world), "tiles": [tilemap.local_to_map(center_world)], "away_from_enemy": (center_world - enemy_center).normalized() if center_world.distance_to(enemy_center) > 1.0 else Vector2(0, 1)}
	var away = best["away_from_enemy"]
	var center_world_from_best = tilemap.map_to_local(best["center_tile"])
	var tiles_arr: Array = best["tiles"]
	tiles_arr.sort_custom(func(a, b): return center_world_from_best.distance_squared_to(tilemap.map_to_local(a)) < center_world_from_best.distance_squared_to(tilemap.map_to_local(b)))
	var melee_positions: Array[Vector2] = []
	var ranged_positions: Array[Vector2] = []
	for i in tiles_arr.size():
		var t: Vector2i = tiles_arr[i]
		var w = tilemap.map_to_local(t)
		var along = (w - center_world_from_best).dot(away)
		if along > 0:
			ranged_positions.append(w)
		else:
			melee_positions.append(w)
	if ranged_positions.is_empty() and melee_positions.is_empty():
		melee_positions.append(center_world_from_best)
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

func move_non_siege_to_position(world_pos: Vector2):
	for unit_wr in all_own_units():
		var u = gr(unit_wr)
		if u == null:
			continue
		if u.get("unit_id") == OWN_RAM_UNIT_ID or u.get("unit_id") == OWN_SIEGE_TOWER_UNIT_ID:
			continue
		u.set_move(world_pos)


func attack_unit_w_all(enemy: Node2D):
	var own_units = all_own_units()
	
	for unit_wr in own_units:
		var enemy_wr = weakref(enemy)
		if gr(unit_wr) == null:
			continue
		gr(unit_wr).set_attack(enemy.map_unique_id)

func attack_non_siege_only(enemy: Node2D):
	for unit_wr in all_own_units():
		var u = gr(unit_wr)
		if u == null:
			continue
		if u.get("unit_id") == OWN_RAM_UNIT_ID or u.get("unit_id") == OWN_SIEGE_TOWER_UNIT_ID:
			continue
		u.set_attack(enemy.map_unique_id)

func _has_any_rams() -> bool:
	for unit_wr in all_own_units():
		var u = gr(unit_wr)
		if u != null and u.get("unit_id") == OWN_RAM_UNIT_ID:
			return true
	return false

func _has_any_melee() -> bool:
	var ranged_ids = GlobalSettings.get_list_of_ranged()
	if ranged_ids == null:
		ranged_ids = []
	for unit_wr in all_own_units():
		var u = gr(unit_wr)
		if u == null or u.get("unit_id") == OWN_RAM_UNIT_ID or u.get("unit_id") == OWN_SIEGE_TOWER_UNIT_ID:
			continue
		if u.unit_id not in ranged_ids:
			return true
	return false

func _attack_door_with_melee_only(door: Node2D):
	var ranged_ids = GlobalSettings.get_list_of_ranged()
	if ranged_ids == null:
		ranged_ids = []
	for unit_wr in all_own_units():
		var u = gr(unit_wr)
		if u == null or u.get("unit_id") == OWN_RAM_UNIT_ID or u.get("unit_id") == OWN_SIEGE_TOWER_UNIT_ID:
			continue
		if u.unit_id in ranged_ids:
			continue
		u.set_attack(door.map_unique_id)

func _attack_door_with_ranged_only(door: Node2D):
	var ranged_ids = GlobalSettings.get_list_of_ranged()
	if ranged_ids == null:
		ranged_ids = []
	for unit_wr in all_own_units():
		var u = gr(unit_wr)
		if u == null or u.get("unit_id") == OWN_RAM_UNIT_ID or u.get("unit_id") == OWN_SIEGE_TOWER_UNIT_ID:
			continue
		if u.unit_id not in ranged_ids:
			continue
		u.set_attack(door.map_unique_id)
	
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
		if not (unit.faction == self.faction or (self.friendly_factions != null and unit.faction in self.friendly_factions)):
			all_enemy_units.append(unit)
	
	return all_enemy_units

func send_groups_to_markers():
	print("[AI faction %s] defense stage 3: send_groups_to_markers map_type=%s" % [faction, "OPEN" if map_type == MapTypes.OPEN else "CASTLE"])
	if map_type == MapTypes.OPEN:
		move_to_computed_defense_positions()
	else:
		print("[AI faction %s] defense stage 3b: castle branch siege_defense_built=%s siege_regions.size()=%s" % [faction, siege_defense_built, siege_regions.size()])
		if siege_defense_built and not siege_regions.is_empty():
			print("[AI faction %s] defense stage 3c: condition passed, siege_defense_positions_assigned=%s" % [faction, siege_defense_positions_assigned])
			_update_siege_breached_regions()
			# Archers and melee: assign only once (so dead units don't pull others away from frontline)
			if not siege_defense_positions_assigned:
				print("[AI faction %s] defense stage 3d: calling move_archers_to_walls_by_enemy and move_melee_to_siege_regions" % faction)
				move_archers_to_walls_by_enemy()
				move_melee_to_siege_regions()
				siege_defense_positions_assigned = true
			else:
				# Only move units from breached regions to fallback; don't shuffle everyone
				move_melee_from_breached_regions_to_fallback()
			# Cauldrins: updated by CauldrinTimer every 4s (see _on_cauldrin_timer_timeout)
		else:
			print("[AI faction %s] defense stage 3b SKIP: siege_defense_built and not siege_regions.is_empty() is false, not sending units" % faction)

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
	print("[AI faction %s] defense stage 4: move_melee_to_siege_regions entered" % faction)
	var ranged_ids = GlobalSettings.get_list_of_ranged()
	if ranged_ids == null:
		ranged_ids = []
	# Build (flag_position, region_id) so we can record which region each unit is assigned to
	var target_slots: Array = []  # [{ "position": Vector2, "region_id": int }]
	for rid in siege_regions.size():
		var reg = siege_regions[rid]
		if reg["breached"] and breach_fallback_region.has(rid):
			var fallback_id = breach_fallback_region[rid]
			if fallback_id < siege_regions.size():
				target_slots.append({"position": siege_regions[fallback_id]["flag_position"], "region_id": rid})
		elif not reg["breached"]:
			target_slots.append({"position": reg["flag_position"], "region_id": rid})
	print("[AI faction %s] defense stage 4b: target_slots.size()=%s" % [faction, target_slots.size()])
	if target_slots.is_empty():
		print("[AI faction %s] defense stage 4 SKIP: target_slots empty, not sending melee" % faction)
		return
	var slot_index = 0
	var melee_sent = 0
	for unit_id in unit_groups:
		if unit_id in ranged_ids or unit_id in CASTLE_WALL_UNIT_IDS or unit_id in CASTLE_DOOR_UNIT_IDS:
			continue
		for group in unit_groups[unit_id]:
			for unit_wr in group["units"]:
				var u = gr(unit_wr)
				if u == null:
					continue
				var slot = target_slots[slot_index % target_slots.size()]
				u.set_move(slot["position"])
				melee_unit_assigned_region[u.map_unique_id] = slot["region_id"]
				slot_index += 1
				melee_sent += 1
	print("[AI faction %s] defense stage 4 done: sent %s melee to siege regions" % [faction, melee_sent])

func move_melee_from_breached_regions_to_fallback():
	var ranged_ids = GlobalSettings.get_list_of_ranged()
	if ranged_ids == null:
		ranged_ids = []
	for unit_id in unit_groups:
		if unit_id in ranged_ids or unit_id in CASTLE_WALL_UNIT_IDS or unit_id in CASTLE_DOOR_UNIT_IDS:
			continue
		for group in unit_groups[unit_id]:
			for unit_wr in group["units"]:
				var u = gr(unit_wr)
				if u == null:
					continue
				if not melee_unit_assigned_region.has(u.map_unique_id):
					continue
				var rid = melee_unit_assigned_region[u.map_unique_id]
				if rid >= siege_regions.size():
					continue
				if not siege_regions[rid]["breached"] or not breach_fallback_region.has(rid):
					continue
				var fallback_id = breach_fallback_region[rid]
				if fallback_id >= siege_regions.size():
					continue
				u.set_move(siege_regions[fallback_id]["flag_position"])
				melee_unit_assigned_region[u.map_unique_id] = fallback_id

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
	# Gather living cauldrins
	var cauldrins: Array = []
	for unit_id in CASTLE_WALL_UNIT_IDS:
		if unit_id not in unit_groups:
			continue
		for group in unit_groups[unit_id]:
			for unit_wr in group["units"]:
				var u = gr(unit_wr)
				if u != null:
					cauldrins.append(u)
	if cauldrins.is_empty():
		return
	# Assign each position (in threat order) to the closest unassigned cauldrin so we don't shuffle them
	var assigned: Array[bool] = []
	assigned.resize(cauldrins.size())
	for j in cauldrins.size():
		assigned[j] = false
	var n_assign = mini(positions.size(), cauldrins.size())
	for idx in n_assign:
		var pos = positions[idx]
		var best_j = -1
		var best_dist_sq := INF
		for j in cauldrins.size():
			if assigned[j]:
				continue
			var d_sq = cauldrins[j].global_position.distance_squared_to(pos)
			if d_sq < best_dist_sq:
				best_dist_sq = d_sq
				best_j = j
		if best_j >= 0:
			assigned[best_j] = true
			cauldrins[best_j].set_move(pos)

func move_archers_to_walls_by_enemy():
	print("[AI faction %s] defense stage 5: move_archers_to_walls_by_enemy entered siege_regions.size()=%s" % [faction, siege_regions.size()])
	var ranged_ids = GlobalSettings.get_list_of_ranged()
	if ranged_ids == null:
		ranged_ids = []
	if siege_regions.is_empty():
		print("[AI faction %s] defense stage 5 SKIP: siege_regions empty, not sending archers" % faction)
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
	var archers_sent = 0
	for unit_id in ranged_ids:
		if unit_id not in unit_groups or unit_id in CASTLE_DOOR_UNIT_IDS:
			continue
		for group in unit_groups[unit_id]:
			for unit_wr in group["units"]:
				var u = gr(unit_wr)
				if u == null:
					continue
				var pos = flag_positions[pos_index % flag_positions.size()]
				u.set_move(pos)
				pos_index += 1
				archers_sent += 1
	print("[AI faction %s] defense stage 5 done: sent %s archers to flag_positions (count=%s)" % [faction, archers_sent, flag_positions.size()])

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
	var now_ms = Time.get_ticks_msec()
	var rules = map_rules.defense_script["door_closure"]
	for rule_idx in rules.size():
		var door_rule = rules[rule_idx]
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
		if not should_close:
			breach_close_allowed_at.erase(rule_idx)
			continue
		if not breach_close_allowed_at.has(rule_idx):
			breach_close_allowed_at[rule_idx] = now_ms + BREACH_DOOR_CLOSE_DELAY_MS
		if now_ms < breach_close_allowed_at[rule_idx]:
			continue
		for door_id_2 in door_rule.get("doors_tc_close", []):
			set_doors(door_id_2, 0)


func get_all_doors():
	doors.clear()
	for unit in root_map.get_node("units").get_children():
		if "is_small_door" in unit and unit.faction == faction:
			doors.append(weakref(unit))

func set_inner_doors(state:int):
	# 1 is open, 0 is closed. Only touch "inner" doors (doors_tc_close); never open outer/front (doors_to_te_destroyed).
	get_all_doors()
	var inner_door_siege_ids: Dictionary = {}
	if map_type == MapTypes.CASTLE:
		var map_rules = root_map.get_node_or_null("map_rules")
		if map_rules != null and map_rules.get("defense_script") != null and map_rules.defense_script.has("door_closure"):
			for rule in map_rules.defense_script["door_closure"]:
				for door_id in rule.get("doors_tc_close", []):
					inner_door_siege_ids[door_id] = true
	for unit_wr in doors:
		var unit = gr(unit_wr)
		if unit == null:
			continue
		if unit.faction != faction:
			continue
		var should_touch = false
		if not inner_door_siege_ids.is_empty():
			should_touch = unit.get("siege_id") != null and inner_door_siege_ids.has(unit.siege_id)
		else:
			should_touch = unit.main_door == false
		if should_touch:
			unit.get_node("actions").set_state(state)

func open_all_doors():
	# Open every gate so units can go out to attack (siege sally-out)
	get_all_doors()
	for unit_wr in doors:
		var unit = gr(unit_wr)
		if unit == null:
			continue
		if unit.faction == faction:
			unit.get_node("actions").set_state(1)
				
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

## Add any faction units that are on the map but not yet in my_units_on_map / unit_groups (e.g. from spawners that run after AI _ready).
func add_new_units_to_control():
	for unit in root_map.get_all_units():
		if unit.faction != faction and (friendly_factions == null or unit.faction not in friendly_factions):
			continue
		var already_tracked = false
		for unit_wr in my_units_on_map:
			if unit_wr.get_ref() == unit:
				already_tracked = true
				break
		if already_tracked:
			continue
		var unit_wr = weakref(unit)
		my_units_on_map.append(unit_wr)
		var unit_id = unit.unit_id
		if not unit_groups.has(unit_id):
			var new_group = base_unit_group.duplicate(true)
			unit_groups[unit_id] = [new_group]
		add_unit_to_group(unit_wr)
		if map_type == MapTypes.CASTLE and "stance" in unit:
			var ranged_ids = GlobalSettings.get_list_of_ranged()
			if ranged_ids == null or unit.unit_id not in ranged_ids:
				unit.stance = 1

func gr(weak_refer):
	if weak_refer == null:
		return null
	if weak_refer.get_ref() == null:
		return null
	else:
		return weak_refer.get_ref()
