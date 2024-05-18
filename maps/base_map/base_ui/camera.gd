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

# Called when the node enters the scene tree for the first time.
func _ready():
	draw_area(false)
	connect("area_selected", Callable(map_root, "_on_area_selected"))


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	var inpx = (int(Input.is_action_pressed("ui_right")) - int(Input.is_action_pressed("ui_left")))	
	var inpy = (int(Input.is_action_pressed("ui_down")) - int(Input.is_action_pressed("ui_up")))
	#position.x += inpx * speed * delta
	position.x = lerp(position.x, position.x + inpx * speed, speed * delta)	
	position.y = lerp(position.y, position.y + inpy * speed, speed * delta)	
	
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
