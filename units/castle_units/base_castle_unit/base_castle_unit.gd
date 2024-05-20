extends Node2D

@export var faction = 99

var unit_id = 0
@export var siege_id = 0
var all_siege_ids = [50]

@export var direction_iddle = 0 # cunterclockwise, 1-4

@export var base_health = 20
@onready var health = base_health
var a_defense = 100

var selected = false

@onready var root_map = get_tree().root.get_child(1) # 0 je global properties autoloader :/
@onready var title_map = root_map.get_node("TileMap")
@onready var astar_grid = root_map.astar_grid
@onready var unit_position = title_map.local_to_map(global_position)


@onready var damage_label = preload("res://weapons/random/damage_label.tscn")





# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	set_direction_sprite()
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func damage_other_parts(damage: int):
	for unit in root_map.get_node("units").get_children():
		var unit_wr = weakref(unit)
		var unit_wr_obj = unit_wr.get_ref()
		if unit == self:
			continue
		if unit_wr_obj.unit_id == unit_id and unit_wr_obj.siege_id == siege_id:
			unit_wr_obj.lower_health(damage)


func set_direction_sprite():

	var r
	print(direction_iddle)
	if direction_iddle == 1:
		r = deg_to_rad(90)
		rotation = r
	elif direction_iddle == 2:
		r = deg_to_rad(180)
		rotation = r
	elif direction_iddle == 3:
		r = deg_to_rad(270)
		rotation = r
	else:
		rotation = 0
	
	
func set_selected(value):
	#queue_redraw()
	if selected != value:
		selected = value
		#lifebar.visible = value
		
func being_attacked_by(unit_wr_obj):
	pass

func get_damaged(damage: int, penetration: int, ):
	#dmg
	#a_pen
	#a_defense
	#hp
	#def = a_defense - a_pen
	#if def < 0: def = 0
	#hp - (dmg - def)
	var defense = a_defense - penetration
	if defense < 0:
		defense = 0
	damage = damage - defense
	if damage < 0:
		damage = 5
	health -= damage
	
	# create label
	var instance = damage_label.instantiate()
	instance.get_node("Label").damage = damage
	instance.position = global_position
	root_map.get_node("on_map_texts").add_child(instance)
	
	damage_other_parts(damage)
	
	if health <= 0:
		get_died()

func lower_health(damage: int,):
	health -= damage
	if health <= 0:
		get_died()


func get_died():
	# remove from selection list
	var units_selected = root_map.units_selected
	for i in units_selected:
		var index_ = units_selected.find(i)
		if i == self:
			units_selected.remove_at(index_)
	
	# remove from control groups
	var control_units_selected = root_map.control_units_selected
	for g in control_units_selected:
		for unit in g:
			var index_ = g.find(unit)
			if unit == self:
				g.remove_at(index_)

	astar_grid.set_point_solid(unit_position, false)
	
	queue_free()
	if units_selected.size() == 0:
		#Input.set_custom_mouse_cursor(cursor_default)
		root_map.get_node("UI").get_node("cursors").set_default_cursor()


func gr(weak_refer):
	if weak_refer == null:
		return null
	if weak_refer.get_ref() == null:
		return null
	else:
		return weak_refer.get_ref()
