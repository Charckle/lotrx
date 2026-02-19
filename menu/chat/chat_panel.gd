extends Panel

@onready var line_edit = $LineEdit
@onready var msg_log_container = $messages_panel/ScrollContainer/VBoxContainer

const SYSTEM_PEER_ID = 0

func _ready() -> void:
	_clear_display()
	_fill_from_chat_log()
	ChatManager.new_message.connect(_on_new_message)


func _exit_tree() -> void:
	if ChatManager.new_message.is_connected(_on_new_message):
		ChatManager.new_message.disconnect(_on_new_message)


func _clear_display() -> void:
	for child in msg_log_container.get_children():
		child.queue_free()


func _fill_from_chat_log() -> void:
	for entry in ChatManager.chat_log:
		_append_entry(entry)


func _on_new_message(entry: Dictionary) -> void:
	_append_entry(entry)


func _scroll_to_bottom() -> void:
	var scroll = msg_log_container.get_parent()
	if scroll is ScrollContainer:
		call_deferred("_set_scroll_to_bottom", scroll)


func _set_scroll_to_bottom(scroll: ScrollContainer) -> void:
	scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)


static func _name_to_color(name_str: String) -> Color:
	var h = (name_str.hash() % 360) / 360.0
	if h < 0:
		h += 1.0
	return Color.from_hsv(h, 0.75, 1.0)


func _append_entry(entry: Dictionary) -> void:
	var peer_id: int = entry["peer_id"]
	var message: String = entry["message"]

	var display_name: String
	var color: Color
	if peer_id == SYSTEM_PEER_ID:
		display_name = "System"
		color = Color(0.6, 0.6, 0.6)
	else:
		var players = GlobalSettings.multiplayer_data.get("players", {})
		var player = players.get(peer_id, {})
		display_name = player.get("name", "Player")
		var lobby_color = player.get("color", null)
		if lobby_color is Dictionary and lobby_color.has("red") and lobby_color.has("green") and lobby_color.has("blue"):
			color = Color(lobby_color["red"] / 255.0, lobby_color["green"] / 255.0, lobby_color["blue"] / 255.0)
		else:
			color = _name_to_color(display_name)

	var row = HBoxContainer.new()

	var name_label = RichTextLabel.new()
	name_label.bbcode_enabled = true
	name_label.fit_content = true
	name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	var hex = color.to_html(false)
	name_label.text = "[color=#%s]%s[/color]:" % [hex, display_name]
	row.add_child(name_label)

	var msg_label = Label.new()
	msg_label.text = " " + message
	msg_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(msg_label)

	msg_log_container.add_child(row)
	_scroll_to_bottom()


func _on_line_edit_text_submitted(_new_text: String) -> void:
	var msg = line_edit.text.strip_edges()
	line_edit.clear()
	if msg.is_empty():
		return
	ChatManager.send_chat_message.rpc(msg)
