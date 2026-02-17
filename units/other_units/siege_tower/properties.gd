extends Node2D

@onready var parent_n = get_parent()

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	#dmg
	#a_pen
	#a_defense
	#hp
	#def = a_defense - a_pen
	#if def < 0: def = 0
	#hp - (dmg - def)
	
	parent_n.unit_id = 9 # 9 siege_tower
	parent_n.agression_range_base = 10
	parent_n.agression_range = 10
	parent_n.attack_range = 10
	#parent_n.m_speed = 20
	parent_n.m_speed = 300
	parent_n.primary_mele_fighter = false
	parent_n.can_dig = false
	parent_n.siege_weapon = true
	parent_n.attack_dmg_range = 40
	parent_n.attack_dmg_mele = 0
	var base_health = 800
	parent_n.base_health = base_health
	parent_n.aggressive = false
	
	parent_n.a_defense = 50
	parent_n.a_penetration = 10
	parent_n.unit_strenght = 1 # for calculating army strenght
	
	var sprite2d = parent_n.get_node("sprite_base")
	sprite2d.new_red = 255
	sprite2d.new_green = 255
	sprite2d.new_blue = 255
