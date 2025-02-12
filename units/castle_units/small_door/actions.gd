extends Node2D

@export var direction_iddle = 0 # cunterclockwise, 1-4



var closed_door = preload("res://sprites/units/castle/small_door/small_door_closed.png")
var open_door = preload("res://sprites/units/castle/small_door/small_door_opened.png")

var door_opened = 0

@onready var parent_n = get_parent()
@onready var base_sprite = parent_n.get_node("spriteNode/base_sprite")
@onready var door_sprite_node = parent_n.get_node("spriteNode")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	#set_state(door_opened)
	parent_n.unit_id = 500
	set_direction_sprite()
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

@rpc("any_peer", "call_local", "reliable")
func set_state(open_: int):
	if open_ == 1:
		base_sprite.set_texture(open_door)
		parent_n.astar_grid.set_point_solid(parent_n.unit_position, false)
		door_opened = open_
	else:
		base_sprite.set_texture(closed_door)
		parent_n.astar_grid.set_point_solid(parent_n.unit_position)
		door_opened = open_

func set_direction_sprite():
	var r
	var rotation_
	#print(direction_iddle)
	if direction_iddle == 1:
		r = deg_to_rad(90)
		rotation_ = r
	elif direction_iddle == 2:
		r = deg_to_rad(180)
		rotation_ = r
	elif direction_iddle == 3:
		r = deg_to_rad(270)
		rotation_ = r
	else:
		rotation_ = 0
	
	door_sprite_node.rotation = rotation_
