extends Node2D

var position_x_todestroy_itself

var speed = 60
var speed_multiplier

var cloud_sprites = [
	preload("res://weather/sprites/oblak_01.png"),
	preload("res://weather/sprites/oblak_02.png"),
	preload("res://weather/sprites/oblak_03.png"),
	preload("res://weather/sprites/oblak_04.png"),
	preload("res://weather/sprites/oblak_05.png"),
	preload("res://weather/sprites/oblak_06.png"),
	preload("res://weather/sprites/oblak_07.png")
]

# Called when the node enters the scene tree for the first time.
func _ready():
	speed_multiplier = randf_range(-30, 30)
	$cloud.texture = cloud_sprites[randi() % cloud_sprites.size()]

func _process(delta):
	# Move to the right at a steady speed
	var n_speed = (speed + speed_multiplier) * delta

	position.x += n_speed
	if is_outside_tilemap():
		queue_free()  # Destroy this node


func is_outside_tilemap() -> bool:
	if position.x > position_x_todestroy_itself:
		return true
	else:
		return false
