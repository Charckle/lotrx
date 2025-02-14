extends Node2D

var astar_grid := AStarGrid2D.new()
var grid_size
const m_cell_size := 32
const sector_size := 15.0 #how many cells in a sector. not used, since the processor will be enough..prolly
@onready var title_map_node = $TileMap
@onready var first_tilemap_layer = title_map_node.get_node("base_layer")

# needed for multiplayer sync, since you cannot send object references via the rpc func
var incremental_unit_ids = 0
var all_units_w_unique_id = {}

var walking_map_tiles_taken
var units_selected = []
var control_units_selected = [[],[],[],[],[],[],[],[],[],[]]
var global_map_sectors := [] # not in use

# multiplayer tick system
# Tick system variables
var tick_rate = 5  # Ticks per second, every 350 miliseconds wthich is super dooper cool for multiplayer
var tick_interval = 1.0 / tick_rate  # Time between ticks
var tick_timer = 0.0  # Timer to accumulate delta time
var current_tick = 0  # Current tick count

var commands_in_last_tick = [] # current clinet current tick commands
var commands_from_other_players_last_tick = [] # commands that the server is gathering from all players
var all_player_commands = [] # commands send back from the server, combined from all players
var commands_to_execute = [] # current player commands to execute
# multiplayer system stop


var cursor_default = load("res://sprites/gui/defaut_cursor.png")
var cursor_move = load("res://sprites/gui/move_to.png")
var going_marker = load("uid://cqhiif4h6eys0")

func _enter_tree():
	GlobalSettings.game_stats = {
		"game_unit_count_start" = null,
		"game_unit_count_current" = null
	}

# Called when the node enters the scene tree for the first time.
func _ready():
	setup_astar_grid()
	re_create_moat(true)

	#global_map_sectors_generate()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	queue_redraw()

# multiplayer tick system for running commands
func _physics_process(delta):
	# Tick system update
	tick_timer += delta
	while tick_timer >= tick_interval:
		tick_timer -= tick_interval
		
		execute_the_commands()
		
		current_tick += 1
		sync_tick_clients.rpc(current_tick)
		
		send_commands_to_server.rpc_id(1, commands_in_last_tick)

		# single players and server will have this TRUE
		if multiplayer.is_server() and len(commands_from_other_players_last_tick) != 0:
			#send_combined_commandsto_clients.rpc(commands_from_other_players_last_tick)
			send_combined_commandsto_clients(commands_from_other_players_last_tick)
		
		commands_in_last_tick = []
		commands_from_other_players_last_tick = []


func execute_the_commands():
	#commands_to_execute = remove_duplicate_dicts(commands_to_execute) # I wager I save a couple of frames per seconds with this one
	commands_to_execute.append_array(all_player_commands)
	all_player_commands = []
	
	var not_executed_commands = []
	
	for command in commands_to_execute:
		if (command["curr_tick"] + 2) <= current_tick:
			#command["func"].callv(command["args"])  # Call the function with its arguments
			var unit = all_units_w_unique_id[command["map_unique_id"]]
			unit.callv(command["func"], command["args"]) 
		else:
			not_executed_commands.append(command)
	commands_to_execute.clear()
	commands_to_execute = not_executed_commands


@rpc("authority", "call_remote", "reliable")
func sync_tick_clients(server_tick:int):
	#current_tick = server_tick
	#tick_timer = 0.0
	
	
	var tick_difference = server_tick - current_tick
	
	if tick_difference > 0:
		# Client is behind, speed up slightly
		tick_interval *= 0.9  # Reduce interval (process faster)
	elif tick_difference < 0:
		# Client is ahead, slow down slightly
		tick_interval *= 1.1  # Increase interval (process slower)

# users send their commands to the server
@rpc("any_peer", "call_local", "reliable")
func send_commands_to_server(player_commands):
	player_commands = remove_duplicate_dicts(player_commands)
	commands_from_other_players_last_tick.append_array(player_commands)

@rpc("authority", "call_local", "reliable")
func send_combined_commandsto_clients(combined_player_commands):
	all_player_commands = combined_player_commands

func _draw():
	#draw_rect(Rect2(5,5,5,5), Color.GREEN_YELLOW)
	pass


func _input(event):
	if event is InputEventMouseMotion:
		pass
	
	if Input.is_action_just_pressed("right_click"):
		self.create_going_marker()
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
	
	if event is InputEventKey and event.pressed and event.keycode == Key.KEY_D:
		set_stance_defence_selected()


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

func set_stance_defence_selected():
	var stance = 0
	if units_selected.size() > 0:
		if units_selected[0].stance == stance:
			stance = 1

	for unit in units_selected:
		#unit.set_stance(stance) 
		update__process_func_clients.rpc(unit.map_unique_id,stance)

@rpc("any_peer", "call_local", "reliable")
func update__process_func_clients(map_unique_id, stance):
	all_units_w_unique_id[map_unique_id].set_stance(stance)


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
	#print("setting up grid and units")
	var first_tilemap_layer = title_map_node.get_child(0) # the first layer should be the biggest, over ALL
	var map_size = first_tilemap_layer.get_used_rect() 
	astar_grid.region = map_size
	astar_grid.cell_size = Vector2(m_cell_size,m_cell_size)
	astar_grid.update()
	grid_size = astar_grid.get_size()
	#print(map_size)
	#print(grid_size)
	
	#walking_map_tiles_taken = create_empty_array(astar_grid.get_size())
	for layer_num in range(title_map_node.get_child_count()):
		var layer = title_map_node.get_child(layer_num)
		for x in map_size.size.x:
			
			for y in map_size.size.y:
				# get the tile position on the base layer, which we use to create the astargrid
				var tile_position = Vector2i(x + map_size.position.x, y + map_size.position.y)
				# get global position of the tile 
				var tile_global_position = first_tilemap_layer.map_to_local(tile_position)
				# get the tile position on the layer we are working on
				var layer_tile_position = layer.local_to_map(tile_global_position)
				# get the tile data in the layer
				var tile_data = layer.get_cell_tile_data(layer_tile_position)

				if layer_num == 0:
					if tile_data == null or tile_data.get_custom_data("not_walkable"):
						astar_grid.set_point_solid(tile_position, true)
				if layer_num == 1:
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


func create_going_marker():
	var instance = going_marker.instantiate()

	instance.position =  get_global_mouse_position()
	
	self.get_node("othr").add_child(instance)


func get_wr_unit_on_mouse_position() -> WeakRef:
	var mouse_pos = get_global_mouse_position()
	var mouse_pos_2i = first_tilemap_layer.local_to_map(mouse_pos)
	
	for unit in $units.get_children():
		var unit_wr = weakref(unit)

		if unit.unit_position == mouse_pos_2i:
			return unit_wr
	
	return null

func get_wr_unit_on_position(global_pos) -> WeakRef:
	var mouse_pos_2i = first_tilemap_layer.local_to_map(global_pos)
	
	for unit in $units.get_children():
		var unit_wr = weakref(unit)

		if unit.unit_position == mouse_pos_2i:
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

func re_create_moat(first_make=false):
	var moat_tiles = []
	
	for moat_obj in $moat.get_children():
		if moat_obj.scheduled_to_be_deleted == false:
			if first_make:
				moat_obj.make_walkable(false)
			first_tilemap_layer.erase_cell(moat_obj.unit_position)
			moat_tiles.append(moat_obj.unit_position)
	
	first_tilemap_layer.set_cells_terrain_connect(moat_tiles, 0, 0)

func remove_all_gui():
	_remove_all_children($gui_windows)


func remove_duplicate_dicts(list_of_dicts):
	var unique_dicts = []  # Stores unique dictionaries
	
	for dict in list_of_dicts:
		var is_duplicate = false
		
		# Compare with already added unique dictionaries
		for unique_dict in unique_dicts:
			if are_dicts_equal(dict, unique_dict):
				is_duplicate = true
				break  # No need to check further
		
		# Add to the list only if it's not a duplicate
		if not is_duplicate:
			unique_dicts.append(dict)

	return unique_dicts

# Helper function to compare two dictionaries (without converting to JSON)
func are_dicts_equal(dict1, dict2):
	# Compare keys and values except for function references
	if dict1.keys() != dict2.keys():
		return false
	
	for key in dict1.keys():
		if key == "func":
			# Compare function references directly
			if dict1[key] != dict2[key]:  
				return false
		else:
			# Compare other values normally
			if dict1[key] != dict2[key]:  
				return false
	
	return true


func _remove_all_children(node_to_delete_children_of):
	# Iterate over a copy of the children list
	for child in node_to_delete_children_of.get_children():
		child.queue_free()

func reset_global_game_settings():
	GlobalSettings.map_options = null
	multiplayer.multiplayer_peer = null
	GlobalSettings.multiplayer_data["players"].clear()

func exit_to_main_menu():
	reset_global_game_settings()
	get_tree().change_scene_to_file("uid://ceun5xdoedpjf")
	self.queue_free()
