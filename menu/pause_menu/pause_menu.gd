extends Panel


@onready var root_map = get_tree().root.get_node("game") # 0 je global properties autoloader :/

# Called when the node enters the scene tree for the first time.
func _ready():
	$CanvasLayer.visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


func _input(event):
	if Input.is_action_just_pressed("escape_button"):
		enable_pause_menu.rpc(true)


@rpc("any_peer", "call_local", "reliable")
func enable_pause_menu(yes_no):
	if yes_no:
		get_tree().paused = true
		$CanvasLayer.visible = true
	else:
		$CanvasLayer.visible = false
		get_tree().paused = false

func _on_resume_button_pressed():
	enable_pause_menu.rpc(false)


func _on_quit_game_button_pressed():
	get_tree().quit()


func _on_to_main_menu_button_pressed():
	get_tree().paused = false
	root_map.exit_to_main_menu()
