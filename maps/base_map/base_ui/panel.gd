extends Panel
@onready var root_map = get_tree().root.get_node("game")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

# close outer doors
func _on_check_button_toggled(toggled_on: bool) -> void:
	for unit in root_map.get_node("units").get_children():
		var unit_wr = weakref(unit)
		var unit_wr_obj = unit_wr.get_ref()
		if unit_wr_obj.siege_id == 5:
			if toggled_on:
				unit_wr_obj.get_node("actions").set_state(1)
				#root_map.astar_grid.set_point_solid(unit_wr_obj.unit_position, false)

			else:
				unit_wr_obj.get_node("actions").set_state(0)
				#root_map.astar_grid.set_point_solid(unit_wr_obj.unit_position)
	pass # Replace with function body.

# close inner doors
func _on_check_button_toggled_2(toggled_on: bool) -> void:
	for unit in root_map.get_node("units").get_children():
		var unit_wr = weakref(unit)
		var unit_wr_obj = unit_wr.get_ref()
		if unit_wr_obj.siege_id == 6:
			if toggled_on:
				unit_wr_obj.get_node("actions").set_state(1)
				root_map.astar_grid.set_point_solid(unit_wr_obj.unit_position, false)

			else:
				unit_wr_obj.get_node("actions").set_state(0)
				root_map.astar_grid.set_point_solid(unit_wr_obj.unit_position)
	pass # Replace with function body.

func gr(weak_refer):
	if weak_refer == null:
		return null
	if weak_refer.get_ref() == null:
		return null
	else:
		return weak_refer.get_ref()
