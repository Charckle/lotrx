extends Node2D

var tile_id
var atlas_coords
var alternative_tile

var scheduled_to_be_deleted = false

@onready var root_map = get_tree().root.get_node("game") # 0 je global properties autoloader :/
@onready var astar_grid = root_map.astar_grid

@onready var title_map_node = root_map.get_node("TileMap")
@onready var first_tilemap_layer = title_map_node.get_node("base_layer")
@onready var unit_position = first_tilemap_layer.local_to_map(global_position)

# you place this on the map, it generates auto tiles

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	get_underliying_tile()
	#astar_grid.set_point_solid(unit_position)
	self.visible = false


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	
	pass



func create_moat():
	pass #first_tilemap_layer.set_cells_terrain_connect(get_neighbors(unit_position), 0, 0)

func fill_moat():
	pass

func make_walkable(yes=true):
	if yes == true:
		yes = false
	else:
		yes = true
	astar_grid.set_point_solid(unit_position, yes)


func get_neighbors(tile_coords: Vector2i) -> Array:
	var neighbors = []
	
	# Offsets for the 8 neighboring tiles + the original tile
	var offsets = [
		Vector2i(0, 0),	# Original tile
		Vector2i(1, 0),	# Right
		Vector2i(-1, 0),	# Left
		Vector2i(0, 1),	# Down
		Vector2i(0, -1),	# Up
		Vector2i(1, 1),	# Bottom-right
		Vector2i(-1, 1),	# Bottom-left
		Vector2i(1, -1),	# Top-right
		Vector2i(-1, -1)	# Top-left
	]
	
	# Add each neighboring coordinate
	for offset in offsets:
		neighbors.append(tile_coords + offset)
	
	return neighbors

func get_underliying_tile():
	tile_id = first_tilemap_layer.get_cell_source_id(unit_position)
	atlas_coords = first_tilemap_layer.get_cell_atlas_coords(unit_position)
	alternative_tile = first_tilemap_layer.get_cell_alternative_tile(unit_position)

func return_to_base_tile():
	first_tilemap_layer.set_cell(unit_position, tile_id, atlas_coords, alternative_tile)
	first_tilemap_layer.set_cells_terrain_connect([unit_position], -1, -1)
	scheduled_to_be_deleted = true
	queue_free()
	root_map.re_create_moat()
