extends Area2D

@export var debugging_ = false

enum State { IDLE, ATTACKING, DEFENDING, RETREATING, DIGGING }
var current_state = State.IDLE # ATM just for digging

var map_unique_id
var unit_id = 0
var ranged_unit_ids = GlobalSettings.my_faction.get_list_of_ranged()
var primary_mele_fighter = true
var can_dig = true
var siege_weapon = false
#@export var siege_id = 0
@export var aggressive = true
@export var base_health = 120
@onready var health = base_health
var a_defense = 0
var a_penetration = 0
var unit_strenght = 1 # for calculations

@export var m_speed = 100

@export var faction = 1
@export var friendly_factions = []

var selected = false
@onready var agression_bar = $agression_bar
@onready var lifebar = $lifebar
@onready var control_group_label = $control_group_label
@onready var debug_label = $debug_label

@onready var root_map = get_tree().root.get_node("game") # 0 je global properties autoloader :/
@onready var title_map_node = root_map.get_node("TileMap")
@onready var first_tilemap_layer = title_map_node.get_node("base_layer")
@onready var astar_grid = root_map.astar_grid
@onready var unit_position = first_tilemap_layer.local_to_map(global_position)
@onready var old_unit_position = first_tilemap_layer.local_to_map(global_position)
@onready var unit_position_iddle = first_tilemap_layer.local_to_map(global_position) # return to this position if baited, but enemy out of agro range

var is_moving: bool
var target_walk: Vector2
var old_target_walk: Vector2
var current_id_path: Array
var current_point_path: PackedVector2Array

@export var stance = 0 #(0: attack, 1 is defense)

var agression_radius = 6 #not in use
var agression_radius_array = [] #not in use
@export var agression_range_base = 5 # when it gets aggressive
@export var agression_range = agression_range_base
@onready var aggression_rage_px = agression_range * root_map.m_cell_size
var walking_in_agression = false

@export var attack_range = 1 # when it can accatck
@onready var attack_rage_px_base = attack_range * root_map.m_cell_size
@onready var attack_rage_px = attack_rage_px_base
@onready var damage_label = preload("res://weapons/random/damage_label.tscn")
@onready var dig_att = load("res://weapons/mele/dig_att/dig_att.tscn")

var selected_target = load("res://sprites/gui/selected_target.png")
var sprite_walk_target = load("res://sprites/gui/going_mark.png")

var units_pining_me = []
var pinning_blocks = []
var is_pinned = false #for long range, if someone who is attacking is in the next cell
var is_attacking = false
var target_attack = null
var target_attack_passive = null
var attack_dmg_mele = 40
var attack_dmg_range = 40

@export var font: Font
var control_group = null

# pathinding retrying
var times_to_retry = 4
var retried_times = 0
var timer_started = false
# END pathinding retrying

var timer_ = 1

func get_right_target():
	if gr(target_attack) != null:
		return target_attack
	elif gr(target_attack_passive) != null:
		return target_attack_passive
	else:
		return null


# Called when the node enters the scene tree for the first time.
func _ready():
	lifebar.progress_bar.max_value = base_health
	lifebar.progress_bar.value = base_health
	target_walk = unit_position
	
	pinning_blocks = get_adjecent_blocks()
	set_stance(self.stance)
	register_unit_w_map()
	pass

func _draw():
	if selected:
		draw_agression_rage()
		draw_attack_rage()
		draw_target()
		draw_control_group_id()
		draw_debug_data()
		draw_target_walk()
		

func set_timer(delta):
	if timer_ < 0:
		timer_ = 1
	timer_ -= 1 * delta
	
func check_stance():
	if selected and faction == GlobalSettings.my_faction:
		if stance == 0:
			# normal stance
			$stance_sprite.visible = false
		else:
			$stance_sprite.visible = true
	else:
		$stance_sprite.visible = false

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	self.check_stance()
	
	agression_bar.visible = walking_in_agression
	
	if selected:
		queue_redraw()
	
	# multiplayer cut-off
	if not multiplayer.is_server():
		return
	
	set_timer(delta)
		
	# remove the target, if it dies
	# what aour passive???
	if target_attack != null and gr(target_attack) == null:
		update_target_attack.rpc(null)
	
	
	if target_attack_passive != null and gr(target_attack_passive) == null:
		update_target_attack_passive.rpc(null)
	
	if gr(get_right_target()) != null:
		alert_target()
	
	check_who_pinning_me()
	
	
	# mark change of position and free or free the spot
	if unit_position != old_unit_position:
		#root_map.update_astar_grid_units()
		astar_grid.set_point_solid(old_unit_position, false)
		astar_grid.set_point_solid(unit_position)
		old_unit_position = unit_position
		
		# get new 1 sorounding squares
		pinning_blocks = get_adjecent_blocks()
	

	
	# get_aggression_cells()
	
	# this shit....
	check_soroundings()
	
	
	

@rpc("authority", "call_local", "reliable")
func update_target_attack(target_attack_id):
	if target_attack_id == null:
		target_attack = null
	else:
		if target_attack_id in root_map.all_units_w_unique_id:
			target_attack = weakref(root_map.all_units_w_unique_id[target_attack_id])

@rpc("authority", "call_local", "reliable")
func update_target_attack_passive(target_attack_passive_id):
	if target_attack_passive_id == null or target_attack_passive_id not in root_map.all_units_w_unique_id:
		target_attack_passive = null
	else:
		target_attack_passive = weakref(root_map.all_units_w_unique_id[target_attack_passive_id])



func set_selected(value):
	queue_redraw()
	if selected != value:
		selected = value
		lifebar.visible = value
		control_group_label.visible = value
		debug_label.visible = value

func _on_input_event(viewport, event, shape_idx):
	if event is InputEventMouseButton:
		if event.is_pressed():
			if event.button_index == MOUSE_BUTTON_LEFT:
				if not Input.is_action_pressed("shift_"):
					root_map.deselect_all_units()
				
				if self not in root_map.units_selected:
					root_map.units_selected.append(self)
					
				set_selected(true)

func _on_mouse_entered() -> void:
	if root_map.units_selected.size() > 0:
		if faction != GlobalSettings.my_faction:
			self.lifebar.visible = true
			#Input.set_custom_mouse_cursor(cursor_attack, Input.CURSOR_ARROW, Vector2(20,20))
			root_map.get_node("UI").get_node("cursors").set_attack_cursor()

func _on_mouse_exited() -> void:
	if faction != GlobalSettings.my_faction:
		self.lifebar.visible = false
	if root_map.units_selected.size() > 0:
		#Input.set_custom_mouse_cursor(cursor_move, Input.CURSOR_ARROW, Vector2(20,20))
		root_map.get_node("UI").get_node("cursors").set_move_cursor()
	else:
		root_map.get_node("UI").get_node("cursors").set_default_cursor()
		#Input.set_custom_mouse_cursor(cursor_default)


func check_who_pinning_me():
	if primary_mele_fighter == false:
		if units_pining_me.size() > 0:
			var temp_arr = units_pining_me.duplicate()
			for tu in temp_arr:
				var index_ = temp_arr.find(tu)
				if gr(tu) == null:
					units_pining_me.remove_at(index_)
					continue
				if gr(tu).unit_position in pinning_blocks:
					is_pinned = true
				else:
					units_pining_me.remove_at(index_)
			
			
			# change target to one who is pinning
			if get_right_target() != null:
				if gr(get_right_target()).unit_position not in pinning_blocks:
					update_target_attack.rpc(null)
					update_target_attack_passive.rpc(null)
			
		else:
			is_pinned = false

#func set_move(recalc=false):
func set_move(target_move_to=null): # null means it will just recalculate the old target
	update_target_attack.rpc(null)
	is_attacking = false
	move_(target_move_to)

func set_attack(unit_map_unique_id: int):
	update_target_attack.rpc(unit_map_unique_id)
	is_attacking = true
	if unit_map_unique_id in root_map.all_units_w_unique_id:
		target_walk = root_map.all_units_w_unique_id[unit_map_unique_id].unit_position
	else:
		root_map.all_units_w_unique_id.erase(unit_map_unique_id)
	move_()

func move_(target_move_to=null):
	current_state = State.IDLE # used for digging ATM
	root_map.get_solid_points()
	
	if target_move_to != null:
		#var mouse_pos = get_global_mouse_position()
		target_walk = first_tilemap_layer.local_to_map(target_move_to)
		# set iddle position for returnign to it, if not in agro anymore
		unit_position_iddle = Vector2i(target_walk.x, target_walk.y)
	
	var unit_pos_for_calc = unit_position
	
	# if attacking, it will always be 0
	var new_id_path
	var return_solid = false
	var solid_tile = target_walk
	if astar_grid.is_point_solid(target_walk):
		astar_grid.set_point_solid(solid_tile, false)
		return_solid = true
		
	new_id_path = astar_grid.get_id_path(unit_pos_for_calc, target_walk, true)
	target_walk = new_id_path[-1]
	
	if return_solid:
		astar_grid.set_point_solid(solid_tile)
	
	current_id_path = new_id_path
	
	get_going_arraw_line()

func set_stance(stance:int):
	if unit_id not in ranged_unit_ids:
		self.stance = stance
		if stance == 1:
			agression_range = 1.5
		else:
			agression_range = self.agression_range_base

		self.aggression_rage_px = agression_range * root_map.m_cell_size



func get_going_arraw_line():
	current_point_path = astar_grid.get_point_path(
		unit_position, target_walk
	)
	for i in current_point_path.size():
		current_point_path[i] = current_point_path[i] + Vector2(21,21)

func _physics_process(delta):
	if not multiplayer.is_server():
		return
	# WHEN MOVING IN GROUPS, THEY TRY TO FIND THE NEEREST OF THE ONE IN FRONT OF THEM, NOT THE TARGET ONE. ALWAYS THE TARGET ONE
	var old_global_position = global_position
	
	if current_id_path.is_empty():
		is_moving = false
		return
	
	var next_cell = current_id_path.front()
	# needed, because godot is retarded
	if next_cell == null:
		return
	var next_cell_global = first_tilemap_layer.map_to_local(next_cell)
	
	# check if the next step is free, otherwise, recalc the route
	if astar_grid.is_point_solid(next_cell) and next_cell != unit_position:
		#print(astar_grid.is_point_solid(title_map.map_to_local(current_id_path.front())))
		
		# if the next cell is the last cell, stop
		if next_cell == Vector2i(target_walk):
			current_id_path = []
			target_walk = unit_position
			
			# check if net cell is moat. if its moat, dig
			if can_dig == true:
				for moat_obj in root_map.get_node("moat").get_node("moat_obj").get_children():
					if moat_obj.unit_position == next_cell:
						# make digging magic
						target_attack = weakref(moat_obj)
						current_state = State.DIGGING
			elif unit_id == 9:
				$attack.deploy_siege.rpc(next_cell)
		# if the next cell is not, wait a little bit
		elif retried_times <= times_to_retry:
			if not timer_started:
				$walk_timer.start()
				timer_started = true

				
		# done waiting, find new path
		else:
			retried_times = 0
			move_()
		return
	
	# if path is free, reset retry walking timer
	retried_times = 0

	astar_grid.set_point_solid(next_cell)
	unit_position = next_cell
	#astar_grid.set_point_solid(unit_position)

	if is_moving == false:
		is_moving = true
	

	global_position = global_position.move_toward(next_cell_global, m_speed * delta)
	
	if is_attacking == true:
		if gr(target_attack) and $attack.in_range(target_attack):
			is_moving = false
			
			current_id_path = [next_cell]
			update_global_pos.rpc(global_position)
			return


	if global_position == next_cell_global:
		current_id_path.pop_front()
		if current_point_path.size() > 0:
			current_point_path.remove_at(0)
	
	if old_global_position != global_position:
		update_global_pos.rpc(global_position)
	
@rpc("authority", "call_remote", "unreliable_ordered")
func update_global_pos(global_position_):
	global_position = global_position_



#func get_aggression_cells():
	#agression_radius_array.clear()
	#var center = unit_position
	#
	#for i in range(agression_radius):
		##print("in range: " + str(i))
		#var left = i + 1
		#var right = i + 2
		#for x in range(center[0] - left, center[0] + right):
			#for y in range(center[1] - left, center[1] + right):
				## Check if the current point is the center point
				#var neighbour_point = Vector2i(x, y)
				#if neighbour_point != center:
					#agression_radius_array.append(neighbour_point)
	
	#print(agression_radius_array)


func check_soroundings():
	if siege_weapon == true:
		return
	if is_moving:
		update_target_attack_passive.rpc(null)
	
	if current_state == State.DIGGING:
		# check for clossst moat, go there
		get_closest_moat()
	
	if gr(get_right_target()) == null and not is_moving:
		if timer_ < 0:
			calclulate_if_in_agression()
			
	if gr(target_attack_passive) != null:
		if not $attack.in_range(target_attack_passive):
			if aggressive and primary_mele_fighter:
				target_walk = gr(target_attack_passive).unit_position
				print_("agressive!!!")
				set_walk_in_aggression.rpc(true)
				move_()
			else:
				update_target_attack_passive.rpc(null)


@rpc("authority", "call_local", "reliable")
func set_walk_in_aggression(yes_no):
	walking_in_agression = yes_no


func get_closest_moat():
	var close_moats = []
	
	for moat in root_map.get_node("moat").get_children():
		var moat_wr = weakref(moat)
		var distance = int(global_position.distance_to(moat.global_position))
		var in_range = aggression_rage_px - distance
		
		if in_range > 0:
			close_moats.append([moat_wr, in_range])
		
		if not close_moats.is_empty():
			close_moats.sort_custom(func(a, b): return a[1] > b[1])
			update_target_attack.rpc(gr(close_moats[0][0]).map_unique_id)
			
		else:
			current_state = State.IDLE # used for digging ATM
			


func calclulate_if_in_agression():
	var close_units = []
	
	for unit in root_map.get_all_units():
		var unit_wr = weakref(unit)
		#var unit_wr_obj = unit_wr.get_ref()
		if unit == self:
			continue
		if unit.faction == self.faction or unit.faction in self.friendly_factions:
			continue
		var distance = int(global_position.distance_to(unit.global_position))
		#print(distance)
		var in_range = aggression_rage_px - distance
		#print(aggression_rage_px)
		#print(distance)
		if in_range > 0:
			close_units.append([unit_wr, in_range])
			#print("distanceit is in range")
			#print(distance)
			#print(in_range > 0)
	
	# sort units to closest one
	
	if not close_units.is_empty():
		close_units.sort_custom(func(a, b): return a[1] > b[1])
		update_target_attack_passive.rpc(gr(close_units[0][0]).map_unique_id)
	# return to iddle position if not agro anymore
	elif unit_position_iddle != unit_position:
		if walking_in_agression:
			target_walk = unit_position_iddle
		set_walk_in_aggression.rpc(false)
		move_()



#func draw_aggression_blocks():
	##draw agression diameter
	#for block in agression_radius_array:
		#var x = block[0]
		#var y = block[1]
		#
		#var global_position_2i = Vector2i(global_position.x, global_position.y)
		#
		##var position_ = Vector2i(x, y)
		##print(position_)
		##var cell_size = Vector2i(root_map.m_cell_size, root_map.m_cell_size)

func draw_agression_rage():
	if GlobalSettings.global_options["gameplay"]["agression_rage"] == true:
		draw_arc(Vector2(0,0), aggression_rage_px + 2, 0, 260, 20, Color.WHITE)

func draw_attack_rage():
	if GlobalSettings.global_options["gameplay"]["attack_rage"] == true:
		draw_arc(Vector2(0,0), attack_rage_px, 0, 260, 20, Color.FIREBRICK)
	
func draw_target():
	if get_right_target() != null and faction == GlobalSettings.my_faction:
		var draw_loc = gr(get_right_target()).global_position - global_position - Vector2(20, 20)
		draw_texture(selected_target,draw_loc)

func draw_target_walk():
	draw_texture(sprite_walk_target, Vector2(first_tilemap_layer.map_to_local(target_walk))-global_position - Vector2(20, 20))
	
func draw_control_group_id():
	if control_group != null:
		self.control_group_label.text = str(control_group)

func draw_debug_data():
	if GlobalSettings.global_options["debug"]["global_debug"] == true:
		var string_ = str(aggressive) + "\n" + str(is_moving) + "\n" +  str(current_id_path.size())
		self.debug_label.text = str(stance) #str(retried_times)

func set_act():
	if GlobalSettings.my_faction == faction:
		walking_in_agression = false
		var mouse_pos = get_global_mouse_position()
		var unit_wr = root_map.get_wr_unit_on_mouse_position()
		#if location has a hostile unit attack, otherwise, move
		# root_map.all_units_w_unique_id[self.map_unique_id]
		if gr(unit_wr) == null:
			root_map.commands_in_last_tick.append({"func": "set_move",
			 "args": [mouse_pos],
			 "map_unique_id": self.map_unique_id,
			 "curr_tick": root_map.current_tick})
			#set_move(mouse_pos)
		else:
			if gr(unit_wr).faction == GlobalSettings.my_faction:
				root_map.commands_in_last_tick.append({"func": "set_move",
				 "args": [mouse_pos], 
				"map_unique_id": self.map_unique_id,
				"curr_tick": root_map.current_tick})
				#set_move(mouse_pos)
			else:
				root_map.commands_in_last_tick.append({"func": "set_attack", 
				#"args": [unit_wr], 
				"args": [gr(unit_wr).map_unique_id], 
				"map_unique_id": self.map_unique_id,
				"curr_tick": root_map.current_tick})
				#set_attack(unit_wr)


func get_adjecent_blocks(circle=1):
	var center = unit_position
	var neighbour_points = []
	
	for i in range(circle):
		var left = i + 1
		var right = i + 2
		#print("in range: " + str(i))
		for x in range(center[0] - left, center[0] + right):
			for y in range(center[1] - left, center[1] + right):
				# Check if the current point is the center point
				var neighbour_point = Vector2i(x, y)
				neighbour_points.append(neighbour_point)
	return neighbour_points
	
	
func get_adjecent_units():
	var neighbour_points = get_adjecent_blocks()
	
	var close_units = []
	for unit in root_map.get_all_units():
		var unit_wr = weakref(unit)
		var unit_wr_obj = unit_wr.get_ref()
		if unit == self:
			continue
		if unit_wr_obj.faction == self.faction or unit_wr_obj.faction in self.friendly_factions:
			continue

		if unit_wr_obj.unit_position in neighbour_points:
			close_units.append(unit_wr)


	if neighbour_points.size() == 0:
		close_units = false
	return close_units


func alert_target():
	#print("alerting")
	#print(gr(get_right_target()).name)
	gr(get_right_target()).being_attacked_by(weakref(self))

func being_attacked_by(unit_wr_obj):
	#print(name)
	#print(gr(unit_wr_obj).unit_position in get_adjecent_blocks() )
	if gr(unit_wr_obj).unit_position in get_adjecent_blocks() and primary_mele_fighter == false:
		for unit in units_pining_me:
			if gr(unit_wr_obj) == gr(unit):
				return
		is_pinned = true
		units_pining_me.append(unit_wr_obj)

func get_damaged(damage: int, penetration: int, modifier= null):
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
	if damage <= 0:
		damage = 5
	
	if modifier != null:
		if "oil" and self.unit_id == 7:
			damage = 30
	
	health -= damage
	
	# create label
	var instance = damage_label.instantiate()
	instance.get_node("Label").damage = damage
	instance.position = global_position
	root_map.get_node("on_map_texts").add_child(instance)
	
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
	
	unregister_unit_w_map()
	queue_free()
	
	if units_selected.size() == 0:
		#Input.set_custom_mouse_cursor(cursor_default)
		root_map.get_node("UI").get_node("cursors").set_default_cursor()


@rpc("authority", "call_local", "reliable")
func dig_moat(right_target_id):
	#var all_moats = root_map.get_node("moat").get_children()
	var att_object = weakref(root_map.all_units_w_unique_id[right_target_id])
	
	$attack.can_attack = false
	$attack/Timer.start()
	var instance = dig_att.instantiate()
	instance.position = global_position
	instance.target = att_object
	#instance.spawnPos = global_position
	#instance.spawnRot = rotation
	#
	root_map.get_node("projectiles").add_child(instance)


# this is needed for multiplayer sync
func register_unit_w_map():
	root_map.incremental_unit_ids += 1
	self.map_unique_id = root_map.incremental_unit_ids
	root_map.all_units_w_unique_id[self.map_unique_id] = self

func unregister_unit_w_map(target=self):
	root_map.all_units_w_unique_id.erase(target.map_unique_id)

func get_tilemap_bounds(tilemapnode: Node2D) -> Rect2i:
	var used_rect = Rect2i()
	var first = true

	for layer_node in tilemapnode.get_children():
		var layer_rect = layer_node.get_used_rect()
		
		# Initialize the rect with the first layer
		if first:
			used_rect = layer_rect
			first = false
		else:
			# Expand to include all layers
			used_rect = used_rect.expand(layer_rect.position)
			used_rect = used_rect.expand(layer_rect.end)  # `.end` is bottom-right corner

	return used_rect


func print_(my_string):
	if debugging_ == true:
		print(my_string)

func gr(weak_refer):
	if weak_refer == null:
		return null
	if weak_refer.get_ref() == null:
		return null
	else:
		return weak_refer.get_ref()


func _on_walk_timer_timeout() -> void:
	timer_started = false
	retried_times += 1
