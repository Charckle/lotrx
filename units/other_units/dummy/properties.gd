extends Node2D


@onready var parent_n = get_parent()

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	parent_n.agression_range = 0
	parent_n.attack_range = 0
	parent_n.m_speed = 0
	parent_n.attack_dmg_range = 0
	parent_n.attack_dmg_mele = 0
	
	parent_n.a_defense = 20
	parent_n.a_penetration = 0
