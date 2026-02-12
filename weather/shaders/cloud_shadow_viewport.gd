extends SubViewport

func _ready():
	size = get_parent().get_viewport_rect().size
	transparent_bg = true
