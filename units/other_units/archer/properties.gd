extends Node2D

@onready var parent_n = get_parent()

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	parent_n.unit_id = 1
	parent_n.agression_range = 16
	parent_n.attack_range = 16
	parent_n.m_speed = 100
	parent_n.primary_mele_fighter = false
	parent_n.attack_dmg_range = 40
	parent_n.attack_dmg_mele = 10
	
	parent_n.a_defense = 0
	parent_n.a_penetration = 10
	
	var sprite2d = parent_n.get_node("Sprite2D")
	sprite2d.new_red = 255
	sprite2d.new_green = 255
	sprite2d.new_blue = 255


