extends Camera2D

@onready var parent_node = get_parent()
var speed := 20.0
var mousePos = Vector2()

var mousePosGlobal = Vector2()
var start = Vector2()
var startV = Vector2()
var end = Vector2()
var endV = Vector2()
var isDragging = false
signal area_selected
signal start_move_selection
@onready var map_root = get_tree().root.get_child(1)
#var speed := 20.0

var edge_threshold = 20  # Distance from the edge to start moving the camera
var camera_speed = 400    # Speed at which the camera moves

var drag_speer = 200    # Speed at which the camera moves
var previous_mouse_position

# Called when the node enters the scene tree for the first time.
func _ready():
	
	draw_area(false)
	connect("area_selected", Callable(map_root, "_on_area_selected"))
	set_player_start_loc()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	
	var inpx = (int(Input.is_action_pressed("ui_right")) - int(Input.is_action_pressed("ui_left")))	
	var inpy = (int(Input.is_action_pressed("ui_down")) - int(Input.is_action_pressed("ui_up")))
	#position.x += inpx * speed * delta
	position.x = lerp(position.x, position.x + inpx * speed, speed * delta)	
	position.y = lerp(position.y, position.y + inpy * speed, speed * delta)
	
	# Handle middle mouse button dragging
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE):
		previous_mouse_position = get_viewport().get_mouse_position()
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE):
		var mouse_position = get_viewport().get_mouse_position()  # Current mouse position
		var mouse_delta = mouse_position - previous_mouse_position  # Calculate delta
		position += mouse_delta * drag_speer * delta  # Adjust camera position
		previous_mouse_position = mouse_position  # Update for next frame
	
	move_camera_if_bumped(delta)
	
func _input(event):
	if event is InputEventMouse:
		mousePos = event.position
		mousePosGlobal = map_root.get_global_mouse_position()
	
	if Input.is_action_just_pressed("left_click"):
		start = mousePosGlobal
		startV = mousePos
		isDragging = true
	
	if isDragging:
		end = mousePosGlobal
		endV = mousePos
		draw_area()
	
	if Input.is_action_just_released("left_click"):
		if startV.distance_to(mousePos) > 50:
			end = mousePosGlobal
			endV = mousePos
			isDragging = false
			draw_area(false)
			emit_signal("area_selected", self)
		else:
			end = start
			isDragging = false
			draw_area(false)
		
func draw_area(s=true):
	var selectionbox = parent_node.get_node("selectionbox")
	selectionbox.size = Vector2(abs(startV.x - endV.x), abs(startV.y - endV.y))
	var pos = Vector2()
	pos.x = min(startV.x, endV.x)
	pos.y = min(startV.y, endV.y)
	selectionbox.position = pos
	selectionbox.size *= int(s)

func move_camera_if_bumped(delta):
	var viewport_size = get_viewport_rect().size
	var mouse_position = get_viewport().get_mouse_position()
	
	var camera_movement = Vector2()
	
	# Define the bounds of your tilemap
	var tilemap = self.map_root.get_node("TileMap")
	var map_size = tilemap.get_used_rect().size * Vector2i(self.map_root.m_cell_size, self.map_root.m_cell_size)
	var map_start = tilemap.get_used_rect().position * Vector2i(self.map_root.m_cell_size, self.map_root.m_cell_size)

	# Check if the mouse is near the left edge
	if mouse_position.x <= edge_threshold:
		camera_movement.x -= camera_speed * delta

	# Check if the mouse is near the right edge
	if mouse_position.x >= viewport_size.x - edge_threshold:
		camera_movement.x += camera_speed * delta

	# Check if the mouse is near the top edge
	if mouse_position.y <= edge_threshold:
		camera_movement.y -= camera_speed * delta

	# Check if the mouse is near the bottom edge
	if mouse_position.y >= viewport_size.y - edge_threshold:
		camera_movement.y += camera_speed * delta

	# Calculate the new position
	var new_position = position + camera_movement

	# Clamp the camera position to stay within the tilemap bounds
	new_position.x = clamp(new_position.x, map_start.x, map_start.x + map_size.x - viewport_size.x)
	new_position.y = clamp(new_position.y, map_start.y, map_start.y + map_size.y - viewport_size.y)
	
	# Update the camera position
	position = new_position


func set_player_start_loc():
	for child in map_root.get_node("othr").get_children():
	 # Check if the child is of type PlayerStartLoc
		if "is_player_start_point" in child:
			# Check if the faction attribute is 1
			if child.faction == GlobalSettings.my_faction:
				# Move the camera to the center of this node
				var viewport_size = get_viewport_rect().size
				var new_position = Vector2()
				new_position.x = child.position.x - (viewport_size.x / 2)
				new_position.y = child.position.y - (viewport_size.y / 2)
				position = new_position
				break  # Stop after finding the first match

