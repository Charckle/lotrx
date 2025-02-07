extends Node2D

var timer_ = 1

var attack_dmg = 10
var a_penetration = 20

@onready var steam = load("res://environmental/steam/steam.tscn")
@onready var root_map = get_tree().root.get_node("game") # 0 je global properties autoloader :/

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$Sprite2D.self_modulate.a = 0.7


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if timer_ < 0:
		timer_ = 10
		$Sprite2D.self_modulate.a -= 0.01
	timer_ -= 1
	


func _on_timer_timeout() -> void:
	queue_free()


func _on_steam_timer_timeout() -> void:
	var instance = steam.instantiate()
	instance.position = global_position
	root_map.get_node("aoe_objects").add_child(instance)
	make_damage()
	
func make_damage():
	# check if anything on the tile
	var obj_wr = root_map.get_wr_unit_on_position(global_position)
	var obj = gr(obj_wr)
	if obj_wr != null or obj != null:
		gr(obj_wr).get_damaged(attack_dmg, a_penetration, "oil")

func gr(weak_refer):
	if weak_refer == null:
		return null
	if weak_refer.get_ref() == null:
		return null
	else:
		return weak_refer.get_ref()
