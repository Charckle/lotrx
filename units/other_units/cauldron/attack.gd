extends Node2D

var can_attack = true
@onready var main_r = get_tree().root.get_node("game")
@onready var parent_n = get_parent()
@onready var oil = load("res://weapons/range/oil/oil.tscn")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if not multiplayer.is_server():
		return
	
	if can_attack == true and parent_n.is_moving == false:
		var right_target = gr(parent_n.get_right_target())
		
		if right_target != null:
			var right_target_id = right_target.map_unique_id
			attack_range.rpc(right_target_id)



@rpc("authority", "call_local", "reliable")
func attack_range(right_target_id):
	var att_object = weakref(main_r.all_units_w_unique_id[right_target_id])
	
	if in_range(att_object):
		#print("attacked!")
		can_attack = false
		var instance = oil.instantiate()
		instance.position = global_position
		instance.target = att_object
		
		main_r.get_node("projectiles").add_child(instance)
		parent_n.update_death.rpc()

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
