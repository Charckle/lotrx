extends Node2D

const cooldown = 2
var can_attack = true
@onready var main_r = get_tree().root.get_child(1)
@onready var parent_n = get_parent()
@onready var sword = load("res://weapons/mele/sword/sword.tscn")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$Timer.wait_time = cooldown


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if can_attack == true and parent_n.is_moving == false:
		if gr(parent_n.get_right_target()) != null and in_range(parent_n.get_right_target()):
			attack_mele(parent_n.get_right_target())



func _on_timer_timeout() -> void:
	can_attack = true


func attack_mele(att_object):
	#print("attacked!")
	can_attack = false
	$Timer.start()
	var instance = sword.instantiate()
	instance.position = global_position
	instance.target = att_object
	instance.attack_dmg = parent_n.attack_dmg_mele
	instance.a_penetration = parent_n.a_penetration
	#instance.spawnPos = global_position
	#instance.spawnRot = rotation
	#
	main_r.get_node("projectiles").add_child(instance)
	
func in_range(target_obj):
	if gr(target_obj) == null:
		return
	var adjecent_units = parent_n.get_adjecent_units()
	var target_pos_2 = Vector2i(gr(target_obj).unit_position.x, gr(target_obj).unit_position.y)
	var yes_in_range = false
	
	
	for unit in adjecent_units:
		if target_pos_2 == gr(unit).unit_position:
			yes_in_range = true
	return yes_in_range

func gr(weak_refer):
	if weak_refer == null:
		return null
	if weak_refer.get_ref() == null:
		return null
	else:
		return weak_refer.get_ref()
