extends Panel

@onready var root_map = get_tree().root.get_child(1) # 0 je global properties autoloader :/

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


func _input(event):
	if Input.is_action_just_pressed("escape_button"):
		if self.visible == false:
			self.visible = true
		else:
			self.visible = false


func _on_resume_button_pressed():
	self.visible = false


func _on_quit_game_button_pressed():
	get_tree().quit()


func _on_to_main_menu_button_pressed():
	root_map.exit_to_main_menu()
