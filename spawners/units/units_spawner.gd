extends Node2D


@export var faction = 1
@export var unit_type = 0
@export var unit_numbers = 1
@onready var root_map = get_tree().root.get_node("game")
@onready var tile_map_layer = root_map.get_node("TileMap/base_layer")
@onready var my_position_2i = tile_map_layer.local_to_map(global_position)

@onready var peasant = preload("res://units/other_units/peasant/peasant.tscn")
@onready var archer = preload("res://units/other_units/archer/archer.tscn")
@onready var crossbow = preload("res://units/other_units/crossbow/crossbow.tscn")
@onready var knight = preload("res://units/other_units/knight/knight.tscn")
@onready var maceman = preload("res://units/other_units/maceman/maceman.tscn")
@onready var pikeman = preload("res://units/other_units/pikeman/pikeman.tscn")
@onready var swordsman = preload("res://units/other_units/swordsman/swordsman.tscn")

#0	Peasant
#1	Archer
#2	Crossbow
#3	Knight
#4	Maceman
#5	Pikeman
#6	Swordsman

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	spawn()
	

func spawn():
	var offsets = _get_spawn_offsets(unit_numbers)
	for offset in offsets:
		var tile_pos = my_position_2i + offset
		var instance = get_unit_().instantiate()
		instance.position = tile_map_layer.map_to_local(tile_pos)
		instance.faction = faction
		root_map.get_node("units").add_child(instance)
	queue_free()


# Returns tile offsets from center in formation order:
#   Row 0: center, right, left  ->  Row 1: center, right, left
#   Then expand both rows outward: +2/-2 on row 0, +2/-2 on row 1, etc.
func _get_spawn_offsets(count: int) -> Array:
	var offsets = []
	if count <= 0:
		return offsets

	# Phase 1: Row 0 center-out (center, right, left)
	var initial_x = [0, 1, -1]
	for x in initial_x:
		if offsets.size() >= count:
			break
		offsets.append(Vector2i(x, 0))

	# Phase 2: Row 1 center-out (center, right, left)
	for x in initial_x:
		if offsets.size() >= count:
			break
		offsets.append(Vector2i(x, 1))

	# Phase 3: Expand outward on both rows, left and right
	var x_dist = 2
	while offsets.size() < count:
		for row in range(2):
			if offsets.size() >= count:
				break
			offsets.append(Vector2i(x_dist, row))
			if offsets.size() >= count:
				break
			offsets.append(Vector2i(-x_dist, row))
		x_dist += 1

	return offsets

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
