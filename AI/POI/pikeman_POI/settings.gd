extends Node2D

@onready var parent_n = get_parent()

# Called when the node enters the scene tree for the first time.
func _ready():
	parent_n.unit_type = 5

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
