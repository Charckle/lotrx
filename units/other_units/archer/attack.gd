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
	var tile_map = parent_n.title_map
	var unit_position = parent_n.unit_position

	if unit_position != local_old_unit_position:
		var height = 0
		
		for layer in range(tile_map.get_layers_count()):
			var tile_data_ = tile_map.get_cell_tile_data(layer, unit_position)
			
			if tile_data_ != null:
				var new_height = tile_data_.get_custom_data("HIGH_G")
				
				if new_height and (new_height > height):
					height = new_height
					current_height = new_height
		
		var multiplier = 3
		parent_n.attack_rage_px = parent_n.attack_rage_px_base + ((height * multiplier) * parent_n.root_map.m_cell_size)
		local_old_unit_position = unit_position

	
	if can_attack == true and parent_n.is_moving == false:
		if gr(parent_n.get_right_target()) != null:
			if not parent_n.is_pinned:
				attack_range(parent_n.get_right_target())
			else:
				attack_mele(parent_n.get_right_target())


func _on_timer_timeout() -> void:
	can_attack = true


func attack_range(att_object):
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

func attack_mele(att_object):
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
