extends Node2D

@onready var small_door_obj = load("res://units/castle_units/small_door/small_door.tscn")
@onready var parent_n = get_parent()
var units_node = null

@export var faction = 1

# Called when the node enters the scene tree for the first time.
func _ready():
	place_doors()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


func place_doors():
	var sprite_01 = $"spriteNode/Sprite2D"
	var sprite_02 = $"spriteNode/Sprite2D2"

	units_node = parent_n.get_parent().get_node("units")
	
	create_instance(sprite_01.global_position, 0)
	create_instance(sprite_02.global_position, 2)
	
	queue_free()


func create_instance(coordinates_, direction_iddle_):
	var instance = small_door_obj.instantiate()
	instance.position = coordinates_
	instance.direction_iddle = direction_iddle_
	instance.faction = faction
	units_node.add_child(instance)
