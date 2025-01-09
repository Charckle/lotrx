extends Node2D

var astar_grid := AStarGrid2D.new()
var grid_size
const m_cell_size := 32
const sector_size := 15.0 #how many cells in a sector. not used, since the processor will be enough..prolly
@onready var title_map = $TileMap


var walking_map_tiles_taken
var units_selected = []
var control_units_selected = [[],[],[],[],[],[],[],[],[],[]]
var global_map_sectors := [] # not in use


var cursor_default = load("res://sprites/gui/defaut_cursor.png")
var cursor_move = load("res://sprites/gui/move_to.png")


func _enter_tree():
	GlobalSettings.game_stats = {
		"game_unit_count_start" = null,
		"game_unit_count_current" = null
	}

# Called when the node enters the scene tree for the first time.
func _ready():
	setup_astar_grid()

	#global_map_sectors_generate()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	queue_redraw()


func _draw():
	#draw_rect(Rect2(5,5,5,5), Color.GREEN_YELLOW)
	pass


func _input(event):
	if event is InputEventMouseMotion:
		pass
	
	if Input.is_action_just_pressed("right_click"):
		# move/attack with units, is they are selected
		if units_selected.size() != 0:
			# instruct the selected units
			for unit in units_selected:
				#unit.set_move()
				unit.set_act()

	
	# Check if the right mouse button is pressed
	
	if Input.is_action_just_pressed("left_click"):
		# Call a function to reset variables
		deselect_all_units()

		Input.set_custom_mouse_cursor(cursor_default)
	# control groups
	if event is InputEventKey:
		if units_selected.size() > 0:
			set_assign_control_group(event)
		get_assign_control_group(event)


func get_assign_control_group(event):
	if event.keycode >= KEY_0 and event.keycode <= KEY_9 and not Input.is_action_pressed("control_button"):
		if event.pressed:
			deselect_all_units()
			Input.set_custom_mouse_cursor(cursor_default, Input.CURSOR_ARROW)
			var pressed_number = event.keycode - KEY_1
			#print(control_units_selected[pressed_number].size() > 0)
			if control_units_selected[pressed_number].size() > 0:
				
				for unit in control_units_selected[pressed_number]:
					unit.set_selected(true)
					units_selected.append(unit)
					
					if units_selected.size() != 0:
						Input.set_custom_mouse_cursor(cursor_move, Input.CURSOR_ARROW, Vector2(20,20))
			

func set_assign_control_group(event):
	if Input.is_action_pressed("control_button"):
			# Check if the pressed key is a number from 1 to 9
			if event.keycode >= KEY_0 and event.keycode <= KEY_9:
				var pressed_number = event.keycode - KEY_1 # starts form 0
				control_units_selected[pressed_number] = units_selected.duplicate(true)
				for unit in units_selected:
					unit.control_group = pressed_number + 1

func deselect_units(node):
	# Iterate through each child node
	for child in node.get_children():
		# Check if the child node has any variables you want to reset
		if "position" in child:
			# Call a function to reset variables (assuming the function is called reset_variables)
			child.set_selected(false)

func _on_area_selected(object):
	var start = object.start
	var end = object.end
	var area = []
	area.append(Vector2(min(start.x, end.x), min(start.y, end.y)))
	area.append(Vector2(max(start.x, end.x), max(start.y, end.y)))

	var units_area = _get_units_in_area(area)
	for unit in units_area:
		unit.set_selected(true)
		units_selected.append(unit)
	
	if units_selected.size() != 0:
		Input.set_custom_mouse_cursor(cursor_move, Input.CURSOR_ARROW, Vector2(20,20))


	
func _get_units_in_area(area):
	var u = []
	for unit in $units.get_children():
		if unit.position.x > area[0].x and unit.position.x < area[1].x:
			if unit.position.y > area[0].y and unit.position.y < area[1].y:
				u.append(unit)
	return u


func deselect_all_units():
	deselect_units($units)
	units_selected.clear()

func setup_astar_grid():
	print("setting up grid and units")
	astar_grid.region = title_map.get_used_rect()
	astar_grid.cell_size = Vector2(m_cell_size,m_cell_size)
	astar_grid.update()
	grid_size = astar_grid.get_size()
	print(grid_size)
	#walking_map_tiles_taken = create_empty_array(astar_grid.get_size())
	for layer in range(title_map.get_layers_count()):
		for x in title_map.get_used_rect().size.x:
			for y in title_map.get_used_rect().size.y:
				var tile_position = Vector2i(x + title_map.get_used_rect().position.x,y + title_map.get_used_rect().position.y)
				
				var tile_data = title_map.get_cell_tile_data(layer,tile_position)
				if layer == 0:
					if tile_data == null or tile_data.get_custom_data("not_walkable"):
						astar_grid.set_point_solid(tile_position, true)
				if layer == 1:
					if  tile_data == null:
						continue
					if tile_data.get_custom_data("not_walkable"):
						astar_grid.set_point_solid(tile_position, true)
					else:
						astar_grid.set_point_solid(tile_position, false)
	
	update_astar_grid_units()

func create_empty_array(vector_var:Vector2):
	var rows = vector_var.x
	var columns = vector_var.y
	var vector_array = []

	for row_idx in range(rows):
		var row = []
		for col_idx in range(columns):
			row.append(0)  # Initialize each element with the specific vector

		# Append the row to the 2D array
		vector_array.append(row)
	return vector_array
	
	
func update_astar_grid_units():
	for unit in $units.get_children():
		unit.astar_grid = astar_grid
		#print(type_string(typeof(unit.unit_position)))
		#print(unit.unit_position)
		astar_grid.set_point_solid(unit.unit_position)



func get_solid_points():
	#print("checking solids")
	#print(grid_size)
	# Iterate through each cell in the grid
	var solid_points = 0
	for x in range(grid_size.x):
		for y in range(grid_size.y):
			# Get the position of the cell
			#var position = Vector2i(x, y)
			#var cell_size = Vector2i(42, 42)


			# Check if the cell is walkable
			if astar_grid.is_point_solid(position):
				solid_points += 1
				#print("Solid point at:", position)
				#draw_rect(Rect2(position), Color.GREEN_YELLOW)
			else:
				pass
	#print("solid points: " + str(solid_points))

# USE IF YOU NEED SECTORS TO CALCULATED COLLISIONS, prolly the processors will be enough, so ATM I dont need it
func global_map_sectors_generate():
	var max_x = float(grid_size.x)
	var max_y = float(grid_size.y)
	
	var x_sectors = ceil(max_x / sector_size)
	var y_sectors = ceil(max_y / sector_size)

	global_map_sectors = []#grid_size
	for xx in x_sectors:
		global_map_sectors.append([])
		for yy in y_sectors:
			var edge_vector = [(xx + 1) * sector_size, (yy + 1) * sector_size]
			global_map_sectors[xx].append(edge_vector)
	print("Map sectors: {}x:{}y".format([x_sectors, y_sectors], "{}"))
	print("Sectors:")
	print(global_map_sectors)
	print("-------")



func get_wr_unit_on_mouse_position() -> WeakRef:
	var mouse_pos = get_global_mouse_position()
	var mouse_pos_2i = title_map.local_to_map(mouse_pos)
	
	for unit in $units.get_children():
		var unit_wr = weakref(unit)
		var unit_wr_obj = unit_wr.get_ref()

		if unit_wr_obj.unit_position == mouse_pos_2i:
			return unit_wr
	
	return null


func get_all_units():
	var units_ = []
	for unit in $units.get_children():
		units_.append(unit)
	return units_

func get_all_ai_markers():
	var markers = []
	for marker in $ai_stuff/markers.get_children():
		markers.append(marker)
	return markers

func remove_all_gui():
	_remove_all_children($gui_windows)

func _remove_all_children(node_to_delete_children_of):
	# Iterate over a copy of the children list
	for child in node_to_delete_children_of.get_children():
		child.queue_free()

func reset_global_game_settings():
	GlobalSettings.map_options = null

func exit_to_main_menu():
	reset_global_game_settings()
	get_tree().change_scene_to_file("uid://ceun5xdoedpjf")
