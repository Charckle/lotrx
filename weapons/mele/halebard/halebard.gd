extends Node2D

var target
var target_coordinate
var speed = 200
var speed_decrese = 10
var a_penetration
var backing_up = false
var back_to_pos
var attack_dmg

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	back_to_pos = self.global_position 

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
	check_hit_target()
	
	if backing_up == true:
		speed -= speed_decrese
		$Sprite2D.self_modulate.a -= 0.05
		if speed <= 0:
			queue_free()
	
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

func check_hit_target():
	if target_coordinate == global_position and backing_up == false:
		backing_up = true
		target_coordinate = back_to_pos
		if gr(target) != null and global_position == gr(target).global_position:
			gr(target).get_damaged(attack_dmg, a_penetration)


func gr(weak_refer):
	if weak_refer == null:
		return null
	if weak_refer.get_ref() == null:
		return null
	else:
		return weak_refer.get_ref()
