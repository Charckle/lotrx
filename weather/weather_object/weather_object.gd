extends Node2D

@onready var cloud = load("uid://clnwljw6l1vvo")

@onready var map_root = get_tree().root.get_node("game")
@onready var title_map_node = map_root.get_node("TileMap")
@onready var first_tilemap_layer = title_map_node.get_node("base_layer")

var map_x_size:int
var map_y_size:int

var cloud_create_x:int
var cloud_destroy_x:int

var cloud_create_y_min:int
var cloud_create_y_max:int


var m_cell_size:int

var wind_direction: int
var wind_speed: int

# --- Rain MultiMesh pool ---
const RAIN_MAX_DROPS := 200
var rain_positions := PackedVector2Array()
var rain_speeds := PackedFloat32Array()
var rain_lifetimes := PackedFloat32Array()
var rain_active_count := 0
var rain_direction := Vector2.ZERO
var rain_multi_mesh_instance: MultiMeshInstance2D
var rain_is_active := false
var rain_was_active := false  # remember rain state so we can restore it
# Accumulator for spawning rain in batches via _process instead of a timer
var rain_spawn_accumulator := 0.0
const RAIN_SPAWN_INTERVAL := 0.5
const RAIN_DROPS_PER_BATCH := 60

var _weather_was_visible := true  # tracks previous frame's setting for edge detection
var _cloud_timer_was_running := false  # remember whether clouds were spawning

# Called when the node enters the scene tree for the first time.
func _ready():
	var map_rectangle = first_tilemap_layer.get_used_rect()
	var map_size = map_rectangle.size # the first tilemaplayer should be the biggest

	var m_cell_size =  self.map_root.m_cell_size
	self.map_x_size = map_size.x * m_cell_size
	self.map_y_size = map_size.y * m_cell_size
	self.m_cell_size = self.map_root.m_cell_size
	
	var cloud_create_position = map_rectangle.position * Vector2i(m_cell_size, m_cell_size)
	self.cloud_create_x = cloud_create_position.x - 400
	self.cloud_create_y_min = cloud_create_position.y
	self.cloud_create_y_max = cloud_create_position.y + self.map_y_size
	
	self.cloud_destroy_x = cloud_create_position.x + self.map_x_size + 400
	
	self.wind_direction = random_sign()
	self.wind_speed = randi() % 3
	
	_setup_rain_multimesh()
	
	if GlobalSettings.global_options["video"]["weather_show"] == true:
		if multiplayer.is_server():
			var weather_ = self.decide_weather()
			var wind_direction = random_sign()
			
			set_weather.rpc(weather_, wind_direction)


func _setup_rain_multimesh():
	# Pre-allocate arrays for rain drop pool
	rain_positions.resize(RAIN_MAX_DROPS)
	rain_speeds.resize(RAIN_MAX_DROPS)
	rain_lifetimes.resize(RAIN_MAX_DROPS)
	
	# Create the MultiMesh resource
	var multi_mesh = MultiMesh.new()
	multi_mesh.transform_format = MultiMesh.TRANSFORM_2D
	multi_mesh.instance_count = RAIN_MAX_DROPS
	multi_mesh.visible_instance_count = 0
	
	# Create a QuadMesh sized to match the rain sprite
	var rain_texture = load("uid://k180si3b10oq") as Texture2D
	var tex_size = rain_texture.get_size()
	var quad = QuadMesh.new()
	quad.size = tex_size
	
	multi_mesh.mesh = quad
	
	# Create the MultiMeshInstance2D and set the texture directly (2D rendering)
	rain_multi_mesh_instance = MultiMeshInstance2D.new()
	rain_multi_mesh_instance.multimesh = multi_mesh
	rain_multi_mesh_instance.texture = rain_texture
	rain_multi_mesh_instance.z_index = 500
	map_root.get_node("weather_objects").add_child(rain_multi_mesh_instance)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	# Live-toggle weather visibility from settings.
	var weather_visible: bool = GlobalSettings.global_options["video"]["weather_show"]
	var weather_objects_node = map_root.get_node("weather_objects")

	# ── Transition: visible → hidden  (clean up everything) ──────────
	if not weather_visible and _weather_was_visible:
		# Remember whether clouds/rain were active so we can restore later.
		_cloud_timer_was_running = not $cloud_Timer.is_stopped()
		rain_was_active = rain_is_active

		# Stop spawning.
		if _cloud_timer_was_running:
			$cloud_Timer.stop()

		# Free every existing cloud.
		for child in weather_objects_node.get_children():
			if child != rain_multi_mesh_instance:
				child.queue_free()

		# Clear rain pool.
		rain_active_count = 0
		rain_multi_mesh_instance.multimesh.visible_instance_count = 0

		weather_objects_node.visible = false

	# ── Transition: hidden → visible  (restore weather) ──────────────
	if weather_visible and not _weather_was_visible:
		weather_objects_node.visible = true

		# Restart clouds if they were running before.
		if _cloud_timer_was_running:
			for x in range(15):
				create_cloud(true)
			$cloud_Timer.start()

		# Restart rain if it was running before.
		if rain_was_active:
			rain_is_active = true
			rain_spawn_accumulator = RAIN_SPAWN_INTERVAL

	_weather_was_visible = weather_visible

	if not weather_visible:
		return

	if rain_is_active:
		_process_rain(delta)


func _process_rain(delta):
	var mm = rain_multi_mesh_instance.multimesh
	
	# Spawn new drops on interval
	rain_spawn_accumulator += delta
	while rain_spawn_accumulator >= RAIN_SPAWN_INTERVAL:
		rain_spawn_accumulator -= RAIN_SPAWN_INTERVAL
		for j in range(RAIN_DROPS_PER_BATCH):
			_spawn_rain_drop()
	
	# Update active drops
	var i := 0
	while i < rain_active_count:
		rain_lifetimes[i] -= delta
		if rain_lifetimes[i] <= 0.0:
			# Swap with last active drop and shrink pool
			rain_active_count -= 1
			rain_positions[i] = rain_positions[rain_active_count]
			rain_speeds[i] = rain_speeds[rain_active_count]
			rain_lifetimes[i] = rain_lifetimes[rain_active_count]
			continue
		rain_positions[i] += rain_direction * rain_speeds[i] * delta
		mm.set_instance_transform_2d(i, Transform2D(0.0, rain_positions[i]))
		i += 1
	
	mm.visible_instance_count = rain_active_count


func _spawn_rain_drop():
	if rain_active_count >= RAIN_MAX_DROPS:
		return
	var idx = rain_active_count
	rain_positions[idx] = Vector2(
		randf_range(cloud_create_x, cloud_destroy_x),
		randf_range(cloud_create_y_min, cloud_create_y_max)
	)
	rain_speeds[idx] = 300.0 + randf_range(-30.0, 30.0)
	rain_lifetimes[idx] = 1.5
	rain_active_count += 1


func create_cloud(all_map=false):
	var instance = cloud.instantiate()
	var start_y = randf_range(self.cloud_create_y_min, self.cloud_create_y_max)
	var x_spawn_coord = self.cloud_create_x
	
	if all_map == true:
		x_spawn_coord = randf_range(self.cloud_create_x, self.cloud_destroy_x)
	
	instance.position =  Vector2(x_spawn_coord, start_y)
	instance.position_x_todestroy_itself = self.cloud_destroy_x
	
	map_root.get_node("weather_objects").add_child(instance)


func _on_timer_timeout():
	for x in range(1):
		create_cloud()

func random_sign() -> int:
	var random_f = randf()

	return -1 if random_f < 0.5 else 1

func decide_weather():
	var weather = [
		"sunny",
		"rain",
		"clouds"
	]
	
	var is_weather = weather[randi() % weather.size()]
	
	return is_weather

@rpc("any_peer", "call_local", "reliable")
func set_weather(is_weather, wind_direction):
	self.wind_direction = wind_direction
	
	if is_weather == "rain":
		# Compute the rain direction based on wind
		var wind_speed_direction = self.wind_speed * self.wind_direction
		rain_direction = Vector2(wind_speed_direction, 1).normalized()
		rain_is_active = true
		rain_spawn_accumulator = RAIN_SPAWN_INTERVAL  # Spawn first batch immediately
	if is_weather == "clouds":
		for x in range(15):
			self.create_cloud(true)
		$cloud_Timer.start()
