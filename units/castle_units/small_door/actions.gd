extends Node2D

var closed_door = preload("res://sprites/units/castle/small_door/small_door_closed.png")
var open_door = preload("res://sprites/units/castle/small_door/small_door_opened.png")

@onready var parent_n = get_parent()

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	#set_state(0)
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func set_state(open_: int):
	if open_ == 1:
		parent_n.get_node("base_sprite").set_texture(open_door)
		parent_n.astar_grid.set_point_solid(parent_n.unit_position, false)
	else:
		for unit in parent_n.root_map.get_all_units():
			if unit == parent_n:
				continue
			if unit.unit_position == parent_n.unit_position:
				print()
				return
		parent_n.get_node("base_sprite").set_texture(closed_door)
		parent_n.astar_grid.set_point_solid(parent_n.unit_position)
