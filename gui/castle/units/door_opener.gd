extends Panel

# weak reference to the door, set when the this is created
var door_unit_id = null
var door_wr: WeakRef
var door_wr_obj = null

# Called when the node enters the scene tree for the first time.
func _ready():
	#rotation = -get_parent().global_rotation
	pass

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if gr(door_wr) == null:
		queue_free()
	
	
func _input(event):
	door_wr_obj = door_wr.get_ref()
	if (event is InputEventMouseButton) and event.pressed:
		var evLocal = make_input_local(event)
		
		if !Rect2(Vector2(0,0), size).has_point(evLocal.position):
			var root_map = door_wr_obj.root_map
			root_map.remove_all_gui()


func _on_check_button_toggled(toggled_on):
	if toggled_on:
		#parent_n.get_node("actions").set_state(1)
		change_state_of_all(1)
		#root_map.astar_grid.set_point_solid(unit_wr_obj.unit_position, false)
	else:
		#parent_n.get_node("actions").set_state(0)
		change_state_of_all(0)
		#root_map.astar_grid.set_point_solid(unit_wr_obj.unit_position)

func change_state_of_all(state_: int):
	door_wr_obj = door_wr.get_ref()
	door_unit_id = door_wr_obj.siege_id

	for unit in door_wr_obj.root_map.get_all_units():
		if "siege_id" in unit and unit.siege_id == door_unit_id:
			unit.get_node("actions").set_state(state_)

func gr(weak_refer):
	if weak_refer == null:
		return null
	if weak_refer.get_ref() == null:
		return null
	else:
		return weak_refer.get_ref()
