extends Sprite2D

var cursor_default = load("res://sprites/gui/defaut_cursor.png")
var cursor_move = load("res://sprites/gui/move_to.png")
var cursor_attack = load("res://sprites/gui/attack_target.png")


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func set_attack_cursor():
	Input.set_custom_mouse_cursor(cursor_attack, Input.CURSOR_ARROW, Vector2(20,20))

func set_move_cursor():
	Input.set_custom_mouse_cursor(cursor_move, Input.CURSOR_ARROW, Vector2(20,20))

func set_default_cursor():
	Input.set_custom_mouse_cursor(cursor_default)
