extends Node2D

const reload_cooldown = 5      # same as archer cooldown
const burst_interval = 0.6     # short delay between burst shots
const burst_count = 2          # arrows per burst

var can_attack = true
var shots_fired = 0
var burst_target_id = null     # locked target during a burst
var locked_target = null       # persistent weakref across bursts (lock-on)
var current_height = 0

@onready var local_old_unit_position = null
@onready var main_r = get_tree().root.get_node("game")
@onready var parent_n = get_parent()
@onready var arrow = load("res://weapons/range/arrow/arrow.tscn")
@onready var siege_deployed = load("res://units/other_units/siege_tower/siege_deployed/siege_deployed.tscn")

func _ready() -> void:
	$ReloadTimer.wait_time = reload_cooldown
	$BurstTimer.wait_time = burst_interval

func _process(delta: float) -> void:
	# Height-based range bonus (runs on all peers, same as archer)
	var title_map_node = parent_n.title_map_node
	var first_tilemap_layer = parent_n.first_tilemap_layer
	var unit_position = parent_n.unit_position

	if unit_position != local_old_unit_position:
		var height = 0
		for layer_num in range(title_map_node.get_child_count()):
			var layer = title_map_node.get_child(layer_num)
			var tile_global_position = first_tilemap_layer.map_to_local(unit_position)
			var layer_tile_position = layer.local_to_map(tile_global_position)
			var tile_data_ = layer.get_cell_tile_data(layer_tile_position)
			if tile_data_ != null:
				var new_height = tile_data_.get_custom_data("HIGH_G")
				if new_height and (new_height > height):
					height = new_height
					current_height = new_height

		var multiplier = 3
		parent_n.attack_rage_px = parent_n.attack_rage_px_base + ((height * multiplier) * parent_n.root_map.m_cell_size)
		local_old_unit_position = unit_position

	# Multiplayer cut-off
	if not multiplayer.is_server():
		return

	# Clear lock-on when moving
	if parent_n.is_moving:
		locked_target = null
		return

	# Clear lock-on if target died or out of range
	if locked_target != null:
		if gr(locked_target) == null or not in_range(locked_target):
			locked_target = null

	# Autonomous targeting + burst fire
	if can_attack:
		# Find new target if we don't have one
		if locked_target == null:
			var enemy = find_closest_enemy()
			if enemy != null:
				locked_target = weakref(enemy)

		if locked_target != null and gr(locked_target) != null:
			start_burst.rpc(gr(locked_target).map_unique_id)


# --- Target acquisition (autonomous, no player input) ---

func find_closest_enemy():
	var close_units = []
	for unit in main_r.get_all_units():
		if unit == parent_n:
			continue
		if unit.unit_id >= 500: # skip castle structures (doors, portcullis, etc.)
			continue
		if unit.faction == parent_n.faction or unit.faction in parent_n.friendly_factions:
			continue
		var distance = int(global_position.distance_to(unit.global_position))
		var in_range_ = parent_n.aggression_rage_px - distance
		if in_range_ > 0:
			close_units.append([unit, in_range_])

	if close_units.is_empty():
		return null

	close_units.sort_custom(func(a, b): return a[1] > b[1])
	return close_units[0][0]


# --- Burst fire logic ---

@rpc("authority", "call_local", "reliable")
func start_burst(right_target_id):
	can_attack = false
	shots_fired = 0
	burst_target_id = right_target_id
	_fire_one_shot()

func _fire_one_shot():
	# Validate target is still alive
	if burst_target_id == null or burst_target_id not in main_r.all_units_w_unique_id:
		burst_target_id = null
		$ReloadTimer.start()
		return

	var att_object = weakref(main_r.all_units_w_unique_id[burst_target_id])

	if in_range(att_object):
		var instance = arrow.instantiate()
		instance.position = global_position
		instance.target = att_object
		instance.attack_dmg = parent_n.attack_dmg_range
		instance.a_penetration = parent_n.a_penetration
		instance.high_ground = self.current_height
		main_r.get_node("projectiles").add_child(instance)

	shots_fired += 1

	if shots_fired < burst_count:
		$BurstTimer.start()
	else:
		burst_target_id = null
		$ReloadTimer.start()

func _on_burst_timer_timeout() -> void:
	_fire_one_shot()

func _on_reload_timer_timeout() -> void:
	can_attack = true


# --- Deploy siege (existing functionality) ---

@rpc("authority", "call_local", "reliable")
func deploy_siege(tile_coord):
	var instance = siege_deployed.instantiate()
	instance.position = parent_n.first_tilemap_layer.map_to_local(tile_coord)
	main_r.get_node("siege_walls").get_node("placed_loc").add_child(instance)
	parent_n.update_death.rpc()


# --- Utility ---

func in_range(target_obj):
	if gr(target_obj) == null:
		return false
	var distance = int(global_position.distance_to(gr(target_obj).global_position))
	var in_range_ = parent_n.aggression_rage_px - distance
	return in_range_ > 0

func gr(weak_refer):
	if weak_refer == null:
		return null
	if weak_refer.get_ref() == null:
		return null
	else:
		return weak_refer.get_ref()
