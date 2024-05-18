extends Node2D

@onready var parent_n = get_parent()


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func siege_action(damage: int):
	for unit in parent_n.root_map.get_node("units").get_children():
		var unit_wr = weakref(unit)
		var unit_wr_obj = unit_wr.get_ref()
		if unit == parent_n:
			continue
		if unit_wr_obj.siege_weapon == true and unit_wr_obj.siege_id == parent_n.siege_id:
			unit_wr_obj.lower_health(damage)



func gr(weak_refer):
	if weak_refer == null:
		return null
	if weak_refer.get_ref() == null:
		return null
	else:
		return weak_refer.get_ref()
