extends Node2D

var closed_door = preload("res://sprites/units/castle/small_door/small_door_closed.png")
var open_door = preload("res://sprites/units/castle/small_door/small_door_opened.png")

@onready var parent_n = get_parent()

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	set_state(0)
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass



func set_state(open_: int):
	if open_ == 1:
		parent_n.get_node("base_sprite").set_texture(open_door)
	else:
		parent_n.get_node("base_sprite").set_texture(closed_door)
