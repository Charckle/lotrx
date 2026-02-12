extends Panel


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	populate_audio_data()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func populate_audio_data():
	var vbox_c = $ScrollContainer/VBoxContainer
	
	var audio_data = [
		"Menu Music",
		"- \"Battle\" by Artist: cymbalBird, Source: (Free Music Archive), License: CC BY",
		"Battle Music",
		"- \"Forgotten Journey\" by Artist: cymbalBird, Source: (Free Music Archive), License: CC BY",
		"- \"Battle Of The Abyss\" by Artist: Psychronic, Source: pixabay.com, License: Pixabay Content License",
		"- \"Epic\" by Artist: SigmaMusicArt, Source: pixabay.com, License: Pixabay Content License",
		"- \"Epic Battle\" by Artist: PaulYudin, Source: pixabay.com, License: Pixabay Content License",
		"- \"Epic Battle\" by Artist: Francis_Samuel, Source: pixabay.com, License: Pixabay Content License",
		"- \"Fallout\" by Artist: nakaradaalexander, Source: pixabay.com, License: Pixabay Content License",
		"- \"Fatal Battle\" by Artist: Ihor_Koliako, Source: pixabay.com, License: Pixabay Content License",
		"- \"FINAL BATTLE (TRAILER MUSIC)\" by Artist: Ihor_Koliako, Source: pixabay.com, License: Pixabay Content License",
		"- \"Heroes Master Track\" by Artist: Billy_Ziogas, Source: pixabay.com, License: Pixabay Content License",
		"- \"His Sacrifice (orchestral dark epic action)\" by Artist: Kulakovka, Source: pixabay.com, License: Pixabay Content License",
		"- \"Medieval Epic - Adventure Action Heroic Powerful Opener Intro\" by Artist: SoundGalleryBy, Source: pixabay.com, License: Pixabay Content License",
		"- \"The Legion\" by Artist: nakaradaalexander, Source: pixabay.com, License: Pixabay Content License",
		"- \"The Tournament\" by Artist: Emmraan, Source: pixabay.com, License: Pixabay Content License",
		"Scroll Music",
		"- \"Joy\" by Artist: cymbalBird, Source: (Free Music Archive), License: CC BY",
		"- \"Bonfire\" by Artist: nakaradaalexander, Source: pixabay.com, License: Pixabay Content License",
		"- \"Facing Storm\" by Artist: nakaradaalexander, Source: pixabay.com, License: Pixabay Content License",
		"- \"Marked\" by Artist: nakaradaalexander, Source: pixabay.com, License: Pixabay Content License",
		"- \"Medieval Chateau\" by Artist: nakaradaalexander, Source: pixabay.com, License: Pixabay Content License",
		"- \"Medieval Adventure\" by Artist: Emmraan, Source: pixabay.com, License: Pixabay Content License",
		"- \"Medieval Celtic Violin\" by Artist: Royalty-free-music, Source: pixabay.com, License: Pixabay Content License",
		"- \"The Landing\" by Artist: PabloGaez, Source: pixabay.com, License: Pixabay Content License",
		"Sound effects",
		"- \"click\" by Artist: R-0-T-0, Source: pixabay.com, License: Pixabay Content License"
		
	]
	
	var label = Label.new()
	label.text = "Audio credits"
	#label.alignment = HORIZONTAL_ALIGNMENT_LEFT
	vbox_c.add_child(label)
	
	for song in audio_data:
		label = Label.new()
		label.text = song
		label.add_theme_font_size_override("font_size", 10)
		#label.alignment = HORIZONTAL_ALIGNMENT_LEFT
		vbox_c.add_child(label)
