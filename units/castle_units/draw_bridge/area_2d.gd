extends Area2D

@onready var parent_n = get_parent()

@onready var door_opener = load("res://gui/castle/units/door_opener.tscn")


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func create_gui():
	var instance = door_opener.instantiate()
	var panel_width = instance.size.x
	instance.position = global_position + Vector2(-(panel_width / 2),-50)
	instance.door_wr = weakref(parent_n)

	
	var actions = parent_n.get_node("actions")
	var checkButton = instance.get_node("CheckButton")
	
	if actions.door_opened == 1:
		checkButton.button_pressed = true
	else:
		checkButton.button_pressed = false

	var root_map = parent_n.root_map
	
	root_map.get_node("gui_windows").add_child(instance)	


func _on_input_event(viewport: Node, event: InputEvent, shape_idx: int) -> void:
	if parent_n.faction == GlobalSettings.my_faction:
		if event is InputEventMouseButton:		
			if event.is_pressed():
				if event.button_index == MOUSE_BUTTON_LEFT:
					create_gui()
