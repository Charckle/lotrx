extends Control

## Open chat with Enter or T. Close with Escape or the X button.

@onready var chat_panel = $ChatPanel
@onready var close_button = $CloseButton

func _ready() -> void:
	chat_panel.visible = false
	close_button.visible = false
	close_button.pressed.connect(_close_chat)
	if multiplayer.multiplayer_peer == null:
		visible = false
		process_mode = PROCESS_MODE_DISABLED


func _input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	# Close chat: Escape only
	if chat_panel.visible and key_event.keycode == KEY_ESCAPE:
		_close_chat()
		get_viewport().set_input_as_handled()
		return
	# Open chat: Enter or T (only when chat is closed, so Enter can submit when open)
	if not chat_panel.visible and (key_event.keycode == KEY_ENTER or key_event.keycode == KEY_KP_ENTER or key_event.keycode == KEY_T):
		_open_chat()
		get_viewport().set_input_as_handled()


func _open_chat() -> void:
	chat_panel.visible = true
	close_button.visible = true
	chat_panel.get_node("LineEdit").grab_focus()


func _close_chat() -> void:
	chat_panel.visible = false
	close_button.visible = false
	chat_panel.get_node("LineEdit").release_focus()


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	if not chat_panel.visible and (key_event.keycode == KEY_ENTER or key_event.keycode == KEY_KP_ENTER or key_event.keycode == KEY_T):
		_open_chat()
		get_viewport().set_input_as_handled()
