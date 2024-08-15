extends Node2D

var closed_door = preload("res://sprites/units/castle/small_door/small_door_closed.png")
var open_door = preload("res://sprites/units/castle/small_door/small_door_opened.png")

var door_opened = 0

@onready var parent_n = get_parent()
@onready var base_sprite = parent_n.get_node("spriteNode/base_sprite")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	#set_state(door_opened)
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func set_state(open_: int):
	if open_ == 1:
		base_sprite.set_texture(open_door)
		parent_n.astar_grid.set_point_solid(parent_n.unit_position, false)
		door_opened = open_
	else:
		base_sprite.set_texture(closed_door)
		parent_n.astar_grid.set_point_solid(parent_n.unit_position)
		door_opened = open_
