extends Control

@onready var parent_node = get_parent()
@onready var base_health = parent_node.base_health
var health = 0
@onready var progress_bar = $ProgressBar

# Called when the node enters the scene tree for the first time.
func _ready():
	#health = parent_node.health
	progress_bar.max_value = base_health
	progress_bar.value = base_health
	#print(parent_node.get_node("Sprite2D").texture.get_size())
	position.x -= parent_node.get_node("sprite_base").texture.get_size()[0] / 2
	position.y -= parent_node.get_node("sprite_base").texture.get_size()[1] - 6
	progress_bar.size.x = parent_node.get_node("sprite_base").texture.get_size()[1]
	progress_bar.size.y = 7
	#print(parent_node.name)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	health = parent_node.health
	progress_bar.value = health
