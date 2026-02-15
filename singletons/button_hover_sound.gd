extends Node

var button_sound = preload("res://audio/sounds/menu/click-151673.mp3")

func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)
	# Also catch any buttons already in the tree
	call_deferred("_connect_existing_buttons")

func _connect_existing_buttons() -> void:
	_scan_node(get_tree().root)

func _scan_node(node: Node) -> void:
	if node is BaseButton:
		if not node.mouse_entered.is_connected(_play_hover_sound):
			node.mouse_entered.connect(_play_hover_sound)
	for child in node.get_children():
		_scan_node(child)

func _on_node_added(node: Node) -> void:
	if node is BaseButton:
		if not node.mouse_entered.is_connected(_play_hover_sound):
			node.mouse_entered.connect(_play_hover_sound)

func _play_hover_sound() -> void:
	var sound = AudioStreamPlayer.new()
	sound.stream = button_sound
	sound.bus = "sfx"
	add_child(sound)
	sound.play()
	sound.finished.connect(sound.queue_free)
