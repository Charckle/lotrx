extends Node2D

var speed = 300
var speed_multiplier
var direction = Vector2()
var wind_speed: int = 0
var wind_direction: int = 0

# Called when the node enters the scene tree for the first time.
func _ready():
	speed_multiplier = randf_range(-30, 30)
	var wind_speed_direction = self.wind_speed * self.wind_direction
	direction = Vector2(wind_speed_direction, 1).normalized()  # Steeper angle (x:1, y:2)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	# Move to the right at a steady speed
	#print((direction * speed * delta))
	var n_speed = (speed + speed_multiplier)
	self.position += direction * n_speed * delta
	#print(self.position)


func _on_timer_timeout():
	queue_free()
