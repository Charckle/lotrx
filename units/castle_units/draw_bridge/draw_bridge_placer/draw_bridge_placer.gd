extends Node2D

var units_node = null

@export var faction = 1
@export var main_door = false
@export var new_siege_id = -1
@export var door_health = 2500

@onready var draw_bridge = load("res://units/castle_units/draw_bridge/draw_bridge.tscn")
@onready var root_map = get_tree().root.get_node("game")

var left_hindge = preload("res://sprites/castle/draw_bridge/closed_01.png")
var middle_section = preload("res://sprites/castle/draw_bridge/closed_02.png")


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
	
	create_instance(sprite_01.global_position, new_siege_id, left_hindge)
	create_instance(sprite_02.global_position, new_siege_id, middle_section)
	create_instance(sprite_03.global_position, new_siege_id, middle_section)
	create_instance(sprite_04.global_position, new_siege_id, left_hindge, true)
	
	queue_free()


func create_instance(coordinates_, new_siege_id, sprite_, mirrored = false):
	var instance = draw_bridge.instantiate()
	instance.position = coordinates_
	instance.faction = faction
	instance.main_door = main_door
	instance.siege_id = new_siege_id
	instance.base_health = self.door_health
	instance.rotation = self.rotation
	var base_sprite = instance.get_node("spriteNode").get_node("base_sprite")
	base_sprite.set_texture(sprite_)

	
	if mirrored == true:
		base_sprite.flip_h = true
	
	units_node.add_child(instance)
