extends Node2D

@onready var cloud = load("uid://clnwljw6l1vvo")
@onready var rain = load("uid://bhfx5elseokmx")

@onready var map_root = get_tree().root.get_node("game")
@onready var tilemap = map_root.get_node("TileMap")
var map_x_size:int
var map_y_size:int

var cloud_create_x:int
var cloud_destroy_x:int

var cloud_create_y_min:int
var cloud_create_y_max:int


var m_cell_size:int

var wind_direction: int
var wind_speed: int

# Called when the node enters the scene tree for the first time.
func _ready():
	var map_size = tilemap.get_used_rect().size
	var m_cell_size =  self.map_root.m_cell_size
	self.map_x_size = map_size.x * m_cell_size
	self.map_y_size = map_size.y * m_cell_size
	self.m_cell_size = self.map_root.m_cell_size
	
	var cloud_create_position = tilemap.get_used_rect().position * Vector2i(m_cell_size, m_cell_size)
	self.cloud_create_x = cloud_create_position.x - 400
	self.cloud_create_y_min = cloud_create_position.y
	self.cloud_create_y_max = cloud_create_position.y + self.map_y_size
	
	self.cloud_destroy_x = cloud_create_position.x + self.map_x_size + 400
	
	self.wind_direction = random_sign()
	self.wind_speed = randi() % 3
	
	if GlobalSettings.global_options["video"]["weather_show"] == true:
		print("kurac2")
		if multiplayer.is_server():
			print("kurac")
			var weather_ = self.decide_weather()
			var wind_direction = random_sign()
			
			set_weather.rpc(weather_, wind_direction)
			
			

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


func create_cloud(all_map=false):
	var instance = cloud.instantiate()
	var start_y = randf_range(self.cloud_create_y_min, self.cloud_create_y_max)
	var x_spawn_coord = self.cloud_create_x
	
	if all_map == true:
		x_spawn_coord = randf_range(self.cloud_create_x, self.cloud_destroy_x)
	
	instance.position =  Vector2(x_spawn_coord, start_y)
	instance.position_x_todestroy_itself = self.cloud_destroy_x
	
	map_root.get_node("weather_objects").add_child(instance)

func create_rain():
	var instance = rain.instantiate()
	var start_x = randf_range(self.cloud_create_x, self.cloud_destroy_x)
	var start_y = randf_range(self.cloud_create_y_min, self.cloud_create_y_max)
	instance.position =  Vector2(start_x, start_y)
	instance.wind_direction = self.wind_direction
	instance.wind_speed = self.wind_speed
	
	map_root.get_node("weather_objects").add_child(instance)

func _on_timer_timeout():
	for x in range(1):
		create_cloud()

func _on_rain_timer_timeout():
	for x in range(60):
		create_rain()


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
	print(is_weather)
	if is_weather == "rain":
		$rain_Timer.start()
	if is_weather == "clouds":
		for x in range(15):
			self.create_cloud(true)
		$cloud_Timer.start()
