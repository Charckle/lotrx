extends Node

## Central chat log and RPC. All chat instances sync from chat_log and new_message.

# peer_id 0 = system messages (server announcements)
# Otherwise peer_id = multiplayer peer who sent the message
var chat_log: Array[Dictionary] = []

signal new_message(entry: Dictionary)

func _ready() -> void:
	pass


func add_message(peer_id: int, message: String) -> void:
	var entry = {"peer_id": peer_id, "message": message}
	chat_log.append(entry)
	new_message.emit(entry)


@rpc("any_peer", "call_local", "reliable")
func send_chat_message(message: String) -> void:
	var peer_id = multiplayer.get_remote_sender_id()
	add_message(peer_id, message)


@rpc("any_peer", "call_local", "reliable")
func send_system_message(message: String) -> void:
	add_message(0, message)


func clear_log() -> void:
	chat_log.clear()
