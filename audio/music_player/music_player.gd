extends AudioStreamPlayer2D

enum MusicType { MENU, BATTLE, SCROLL }
var current_music_type = MusicType.MENU
var menu_music = [
	preload("res://audio/music/menu/cymbalBird - Battle.mp3")
	]

var battle_music = [
	preload("res://audio/music/battle/battle-of-the-abyss-227337.mp3"),
	preload("res://audio/music/battle/cymbalBird - Forgotten Journey.mp3"),
	preload("res://audio/music/battle/epic-battle-159260.mp3"),
	preload("res://audio/music/battle/epic-battle-francisco-samuel-123469.mp3"),
	preload("res://audio/music/battle/fallout-241797.mp3"),
	preload("res://audio/music/battle/fatal-battle-219800.mp3"),
	preload("res://audio/music/battle/final-battle-trailer-music-217488.mp3"),
	preload("res://audio/music/battle/heroes-master-track-209889.mp3"),
	preload("res://audio/music/battle/his-sacrifice-orchestral-dark-epic-action-274990.mp3"),
	preload("res://audio/music/battle/medieval-epic-adventure-action-heroic-powerful-opener-intro-117935.mp3"),
	preload("res://audio/music/battle/the-legion-250653.mp3"),
	preload("res://audio/music/battle/the-tournament-280277.mp3")]

var scroll_music = [
	preload("res://audio/music/scroll/bonfire-241757.mp3"),
	preload("res://audio/music/scroll/cymbalBird - Joy.mp3"),
	preload("res://audio/music/scroll/facing-storm-250682.mp3"),
	preload("res://audio/music/scroll/marked-241780.mp3"),
	preload("res://audio/music/scroll/medieval-adventure-270566.mp3"),
	preload("res://audio/music/scroll/medieval-celtic-violin-244699.mp3"),
	preload("res://audio/music/scroll/medieval-chateau-258469.mp3"),
	preload("res://audio/music/scroll/the-landing-280923.mp3")]

var shuffled_songs = []  # Holds shuffled songs
var current_index = 0  # Tracks which song is playing

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	self.connect("finished", Callable(self, "_on_song_finished"))


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func play_menu_music():
	current_music_type = MusicType.MENU
	play_music()

func play_battle_music():
	current_music_type = MusicType.BATTLE
	play_music()

func play_music():
	if GlobalSettings.global_options["audio"]["music_active"] == true:
		start_new_shuffle()
		play_next_song()

func start_new_shuffle():
	shuffled_songs = get_correct_playlist().duplicate()
	shuffled_songs.shuffle()  # Randomize order
	current_index = 0


func get_correct_playlist():
	if current_music_type == MusicType.MENU:
		return menu_music
	elif current_music_type == MusicType.BATTLE:
		return battle_music
	else:
		return scroll_music

func play_next_song():
	if current_index >= shuffled_songs.size():
		start_new_shuffle()  # Reshuffle when all songs are played

	var next_song = shuffled_songs[current_index]
	self.stream = next_song
	self.play()

	current_index += 1  # Move to next song

func _on_song_finished():
	play_next_song() 
