extends RefCounted
class_name MultilevelAStar

# tile custom data "type":
#  0     => blocked
#  1(+)  => can move to same number
# -1(-)  => can move to same, one larger or one smaller as long as they're both negative
#        => can move to and from its absolute value and one larger than its absolute value

# private variables start with an _ as per the GDScript style guide
var _used_rect: Rect2i
var _astar: MultilevelAStarEx


func _init(map: TileMap):
	_used_rect = map.get_used_rect()
	
	# assert stuff here because the extension's assertions just crash without a message
	assert(_used_rect.get_area() >= 0)
	
	_astar = MultilevelAStarEx.new()
	_astar.init(_used_rect)
	
	for layer in map.get_layers_count():
		var cells := map.get_used_cells(layer)
		for cell in cells:
			var tile_data := map.get_cell_tile_data(layer, cell)
			if tile_data != null:
				var type = tile_data.get_custom_data("type")
				assert(type is int)
				_astar.set_terrain(cell, type)


func is_unit(point: Vector2i) -> bool:
	assert(_used_rect.has_point(point))
	return _astar.get_unit(point)


func set_unit(point: Vector2i, solid: bool = true) -> void:
	assert(_used_rect.has_point(point))
	_astar.set_unit(point, solid)


func get_terrain(point: Vector2i) -> MultilevelAStarEx.TerrainType:
	assert(_used_rect.has_point(point))
	return _astar.get_terrain(point)


func set_terrain(point: Vector2i, type: MultilevelAStarEx.TerrainType) -> void:
	assert(_used_rect.has_point(point))
	_astar.set_terrain(point, type)


func is_blocked(point: Vector2i) -> bool:
	assert(_used_rect.has_point(point))
	return (_astar.get_terrain(point) == MultilevelAStarEx.BLOCKED) or _astar.get_unit(point)


func find_path(from: Vector2i, to: Vector2i, return_closest: bool = false) -> Array[Vector2i]:
	assert(_used_rect.has_point(from))
	assert(_used_rect.has_point(to))
	
	var res = _astar.find_path(from, to, return_closest) # returns Variant: null or Array[Vector2i]
	
	if res != null:
		return res
	else:
		return []
