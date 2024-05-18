extends Node2D


@export var faction = 1
@export var unit_type = 0
@export var unit_numbers = 1
@onready var root_map = get_tree().root.get_child(1) # 0 je global properties autoloader :/
@onready var title_map = root_map.get_node("TileMap")
@onready var my_position_2i = title_map.local_to_map(global_position)

@onready var peasant = preload("res://units/other_units/peasant/peasant.tscn")
@onready var archer = preload("res://units/other_units/archer/archer.tscn")
@onready var crossbow = preload("res://units/other_units/crossbow/crossbow.tscn")
@onready var knight = preload("res://units/other_units/knight/knight.tscn")
@onready var maceman = preload("res://units/other_units/maceman/maceman.tscn")
@onready var pikeman = preload("res://units/other_units/pikeman/pikeman.tscn")
@onready var swordsman = preload("res://units/other_units/swordsman/swordsman.tscn")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	spawn()
	

func spawn():
	#next_cell_global = title_map.map_to_local(next_cell)
	#if astar_grid.is_point_solid(next_cell):
	var place_position = my_position_2i
	for num in range(unit_numbers):
		print(my_position_2i)
		var instance = get_unit_().instantiate()
		instance.position = title_map.map_to_local(my_position_2i)
		instance.faction = faction
		root_map.get_node("units").add_child(instance)
		my_position_2i.x += 1
		print("added")
		

func get_unit_():
	var units_builders = {
		0: peasant,
		1: archer,
		2: crossbow,
		3: knight,
		4: maceman,
		5: pikeman,
		6: swordsman
	}
	
	return units_builders[unit_type]
