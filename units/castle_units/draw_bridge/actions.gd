extends Node2D

var door_opened = 0

@onready var parent_n = get_parent()
@onready var base_sprite = parent_n.get_node("spriteNode/base_sprite")
@onready var open_sprite = parent_n.get_node("sprites_open")
@onready var open_door = parent_n.get_node("open_door")
@onready var close_door = parent_n.get_node("close_door")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

@rpc("any_peer", "call_local", "reliable")
func set_state(open_: int):
	if open_ == 1:
		close_door.stop()
		open_door.start()
	else:
		open_door.stop()
		close_door.start()


func _on_open_door_timeout() -> void:
	base_sprite.visible = false
	open_sprite.visible = true
	parent_n.astar_grid.set_point_solid(parent_n.unit_position, false)
	door_opened = 1


func _on_close_door_timeout() -> void:
	base_sprite.visible = true
	open_sprite.visible = false
	parent_n.astar_grid.set_point_solid(parent_n.unit_position)
	door_opened = 0
