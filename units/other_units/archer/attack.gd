extends Node2D

const cooldown = 2
var can_attack = true
var current_height = 0

@onready var local_old_unit_position = null

@onready var main_r = get_tree().root.get_node("game")
@onready var parent_n = get_parent()
@onready var arrow = load("res://weapons/range/arrow/arrow.tscn")
@onready var sword = load("res://weapons/mele/sword/sword.tscn")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$Timer.wait_time = cooldown


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	# add range if on a high ground
	var title_map_node = parent_n.title_map_node
	var first_tilemap_layer = parent_n.first_tilemap_layer
	var unit_position = parent_n.unit_position

	if unit_position != local_old_unit_position:
		var height = 0
		
		for layer_num in range(title_map_node.get_child_count()):
			var layer = title_map_node.get_child(layer_num)
			
			# get global position of the tile 
			var tile_global_position = first_tilemap_layer.map_to_local(unit_position)
			# get the tile position on the layer we are working on
			var layer_tile_position = layer.local_to_map(tile_global_position)
			# get the tile data in the layer
			
			var tile_data_ = layer.get_cell_tile_data(layer_tile_position)
			#parent_n.print_(layer_tile_position)
			#parent_n.print_(layer_num)
			if tile_data_ != null:
				var new_height = tile_data_.get_custom_data("HIGH_G")
				parent_n.print_(new_height)
				if new_height and (new_height > height):
					height = new_height
					current_height = new_height
		
		var multiplier = 3
		parent_n.attack_rage_px = parent_n.attack_rage_px_base + ((height * multiplier) * parent_n.root_map.m_cell_size)
		local_old_unit_position = unit_position
	
	# multiplayer cut-off
	if not multiplayer.is_server():
		return
	
	if can_attack == true and parent_n.is_moving == false:
		var right_target = gr(parent_n.get_right_target())
		if right_target != null:
			var right_target_id = right_target.map_unique_id
			
			if not parent_n.is_pinned:
				#attack_range(parent_n.get_right_target())
				attack_range.rpc(right_target_id)
			else:
				#attack_mele(parent_n.get_right_target())
				attack_mele.rpc(right_target_id)


func _on_timer_timeout() -> void:
	can_attack = true

@rpc("authority", "call_local", "reliable")
func attack_range(right_target_id):
	var att_object = weakref(main_r.all_units_w_unique_id[right_target_id])
	
	if in_range(att_object):
		#print("attacked!")
		can_attack = false
		$Timer.start()
		var instance = arrow.instantiate()
		instance.position = global_position
		instance.target = att_object
		instance.attack_dmg = parent_n.attack_dmg_range
		instance.a_penetration = parent_n.a_penetration
		instance.high_ground = self.current_height
		#instance.spawnPos = global_position
		#instance.spawnRot = rotation
		#
		main_r.get_node("projectiles").add_child(instance)

@rpc("authority", "call_local", "reliable")
func attack_mele(right_target_id):
	var att_object = weakref(main_r.all_units_w_unique_id[right_target_id])
	
	#print("attacked!")
	can_attack = false
	$Timer.start()
	var instance = sword.instantiate()
	instance.position = global_position
	instance.target = att_object
	instance.attack_dmg = parent_n.attack_dmg_mele
	instance.a_penetration = 0
	#instance.spawnPos = global_position
	#instance.spawnRot = rotation
	#
	main_r.get_node("projectiles").add_child(instance)

func in_range(target_obj):
	if gr(target_obj) == null:
		return
	var distance = int(global_position.distance_to(gr(target_obj).global_position))
	var in_range = parent_n.aggression_rage_px - distance
	if in_range <= 0:
		return false
	else:
		return true

func gr(weak_refer):
	if weak_refer == null:
		return null
	if weak_refer.get_ref() == null:
		return null
	else:
		return weak_refer.get_ref()
