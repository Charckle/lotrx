extends Node2D

var unit_type = 1
@export var faction = 1

@export var priority = 1 # the higher, the more urgent

# Called when the node enters the scene tree for the first time.
func _ready():
	#print(get_unit_(unit_type))
	set_unit_image()
	if GlobalSettings.global_options["gameplay"]["show_ai_POI"] == false:
		self.visible = false



# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


func set_unit_image():
	pass

func get_unit_(unit_type_):
	var units_ = {
		0: "peasant",
		1: "archer",
		2: "crossbow",
		3: "knight",
		4: "maceman",
		5: "pikeman",
		6: "swordsman",
		7: "ram"
	}
	
	return units_[unit_type_]
