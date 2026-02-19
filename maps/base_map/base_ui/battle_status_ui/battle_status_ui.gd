extends Control

@onready var root_map = get_tree().root.get_node("game") # 0 je global properties autoloader :/
@onready var progress_bar = $ProgressBar
@onready var scoreboard_panel = get_parent().get_node("ScoreboardPanel")

var faction = GlobalSettings.my_faction
var friendly_factions = GlobalSettings.friendly_factions

# Hover areas for tooltips (children of the progress bar)
var my_side_hover: Control
var their_side_hover: Control

# Cached StyleBoxFlat resources so we don't recreate every tick
var fill_style: StyleBoxFlat
var bg_style: StyleBoxFlat

# Default colors (blue for player, red for enemy)
var default_fill_color = Color(0.100973, 0, 0.794712, 1)
var default_bg_color = Color(0.732528, 0.0362809, 0.0901984, 1)

# Track current colors to avoid unnecessary updates
var _current_fill_color: Color = Color.BLACK
var _current_bg_color: Color = Color.BLACK


# Called when the node enters the scene tree for the first time.
func _ready():
	# Create reusable style boxes
	fill_style = StyleBoxFlat.new()
	fill_style.border_width_left = 2
	fill_style.border_width_top = 2
	fill_style.border_width_bottom = 2
	fill_style.border_color = Color(0.038, 0.038, 0.038)
	fill_style.corner_radius_top_left = 5
	fill_style.corner_radius_bottom_left = 5

	bg_style = StyleBoxFlat.new()
	bg_style.border_width_left = 2
	bg_style.border_width_top = 2
	bg_style.border_width_right = 2
	bg_style.border_width_bottom = 2
	bg_style.border_color = Color(0.043, 0.043, 0.043)
	bg_style.corner_radius_top_left = 5
	bg_style.corner_radius_top_right = 5
	bg_style.corner_radius_bottom_right = 5
	bg_style.corner_radius_bottom_left = 5

	progress_bar.add_theme_stylebox_override("fill", fill_style)
	progress_bar.add_theme_stylebox_override("background", bg_style)

	# Create transparent hover areas as children of the progress bar
	my_side_hover = Control.new()
	my_side_hover.mouse_filter = Control.MOUSE_FILTER_STOP
	my_side_hover.mouse_default_cursor_shape = Control.CURSOR_ARROW

	their_side_hover = Control.new()
	their_side_hover.mouse_filter = Control.MOUSE_FILTER_STOP
	their_side_hover.mouse_default_cursor_shape = Control.CURSOR_ARROW

	progress_bar.add_child(my_side_hover)
	progress_bar.add_child(their_side_hover)

	set_progressbar(true)


func _on_timer_timeout():
	set_progressbar()


func _is_door_unit(unit) -> bool:
	var uid = unit.get("unit_id")
	return unit.get("is_small_door") != null or (uid != null and uid in [500, 501, 502])

func set_progressbar(save_units_score=false):
	var units_on_map = root_map.get_all_units()

	var my_side = 0
	var their_side = 0
	var factions_on_map: Dictionary = {} # faction_id -> true

	for unit in units_on_map:
		if _is_door_unit(unit):
			continue
		factions_on_map[unit.faction] = true
		if unit.faction == self.faction or unit.faction in self.friendly_factions:
			my_side += unit.unit_strenght
		else:
			their_side += unit.unit_strenght

	var all_units: float = my_side + their_side
	if all_units == 0:
		progress_bar.value = 50
		return

	var units_value = (my_side / all_units) * 100
	progress_bar.value = units_value

	# Update bar colors based on faction count
	_update_bar_colors(factions_on_map)

	# Update hover tooltip areas
	_update_hover_areas(units_value, factions_on_map)

	if units_value == 100:
		set_endgame_parameterd()

	if units_value == 0:
		set_endgame_parameterd()

	if save_units_score == true:
		GlobalSettings.game_stats["game_unit_count_start"] = self.scoreboard_panel.calc_score(units_on_map)


func _update_bar_colors(factions_on_map: Dictionary):
	var faction_ids = factions_on_map.keys()
	var new_fill_color: Color
	var new_bg_color: Color

	if faction_ids.size() == 2:
		# Exactly 2 factions: use their actual faction colors
		var my_faction_id = self.faction
		var their_faction_id = -1
		for fid in faction_ids:
			if fid != my_faction_id and fid not in self.friendly_factions:
				their_faction_id = fid
				break

		if their_faction_id == -1:
			# Could not determine enemy faction, use defaults
			new_fill_color = default_fill_color
			new_bg_color = default_bg_color
		else:
			new_fill_color = _get_faction_color(my_faction_id)
			new_bg_color = _get_faction_color(their_faction_id)
	else:
		# More than 2 factions (or fewer): use default blue/red
		new_fill_color = default_fill_color
		new_bg_color = default_bg_color

	# Only update styles if colors changed
	if new_fill_color != _current_fill_color or new_bg_color != _current_bg_color:
		_current_fill_color = new_fill_color
		_current_bg_color = new_bg_color
		fill_style.bg_color = new_fill_color
		bg_style.bg_color = new_bg_color


func _get_faction_color(faction_id: int) -> Color:
	if GlobalSettings.faction_colors.has(faction_id):
		var c = GlobalSettings.faction_colors[faction_id]
		return Color(c["red"] / 255.0, c["green"] / 255.0, c["blue"] / 255.0)
	return Color.WHITE


func _update_hover_areas(progress_value: float, factions_on_map: Dictionary):
	var bar_width = progress_bar.size.x
	var bar_height = progress_bar.size.y
	var fill_width = (progress_value / 100.0) * bar_width

	# Left side = my faction(s)
	my_side_hover.position = Vector2(0, 0)
	my_side_hover.size = Vector2(fill_width, bar_height)

	# Right side = enemy faction(s)
	their_side_hover.position = Vector2(fill_width, 0)
	their_side_hover.size = Vector2(bar_width - fill_width, bar_height)

	# Build tooltip text for each side
	my_side_hover.tooltip_text = _build_side_tooltip(true, factions_on_map)
	their_side_hover.tooltip_text = _build_side_tooltip(false, factions_on_map)


func _build_side_tooltip(is_my_side: bool, factions_on_map: Dictionary) -> String:
	var side_faction_ids = []
	for fid in factions_on_map.keys():
		if is_my_side:
			if fid == self.faction or fid in self.friendly_factions:
				side_faction_ids.append(fid)
		else:
			if fid != self.faction and fid not in self.friendly_factions:
				side_faction_ids.append(fid)

	var lines = []
	var players = GlobalSettings.multiplayer_data.get("players", {})

	for fid in side_faction_ids:
		# Find player names assigned to this faction
		var player_names = []
		for pid in players:
			var p = players[pid]
			if p.get("faction", -1) == fid:
				player_names.append(p.get("name", "Unknown"))

		if player_names.size() > 0:
			for pname in player_names:
				lines.append(pname + " (Faction " + str(fid) + ")")
		else:
			# Single-player or no player data: just show faction
			lines.append("Faction " + str(fid))

	return "\n".join(lines)


func set_endgame_parameterd():
	self.scoreboard_panel.display_panel()
