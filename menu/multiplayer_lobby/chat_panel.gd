extends Panel

@onready var input_msg_box = $VBoxContainer/LineEdit
@onready var msg_log_container = $messages_panel/ScrollContainer/VBoxContainer

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass




@rpc("any_peer", "call_local", "reliable")
func receive_chat_message(message: String):
	var chat_label = Label.new()
	var peer_id = multiplayer.get_remote_sender_id()
	
	var player_name = GlobalSettings.multiplayer_data["players"][peer_id]["name"]
	
	chat_label.text = player_name + ": " + message
	chat_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	msg_log_container.add_child(chat_label)


func _on_line_edit_text_submitted(new_text: String) -> void:
	var msg = $LineEdit.text
	receive_chat_message.rpc(msg)
	$LineEdit.clear()
