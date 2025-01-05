extends Control

@onready var root_map = get_tree().root.get_child(1) # 0 je global properties autoloader :/
@onready var progress_bar = $ProgressBar
@onready var scoreboard_panel = get_parent().get_node("ScoreboardPanel")

var faction = GlobalSettings.my_faction
var friendly_factions = GlobalSettings.friendly_factions

# Called when the node enters the scene tree for the first time.
func _ready():
	set_progressbar(true)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


func _on_timer_timeout():
	set_progressbar()


func set_progressbar(save_units_score=false):
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

	var units_value =  (my_side / all_units) * 100
	progress_bar.value = units_value
	
	if units_value == 100:
		set_endgame_parameterd()
		
	if units_value == 0:
		set_endgame_parameterd()
	
	if save_units_score == true:
		GlobalSettings.game_stats["game_unit_count_start"] = self.scoreboard_panel.calc_score(units_on_map)


func set_endgame_parameterd():
	self.scoreboard_panel.display_panel()
