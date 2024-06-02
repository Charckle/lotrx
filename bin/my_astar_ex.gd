extends RefCounted
class_name MyAStarEx


# private variables start with an _ as per the GDScript style guide
var _used_rect: Rect2i
var _astar: MyAStar


func _init(map: TileMap):
	_used_rect = map.get_used_rect()
	
	# assert stuff here because the extension's assertions just crash without a message
	assert(_used_rect.get_area() > 0)
	print("bbb")
	_astar = MyAStar.new()
	_astar.init(_used_rect)
	print("bbb")
	for layer in map.get_layers_count():
		print(layer)
		var cells := map.get_used_cells(layer)
		for cell in cells:
			var tile_data := map.get_cell_tile_data(layer, cell)
			
			if tile_data != null:
				var type = tile_data.get_custom_data("type")
				print("aaa")
				print(type)
				assert(type is int)
				print("bbb222")
				_astar.set_terrain(cell, type)
				print("bbb333")
	print("bbb1")




func is_unit(point: Vector2i) -> bool:
	return _astar.get_unit(point)


func set_unit(point: Vector2i, solid: bool = true) -> void:
	print("kura")
	assert(_used_rect.has_point(point))
	_astar.set_unit(point, solid)
	print("akurc")


func get_terrain(point: Vector2i) -> MyAStar.TerrainType:
	assert(_used_rect.has_point(point))
	return _astar.get_terrain(point)


func set_terrain(point: Vector2i, type: MyAStar.TerrainType) -> void:
	assert(_used_rect.has_point(point))
	_astar.set_terrain(point, type)


func find_path(from: Vector2i, to: Vector2i, return_closest: bool = false) -> Array[Vector2i]:
	assert(_used_rect.has_point(from))
	assert(_used_rect.has_point(to))
	
	var res = _astar.find_path(from, to, return_closest) # vrne Variant: null ali Array[Vector2i]
	
	if res != null:
		return res
	else:
		return []

func get_size() -> Vector2i:
	return _used_rect.size
