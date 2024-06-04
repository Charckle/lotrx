extends Node2D

@export var state_ = 0 #  0 iddle, 1 attack, 2 defend

@export var faction = 2
@export var friendly_factions = []

@onready var root_map = get_tree().root.get_child(1) # 0 je global properties autoloader :/

# Called when the node enters the scene tree for the first time.
func _ready():
	evaluate_threat()
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
	

func evaluate_threat():
	print("evaluating_threats")
	var units_on_map = root_map.get_all_units()
	
	var my_side = 0
	var their_side = 0
	
	for unit in units_on_map:
		if unit.faction == self.faction or unit.faction in self.friendly_factions:
			my_side += unit.unit_strenght
		else:
			their_side += unit.unit_strenght
	print("my side: " + str(my_side))
	print("their side: " + str(their_side))
	set_state(my_side, their_side)

func set_state(my_side, their_side):
	if my_side > their_side:
		print("Starting Attack!")
		state_ = 1
	else:
		state_ = 2
		print("Starting Defense!")
		


func _on_timer_timeout():
	evaluate_threat()
