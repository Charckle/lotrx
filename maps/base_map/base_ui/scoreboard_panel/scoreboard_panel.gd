extends Control

@onready var root_map = get_tree().root.get_node("game")

@onready var player_1 = $Panel/GridContainer/player_1
@onready var player_2 = $Panel/GridContainer/player_2

var my_faction = GlobalSettings.my_faction
var friendly_factions = GlobalSettings.friendly_factions

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func calc_score(units_on_map=null):
	if units_on_map == null:
		units_on_map = root_map.get_all_units()
	
	var my_units = {
		"total": 0}
	var enemy_units = my_units.duplicate(true)
	
	for unit in units_on_map:
		if unit.faction == self.my_faction or unit.faction in self.friendly_factions:
			var unit_id = unit.unit_id
			if unit.unit_id not in my_units:
				my_units[unit_id] = 0
			my_units[unit_id] += 1
			my_units["total"] += 1

		else:
			var unit_id = unit.unit_id
			if unit.unit_id not in enemy_units:
				enemy_units[unit_id] = 0
			enemy_units[unit_id] += 1
			enemy_units["total"] += 1
	
	var score = {
		"my_units": my_units,
		"enemy_units": enemy_units
	}
	
	return score
	
func display_panel():
	GlobalSettings.game_stats["game_unit_count_current"] = self.calc_score()
	self.fill_panel_numbers()
	
	# Only show "Back to Lobby" if we're in a multiplayer game
	var lobby = get_tree().root.get_node_or_null("MultiplayerLobby")
	$Panel/ButtonContainer/lobby_button.visible = (lobby != null)
	
	self.visible = true

func fill_panel_numbers():
	var game_unit_count_start = GlobalSettings.game_stats["game_unit_count_start"]
	var game_unit_count_current = GlobalSettings.game_stats["game_unit_count_current"]
	
	self.fill_player_table(self.player_1, game_unit_count_current["my_units"], game_unit_count_start["my_units"])
	self.fill_player_table(self.player_2, game_unit_count_current["enemy_units"], game_unit_count_start["enemy_units"])

func fill_player_table(player, current_score, start_score):
	player.get_node("peasants_label").text = str(current_score.get(0, 0)) + "/" + str(start_score.get(0, 0))
	player.get_node("macemen_label").text = str(current_score.get(4, 0)) + "/" + str(start_score.get(4, 0))
	player.get_node("pikemen_label").text = str(current_score.get(5, 0)) + "/" + str(start_score.get(5, 0))
	player.get_node("swordsmen_label").text = str(current_score.get(6, 0)) + "/" + str(start_score.get(6, 0))
	player.get_node("archers_label").text = str(current_score.get(1, 0)) + "/" + str(start_score.get(1, 0))
	player.get_node("crossbowmen_label").text = str(current_score.get(2, 0)) + "/" + str(start_score.get(2, 0))
	player.get_node("knights_label").text = str(current_score.get(3, 0)) + "/" + str(start_score.get(3, 0))
	player.get_node("total_label").text = str(current_score["total"]) + "/" + str(start_score["total"])

func _on_lobby_button_pressed():
	root_map.exit_to_lobby()

func _on_main_menu_button_pressed():
	root_map.exit_to_main_menu()
