extends Node2D

var position_x_todestroy_itself

var speed = 60
var speed_multiplier

var shadow: Sprite2D

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
	var chosen_texture = cloud_sprites[randi() % cloud_sprites.size()]
	$cloud.texture = chosen_texture
	$cloud.visible = false  # Hide the direct sprite; we render via the viewport

	# Create a shadow sprite in the CloudShadowsViewport
	shadow = Sprite2D.new()
	shadow.texture = chosen_texture
	shadow.material = load("res://weather/shaders/black_shadow.tres")

	var game = get_tree().root.get_node("game")
	var viewport = game.get_node("CloudShadowsViewport")
	viewport.add_child(shadow)


func _exit_tree():
	if shadow and is_instance_valid(shadow):
		shadow.queue_free()


func _process(delta):
	# Move to the right at a steady speed
	var n_speed = (speed + speed_multiplier) * delta

	position.x += n_speed

	# Update shadow position: convert world coords to viewport (screen) coords
	if shadow and is_instance_valid(shadow):
		var canvas_transform = get_viewport().get_canvas_transform()
		shadow.position = canvas_transform * global_position

	if is_outside_tilemap():
		queue_free()  # Destroy this node


func is_outside_tilemap() -> bool:
	if position.x > position_x_todestroy_itself:
		return true
	else:
		return false
