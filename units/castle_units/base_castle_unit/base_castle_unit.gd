extends Node2D

@export var faction = 99

var map_unique_id
var unit_id = 0 # set in settings?
@export var siege_id = 0
var all_siege_ids = [50]



@export var base_health = 20
@onready var health = base_health
var a_defense = 100
var unit_strenght = 2 # for calculations

var is_small_door
@export var main_door = false

var selected = false

@onready var root_map = get_tree().root.get_node("game") # 0 je global properties autoloader :/
@onready var title_map_node = root_map.get_node("TileMap")
@onready var first_tilemap_layer = title_map_node.get_node("base_layer")
@onready var astar_grid = root_map.astar_grid
@onready var unit_position = first_tilemap_layer.local_to_map(global_position)


@onready var damage_label = preload("res://weapons/random/damage_label.tscn")





# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	#set_direction_sprite()
	
	register_unit_w_map()
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func set_act():
	pass

func damage_other_parts(damage: int):
	for unit in root_map.get_node("units").get_children():
		var unit_wr = weakref(unit)
		var unit_wr_obj = unit_wr.get_ref()
		if unit == self:
			continue
		if unit_wr_obj.unit_id == unit_id and unit_wr_obj.siege_id == siege_id:
			unit_wr_obj.lower_health(damage)


func set_selected(value):
	#queue_redraw()
	if selected != value:
		selected = value
		#lifebar.visible = value
		
func being_attacked_by(unit_wr_obj):
	pass

func get_damaged(damage: int, penetration: int, modifier=null):
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
	
	if modifier != null:
		if modifier == "ram" and self.unit_id in [500, 501]: # if a ram is attacking a castle door
			damage = 100
	
	health -= damage
	
	# create label
	var instance = damage_label.instantiate()
	instance.get_node("Label").damage = damage
	instance.position = global_position
	root_map.get_node("on_map_texts").add_child(instance)
	
	damage_other_parts(damage)
	
	if health <= 0:
		update_death.rpc()

func lower_health(damage: int,):
	health -= damage
	if health <= 0:
		update_death.rpc()

@rpc("authority", "call_local", "reliable")
func update_death():
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
	unregister_unit_w_map()
	
	if units_selected.size() == 0:
		#Input.set_custom_mouse_cursor(cursor_defau.get_ref() lt)
		root_map.get_node("UI").get_node("cursors").set_default_cursor()

# this is needed for multiplayer sync
func register_unit_w_map():
	root_map.incremental_unit_ids += 1
	self.map_unique_id = root_map.incremental_unit_ids
	root_map.all_units_w_unique_id[self.map_unique_id] = self

func unregister_unit_w_map():
	root_map.all_units_w_unique_id.erase(self.map_unique_id)

func gr(weak_refer):
	if weak_refer == null:
		return null
	if weak_refer.get_ref() == null:
		return null
	else:
		return weak_refer.get_ref()
