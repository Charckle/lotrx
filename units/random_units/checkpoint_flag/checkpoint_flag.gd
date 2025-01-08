extends Node2D

@export var faction = 1
@export var radious_ = 4

@onready var flag_sprite = $flag_sprite

@onready var root_map = get_tree().root.get_child(1) # 0 je global properties autoloader :/

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
	
func _draw():
	draw_range()


func _on_timer_timeout():
	check_units_in_radious()
	

func check_units_in_radious():
	var range_of_poi = self.radious_ * root_map.m_cell_size
	# get all units in radious
	var close_units = []
	for unit in root_map.get_all_units():
		var unit_wr = weakref(unit)
		var unit_wr_obj = unit_wr.get_ref()
		
		var distance = int(global_position.distance_to(unit_wr_obj.global_position))
		var in_range = range_of_poi - distance
		
		if in_range > 0:
			close_units.append(unit_wr_obj)
	
	# now check if all units are one faction
	if not close_units.is_empty():
		var units_num = 0
		
		for unit in close_units:
			if unit.faction != self.faction:
				units_num += 1
		
		if units_num == close_units.size():
			self.faction = close_units[0].faction
			flag_sprite.set_flag_color()


func draw_range():
	var range_of_poi = self.radious_ * root_map.m_cell_size
	
	if GlobalSettings.global_options["gameplay"]["agression_rage"] == true:
		draw_arc(Vector2(0,0), range_of_poi + 2, 0, 260, 20, Color.BLACK)
