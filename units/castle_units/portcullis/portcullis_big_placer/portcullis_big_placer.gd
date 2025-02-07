extends Node2D

@onready var small_door_obj = load("res://units/castle_units/portcullis/portcullis.tscn")
@onready var root_map = get_tree().root.get_node("game")
var units_node = null

@export var faction = 1
@export var main_door = false
@export var new_siege_id = -1
@export var door_health = 1000


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	place_doors()


func place_doors():
	var sprite_01 = $"spriteNode/Sprite2D"
	var sprite_02 = $"spriteNode/Sprite2D2"
	var sprite_03 = $"spriteNode/Sprite2D3"
	var sprite_04 = $"spriteNode/Sprite2D4"

	units_node = root_map.get_node("units")
	if new_siege_id == -1:
		new_siege_id = units_node.get_child_count()
	
	for sprite_ in $spriteNode.get_children():
		create_instance(sprite_.global_position, new_siege_id)
	
	queue_free()


func create_instance(coordinates_, new_siege_id):
	var instance = small_door_obj.instantiate()
	instance.position = coordinates_
	instance.faction = faction
	instance.main_door = main_door
	instance.siege_id = new_siege_id
	instance.base_health = self.door_health
	instance.rotation = self.rotation
	units_node.add_child(instance)
