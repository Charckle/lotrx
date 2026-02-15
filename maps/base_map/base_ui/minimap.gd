extends Control

# Minimap for the RTS game.
# Shows a baked terrain background, colored dots for units, and a white
# rectangle representing the current camera viewport.  Click or drag on
# the minimap to move the camera.

var map_root
var camera: Camera2D
var tilemap_layer: TileMapLayer
@onready var minimap_bg: TextureRect = $MinimapBG

# World-space rectangle that covers the entire map (in pixels).
var map_rect: Rect2
# Pixel size of this minimap control.
var minimap_size: Vector2

var is_dragging_minimap := false
var initialized := false

# ── Lifecycle ────────────────────────────────────────────────────────────

func _ready():
	# Defer initialisation so the game root's @onready vars and _ready()
	# have finished first (children _ready before parents in Godot).
	mouse_filter = Control.MOUSE_FILTER_STOP
	_initialize.call_deferred()


func _initialize():
	map_root = get_tree().root.get_node("game")
	camera = get_parent().get_node("camera")
	tilemap_layer = map_root.first_tilemap_layer

	# Calculate full map bounds in world pixels.
	var used_rect = tilemap_layer.get_used_rect()
	var cell_size = map_root.m_cell_size  # 32
	map_rect = Rect2(
		Vector2(used_rect.position) * cell_size,
		Vector2(used_rect.size) * cell_size
	)
	minimap_size = size
	_bake_terrain(used_rect)
	initialized = true


func _process(_delta):
	if initialized:
		queue_redraw()


func _unhandled_input(event: InputEvent):
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_M:
			visible = !visible


func _draw():
	if not initialized:
		return
	_draw_units()
	_draw_viewport_rect()

# ── Terrain baking ───────────────────────────────────────────────────────

# Colour palette
const CLR_GRASS       := Color(0.30, 0.52, 0.20)
const CLR_TREES       := Color(0.12, 0.28, 0.10)
const CLR_WATER       := Color(0.15, 0.35, 0.60)
const CLR_MOAT        := Color(0.20, 0.32, 0.55)
const CLR_DIRT        := Color(0.55, 0.42, 0.25)
const CLR_WALL_TOP    := Color(0.68, 0.62, 0.52)  # crenellations
const CLR_WALL        := Color(0.50, 0.45, 0.38)   # castle walls (not_walkable)
const CLR_CASTLE_FLOOR := Color(0.45, 0.40, 0.32)  # walkable castle interior
const CLR_VOID        := Color(0.10, 0.10, 0.10)   # map edge / empty


func _bake_terrain(used_rect: Rect2i):
	var img_w := int(minimap_size.x)
	var img_h := int(minimap_size.y)
	var image := Image.create(img_w, img_h, false, Image.FORMAT_RGB8)

	# Grab the castle / wall layer (second child of the TileMap node) if it exists.
	var tilemap_node = map_root.get_node("TileMap")
	var castle_layer: TileMapLayer = null
	if tilemap_node.get_child_count() > 1:
		castle_layer = tilemap_node.get_child(1)

	# Check once whether the castle layer's tileset has the "cranullations" data.
	var has_crenellation_data := false
	if castle_layer != null and castle_layer.tile_set != null:
		var ts := castle_layer.tile_set
		for i in ts.get_custom_data_layers_count():
			if ts.get_custom_data_layer_name(i) == "cranullations":
				has_crenellation_data = true
				break

	for x in range(img_w):
		for y in range(img_h):
			# Convert minimap pixel → tile coordinate.
			var tile_x := int(used_rect.position.x + (float(x) / img_w) * used_rect.size.x)
			var tile_y := int(used_rect.position.y + (float(y) / img_h) * used_rect.size.y)
			var tile_pos := Vector2i(tile_x, tile_y)
			var color := CLR_VOID

			# ── Castle layer (overlays base) ─────────────────────────
			if castle_layer != null:
				var world_pos = tilemap_layer.map_to_local(tile_pos)
				var castle_tile_pos = castle_layer.local_to_map(world_pos)
				var ctd = castle_layer.get_cell_tile_data(castle_tile_pos)
				if ctd != null:
					if has_crenellation_data and ctd.get_custom_data("cranullations"):
						color = CLR_WALL_TOP
					elif ctd.get_custom_data("not_walkable"):
						color = CLR_WALL
					else:
						color = CLR_CASTLE_FLOOR
					image.set_pixel(x, y, color)
					continue

			# ── Base layer ───────────────────────────────────────────
			var btd = tilemap_layer.get_cell_tile_data(tile_pos)
			if btd != null:
				var terrain_name := _get_terrain_name(tilemap_layer, btd)
				match terrain_name:
					"moat":
						color = CLR_MOAT
					"dirt":
						color = CLR_DIRT
					"water":
						color = CLR_WATER
					"trees":
						color = CLR_TREES
					"grass":
						color = CLR_GRASS
					_:
						if map_root.astar_grid.is_point_solid(tile_pos):
							color = CLR_VOID
						else:
							color = CLR_GRASS

			image.set_pixel(x, y, color)

	var texture := ImageTexture.create_from_image(image)
	minimap_bg.texture = texture
	minimap_bg.size = minimap_size


func _get_terrain_name(layer: TileMapLayer, tile_data: TileData) -> String:
	var terrain_idx := tile_data.get_terrain()
	if terrain_idx < 0:
		return ""
	var ts := layer.tile_set
	if ts == null or ts.get_terrain_sets_count() == 0:
		return ""
	if terrain_idx >= ts.get_terrains_count(0):
		return ""
	return ts.get_terrain_name(0, terrain_idx)

# ── Unit dots ────────────────────────────────────────────────────────────

func _draw_units():
	for unit in map_root.get_node("units").get_children():
		if not "faction" in unit:
			continue
		var minimap_pos := _world_to_minimap(unit.global_position)

		# Faction colour from GlobalSettings.
		var fc: Dictionary = GlobalSettings.faction_colors.get(
			unit.faction, {"red": 255, "green": 255, "blue": 255}
		)
		var color := Color(fc["red"] / 255.0, fc["green"] / 255.0, fc["blue"] / 255.0)

		draw_rect(Rect2(minimap_pos - Vector2(1.5, 1.5), Vector2(3, 3)), color)

# ── Viewport rectangle ──────────────────────────────────────────────────

func _draw_viewport_rect():
	var viewport_size := get_viewport_rect().size
	# Camera anchor_mode 0 → position is the top-left corner of the view.
	var cam_pos := camera.position

	var top_left := _world_to_minimap(cam_pos)
	var bottom_right := _world_to_minimap(cam_pos + viewport_size)

	var rect := Rect2(top_left, bottom_right - top_left)
	draw_rect(rect, Color.WHITE, false, 1.5)

# ── Coordinate helpers ───────────────────────────────────────────────────

func _world_to_minimap(world_pos: Vector2) -> Vector2:
	var relative := (world_pos - map_rect.position) / map_rect.size
	return relative * minimap_size


func _minimap_to_world(minimap_pos: Vector2) -> Vector2:
	var relative := minimap_pos / minimap_size
	return map_rect.position + relative * map_rect.size

# ── Click / drag to navigate ────────────────────────────────────────────

func _gui_input(event: InputEvent):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			is_dragging_minimap = true
			_move_camera_to(event.position)
		else:
			is_dragging_minimap = false
		accept_event()

	if event is InputEventMouseMotion and is_dragging_minimap:
		_move_camera_to(event.position)
		accept_event()


func _move_camera_to(minimap_pos: Vector2):
	var viewport_size := get_viewport_rect().size
	var world_pos := _minimap_to_world(minimap_pos)
	# Centre the camera on the clicked position.
	var new_pos := world_pos - viewport_size / 2.0

	# Clamp to the map bounds (same logic as camera.gd).
	var map_start := map_rect.position
	var map_end := map_rect.end
	new_pos.x = clamp(new_pos.x, map_start.x, map_end.x - viewport_size.x)
	new_pos.y = clamp(new_pos.y, map_start.y, map_end.y - viewport_size.y)

	camera.position = new_pos
