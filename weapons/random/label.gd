extends Label

var label_go_up_max = 300
var label_go_up = 0
var damage:= 0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	global_position.y -= 25


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	label_go_up += 5
	text = str(damage)
	self["theme_override_colors/font_color"] = Color.RED
	global_position.y = global_position.y - 50 * delta
	#print(global_position)
	if label_go_up > label_go_up_max:
		queue_free()

