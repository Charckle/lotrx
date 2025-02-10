extends Node2D

var target
var target_coordinate
var speed = 1200
var speed_decrese = 25
var min_speed = 300
var stuck = false
var attack_dmg
var a_penetration

var timer_ = 1

var high_ground:int

var autodestroy = 0
var good_to_be_deleted = false
var previous_cell

var arrow_pos_for_calc


@onready var root_map = get_tree().root.get_node("game") # 0 je global properties autoloader :/
@onready var title_map_node = root_map.get_node("TileMap")
@onready var first_tilemap_layer = title_map_node.get_node("base_layer")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	target_coordinate = gr(target).global_position
	# Calculate the angle between the node's position and the target coordinate
	var angle = global_position.angle_to_point(target_coordinate)
	rotation = angle
	$Sprite2D.self_modulate.a = 1


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	arrow_pos_for_calc = first_tilemap_layer.local_to_map(global_position)
	
	if timer_ < 0:
		timer_ = 10
	timer_ -= 1
	
	check_hit_wall()
	check_hit_target()


	if stuck == false:
		if $Sprite2D.self_modulate.a < 1:
			$Sprite2D.self_modulate.a += 0.1
	if speed >= min_speed:
		speed -= speed_decrese
	global_position = global_position.move_toward(target_coordinate, speed * delta)
	
	# this part I think the shaders break. welp....
	#if stuck == true:
		#print($Sprite2D.self_modulate.a > 0)
		#if $Sprite2D.self_modulate.a > 0:
		#
			#$Sprite2D.self_modulate.a -= 0.01
			##print($Sprite2D.self_modulate.a)
		#else:
			#queue_free()


func check_hit_wall():
	if timer_ % 2 == 0:

		var local_high_ground = 0
		
		var is_wall = false
		var all_layers_null = true
		var is_cranullation = false
		
		# check for cranulations effects
		if good_to_be_deleted == true:
			if previous_cell != arrow_pos_for_calc:
				autodestroy += 1
				if autodestroy > 1:
					queue_free()
		
		for layer_num in range(title_map_node.get_child_count()):
			var layer = title_map_node.get_child(layer_num)
			
			var tile_data_ = layer.get_cell_tile_data(arrow_pos_for_calc)
			
			if tile_data_ != null:
				all_layers_null = false

				if tile_data_.get_custom_data("wall"):
					is_wall = true
					
				if tile_data_.get_custom_data("cranullations"):
					local_high_ground = tile_data_.get_custom_data("HIGH_G")
					is_cranullation = true

		if is_wall or all_layers_null:
			queue_free()
		
		# check if if hit cranulations
		if is_cranullation and (local_high_ground != high_ground):
			good_to_be_deleted = true
			previous_cell = arrow_pos_for_calc


func check_hit_target():
	if first_tilemap_layer.local_to_map(target_coordinate) == arrow_pos_for_calc and stuck == false:
		stuck = true
		if gr(target) != null and arrow_pos_for_calc == gr(target).unit_position:
			queue_free()
			gr(target).get_damaged(attack_dmg, a_penetration)


func gr(weak_refer):
	if weak_refer == null:
		return null
	if weak_refer.get_ref() == null:
		return null
	else:
		return weak_refer.get_ref()
