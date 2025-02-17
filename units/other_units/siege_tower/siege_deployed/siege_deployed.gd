extends Node2D

@onready var root_map = get_tree().root.get_node("game") # 0 je global properties autoloader :/
@onready var astar_grid = root_map.astar_grid

@onready var title_map_node = root_map.get_node("TileMap")
@onready var first_tilemap_layer = title_map_node.get_node("base_layer")
@onready var unit_position = first_tilemap_layer.local_to_map(global_position)

var pass_placed = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if not pass_placed:
		astar_grid.set_point_solid(unit_position, false)
		pass_placed = true
