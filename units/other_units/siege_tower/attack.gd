extends Node2D

const cooldown = 4
var can_attack = true
@onready var main_r = get_tree().root.get_node("game")
@onready var parent_n = get_parent()
@onready var ram_att = load("res://weapons/mele/ram_att/ram_att.tscn")

@onready var siege_deployed = load("res://units/other_units/siege_tower/siege_deployed/siege_deployed.tscn")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if not multiplayer.is_server():
		return


	
@rpc("authority", "call_local", "reliable")
func attack_mele(right_target_id):
	pass

@rpc("authority", "call_local", "reliable")
func deploy_siege(tile_coord):
	# create objects
	var instance = siege_deployed.instantiate()
	instance.position =  parent_n.first_tilemap_layer.map_to_local(tile_coord)
	main_r.get_node("siege_walls").get_node("placed_loc").add_child(instance)
	
	# delet the object
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
