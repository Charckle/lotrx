extends Node2D

var timer_ = 1

var speed = 50
var velocity 

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$Sprite2D.self_modulate.a = 0.7
	
	var angle = deg_to_rad(0 + randf_range(-30, 30))  # Random between 60° and 120°
	
	# Calculate velocity
	var direction = Vector2.UP.rotated(angle)  # Rotate the upward direction
	velocity = direction * speed
	


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if timer_ < 0:
		timer_ = 10
		$Sprite2D.self_modulate.a -= 0.1
		
		if $Sprite2D.self_modulate.a <= 0:
			queue_free()
	timer_ -= 1
	
	#global_position.y = global_position.y - speed * delta
	position += velocity * delta
