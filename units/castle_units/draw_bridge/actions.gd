extends Node2D

var door_opened = 0
var all_sprite_positions = []
var got_all_sprites_pos = false

@onready var parent_n = get_parent()
@onready var root_map = get_tree().root.get_node("game") 
@onready var base_sprite = parent_n.get_node("spriteNode/base_sprite")
@onready var open_sprite = parent_n.get_node("sprites_open")
@onready var open_door = parent_n.get_node("open_door")
@onready var close_door = parent_n.get_node("close_door")

@onready var title_map_node = root_map.get_node("TileMap")
@onready var first_tilemap_layer = title_map_node.get_node("base_layer")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	parent_n.unit_id = 502


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	#print(open_sprite.visible)
	if got_all_sprites_pos == false:
		get_all_bridge_spritecells()
		got_all_sprites_pos = true

@rpc("any_peer", "call_local", "reliable")
func set_state(open_: int):
	if open_ == 1:
		close_door.stop()
		open_door.start()
	else:
		if check_if_units_on_bridge() == false:
			open_door.stop()
			close_door.start()

func get_all_sprites_coord_NOT_IN_USE():
	for sprite in open_sprite.get_children():
		all_sprite_positions.append(first_tilemap_layer.local_to_map(sprite.global_position))

func _on_open_door_timeout() -> void:
	base_sprite.visible = false
	open_sprite.visible = true
	
	
	parent_n.astar_grid.set_point_solid(parent_n.unit_position, false)
	door_opened = 1
	make_moat_unwalkable()

func make_moat_unwalkable(yes = true):
	for moat_obj in root_map.get_node("moat").get_node("moat_obj").get_children():
		if moat_obj.unit_position in all_sprite_positions:
			moat_obj.make_walkable(yes)

func _on_close_door_timeout() -> void:
	base_sprite.visible = true
	open_sprite.visible = false
	parent_n.astar_grid.set_point_solid(parent_n.unit_position)
	door_opened = 0
	make_moat_unwalkable(false)

func check_if_units_on_bridge():
	for unit_obj in root_map.get_node("units").get_children():
		if unit_obj.unit_id != parent_n.unit_id and unit_obj.unit_position in all_sprite_positions:

			return true
	
	return false

func get_all_bridge_spritecells():
	for bridge_piece in root_map.get_node("units").get_children():
		var siege_id = bridge_piece.get("siege_id")
		
		if siege_id == parent_n.siege_id:
			for sprite in bridge_piece.get_node("sprites_open").get_children():
				all_sprite_positions.append(first_tilemap_layer.local_to_map(sprite.global_position))
			
