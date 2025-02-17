extends Node2D

var target
var target_coordinate
var diretion_vector

var speed = 5

var timer_ = 1
var ttd = 6 # time to die
var ttb = 5 # time to burn fire!
var oil_pos_for_calc
var oil_pos_for_calc_old
var already_placed_bloks = []

@onready var oil_puddle = load("res://weapons/mele/oil_puddle/oil_puddle.tscn")
@onready var root_map = get_tree().root.get_node("game") # 0 je global properties autoloader :/
@onready var title_map_node = root_map.get_node("TileMap")
@onready var first_tilemap_layer = title_map_node.get_node("base_layer")
@onready var unit_position = first_tilemap_layer.local_to_map(global_position)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	target_coordinate = gr(target).global_position
	diretion_vector = target_coordinate - position
	oil_pos_for_calc = unit_position
	oil_pos_for_calc_old = oil_pos_for_calc
	var angle = global_position.angle_to_point(target_coordinate)
	rotation = angle
	$Sprite2D.self_modulate.a = 0.7


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	unit_position = first_tilemap_layer.local_to_map(global_position)
	
	if timer_ < 0:
		timer_ = 10
	timer_ -= 1
	
	global_position = global_position + (diretion_vector * (speed * delta))
	
	if unit_position != oil_pos_for_calc_old:
		ttd -= 1
		oil_pos_for_calc_old = unit_position
		
		if ttd < ttb:
			var adjecent_blocks = get_adjecent_blocks()
			
			
			for block in adjecent_blocks:
				if block not in already_placed_bloks:
					var pos_ition = first_tilemap_layer.map_to_local(block)
					spawn_puddles(pos_ition)
					already_placed_bloks.append(block)
	
	if ttd <= 0:
		queue_free()

func spawn_puddles(pos_ition):
	var instance = oil_puddle.instantiate()
	instance.position = pos_ition
	root_map.get_node("aoe_objects").add_child(instance)


func get_adjecent_blocks(circle=1):
	var center = oil_pos_for_calc
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

func gr(weak_refer):
	if weak_refer == null:
		return null
	if weak_refer.get_ref() == null:
		return null
	else:
		return weak_refer.get_ref()
