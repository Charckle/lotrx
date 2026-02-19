extends Node2D

const cooldown = 4
var can_attack = true
@onready var main_r = get_tree().root.get_node("game")
@onready var parent_n = get_parent()
@onready var ram_att = load("res://weapons/mele/ram_att/ram_att.tscn")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$Timer.wait_time = cooldown


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if not multiplayer.is_server():
		return
	
	if can_attack == true and parent_n.is_moving == false:
		var right_target = parent_n.get_right_target()
		
		if gr(right_target) != null and in_range(right_target):
			var right_target_id = gr(right_target).map_unique_id
			attack_mele.rpc(right_target_id)
	pass


	
@rpc("authority", "call_local", "reliable")
func attack_mele(right_target_id):
	if not multiplayer.is_server():
		return
	var att_object = weakref(main_r.all_units_w_unique_id[right_target_id])
	
	can_attack = false
	$Timer.start()
	var instance = ram_att.instantiate()
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
	var adjecent_blocks = parent_n.get_adjecent_blocks()
	var target_pos_2 = Vector2i(gr(target_obj).unit_position.x, gr(target_obj).unit_position.y)
	var yes_in_range = false
	
	
	for block in adjecent_blocks:
		if target_pos_2 == block:
			yes_in_range = true
	return yes_in_range

func gr(weak_refer):
	if weak_refer == null:
		return null
	if weak_refer.get_ref() == null:
		return null
	else:
		return weak_refer.get_ref()


func _on_timer_timeout() -> void:
	can_attack = true
