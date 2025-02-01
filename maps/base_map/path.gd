extends Node2D


@onready var parent_node = get_parent()
@onready var units = parent_node.get_node("units").get_children()

func _draw():
	draw_pathway()
	draw_solid_map()
	
	#print(player.current_point_path)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	queue_redraw()


func draw_pathway():
	var show_path = GlobalSettings.global_options["debug"]["show_path"]
	
	if show_path == true:
		for unit in units:
			if unit.current_point_path.is_empty():
				pass
			elif unit.selected == false:
				pass
			else:
				if unit.current_point_path.size() >= 2:
					draw_polyline(unit.current_point_path, Color.RED)
					
func draw_solid_map():
	var show_solid_tiles = GlobalSettings.global_options["debug"]["show_solid_tiles"]
	
	if show_solid_tiles == true:
		var astar_grid = parent_node.astar_grid
		var grid_size = astar_grid.get_size()
		#print("checking solids")
		#print(grid_size)
		# Iterate through each cell in the grid
		for x in range(grid_size.x):
			for y in range(grid_size.y):
				# Get the position of the cell
				var position_ = Vector2i(x, y)
				var cell_size = Vector2i(parent_node.m_cell_size, parent_node.m_cell_size)
				#var cell_size2 = Vector2i(parent_node.m_cell_size + 3, m_cell_size + 3)
				# Check if the cell is walkable
				#print(grid_size)
				if astar_grid.is_in_boundsv(position_):
					if astar_grid.is_point_solid(position_):
						draw_rect(Rect2(position_ * cell_size, cell_size), Color.GREEN_YELLOW)
