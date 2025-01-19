extends Node2D

var fade_duration: float = 1.0  # Time in seconds for the fade-out
var fade_timer: float = 0.0    # Tracks the elapsed time

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	# Increment the fade timer
	fade_timer += delta

	# Calculate fade progress (0.0 -> 1.0 over `fade_duration`)
	var fade_progress = fade_timer / fade_duration

	# Update transparency (alpha) by linearly reducing it
	var new_modulate = modulate
	new_modulate.a = lerp(1.0, 0.0, fade_progress)  # Reduce alpha to 0
	modulate = new_modulate

	# Destroy the object when fully transparent
	if fade_progress >= 1.0:
		queue_free()  # Remove the object from the scene

func _input(event):
	if event is InputEventMouseMotion:
		pass
	
	if Input.is_action_just_pressed("right_click"):
		queue_free()
