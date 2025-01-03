extends Control

@onready var root_map = get_tree().root.get_child(1) # 0 je global properties autoloader :/
@onready var progress_bar = $ProgressBar

var faction = GlobalSettings.my_faction
@export var friendly_factions = []

# Called when the node enters the scene tree for the first time.
func _ready():
	set_progressbar()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


func _on_timer_timeout():
	set_progressbar()


func set_progressbar():
	var units_on_map = root_map.get_all_units()
	
	var my_side = 0
	var their_side = 0
	
	for unit in units_on_map:
		if unit.faction == self.faction or unit.faction in self.friendly_factions:
			my_side += unit.unit_strenght
		else:
			their_side += unit.unit_strenght
	#print("my side: " + str(my_side))
	#print("their side: " + str(their_side))
	var all_units: float = my_side + their_side

	progress_bar.value = (my_side / all_units) * 100
