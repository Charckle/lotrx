extends Node2D

@onready var parent_n = get_parent()

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	parent_n.unit_id = 7
	parent_n.attack_range = 1
	parent_n.m_speed = 230
	parent_n.primary_mele_fighter = true
	parent_n.attack_dmg_range = 0
	parent_n.attack_dmg_mele = 50
	
	parent_n.a_defense = 10
	parent_n.a_penetration = 0
	parent_n.unit_strenght = 1
	
	var sprite2d = parent_n.get_node("sprite_base")
	sprite2d.new_red = 255
	sprite2d.new_green = 255
	sprite2d.new_blue = 255


