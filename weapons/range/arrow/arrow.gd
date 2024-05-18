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

@onready var root_map = get_tree().root.get_child(1) # 0 je global properties autoloader :/
@onready var title_map = root_map.get_node("TileMap")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	target_coordinate = gr(target).global_position  # Example target coordinate
	#print(target_coordinate)
	#print(global_position)
	# Calculate the angle between the node's position and the target coordinate
	var angle = global_position.angle_to_point(target_coordinate)
	rotation = angle
	$Sprite2D.self_modulate.a = 1
	#print(rotation)
	#global_position = target_coordinate


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
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
	pass

func check_hit_wall():
	if timer_ % 2 == 0:
		var arrow_pos_for_calc = title_map.local_to_map(global_position)
		var tile_data_ = title_map.get_cell_tile_data(0,arrow_pos_for_calc)
		if tile_data_ == null or tile_data_.get_custom_data("wall"):
			queue_free()


func check_hit_target():
	if target_coordinate == global_position:
		stuck = true
		if gr(target) != null and global_position == gr(target).global_position:
			queue_free()
			gr(target).get_damaged(attack_dmg, a_penetration)


func gr(weak_refer):
	if weak_refer == null:
		return null
	if weak_refer.get_ref() == null:
		return null
	else:
		return weak_refer.get_ref()
