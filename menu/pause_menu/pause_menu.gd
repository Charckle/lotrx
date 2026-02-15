extends Panel


@onready var root_map = get_tree().root.get_node("game") # 0 je global properties autoloader :/
@onready var settings_panel = $CanvasLayer/vbnvbn/settings_panel
@onready var menu_panel = $CanvasLayer/vbnvbn/Panel

# Called when the node enters the scene tree for the first time.
func _ready():
	$CanvasLayer.visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Only show "Back to Lobby" if we're in a multiplayer game
	var lobby = get_tree().root.get_node_or_null("MultiplayerLobby")
	$CanvasLayer/vbnvbn/Panel/VBoxContainer/to_lobby_button.visible = (lobby != null)
	
	# When the settings panel closes, show the menu buttons again
	settings_panel.closed.connect(_on_settings_panel_closed)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


func _input(event):
	if Input.is_action_just_pressed("escape_button"):
		# If settings panel is open, close it first instead of dismissing the pause menu
		if settings_panel.visible:
			settings_panel.visible = false
			menu_panel.visible = true
			return
		enable_pause_menu.rpc(true)


@rpc("any_peer", "call_local", "reliable")
func enable_pause_menu(yes_no):
	if yes_no:
		get_tree().paused = true
		$CanvasLayer.visible = true
		# Always show menu buttons and hide settings when opening
		menu_panel.visible = true
		settings_panel.visible = false
	else:
		$CanvasLayer.visible = false
		get_tree().paused = false

func _on_resume_button_pressed():
	enable_pause_menu.rpc(false)


func _on_quit_game_button_pressed():
	get_tree().quit()


func _on_to_lobby_button_pressed():
	get_tree().paused = false
	root_map.exit_to_lobby()


func _on_to_main_menu_button_pressed():
	get_tree().paused = false
	root_map.exit_to_main_menu()


func _on_settings_button_pressed():
	menu_panel.visible = false
	settings_panel.visible = true


func _on_settings_panel_closed():
	settings_panel.visible = false
	menu_panel.visible = true
