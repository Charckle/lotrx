extends Sprite2D

@onready var parent_n = get_parent()

var new_red: int
var new_green: int
var new_blue: int

var my_shader: Shader
@onready var shaded_sprite = preload("res://shaders/color_changer/my_shader.gdshader")

func _ready():
	var my_faction = parent_n.faction

	new_red = GlobalSettings.faction_colors[my_faction]["red"]
	new_green = GlobalSettings.faction_colors[my_faction]["green"]
	new_blue = GlobalSettings.faction_colors[my_faction]["blue"]
	#print(new_blue)
	
	my_shader = shaded_sprite
	# zato da ko riše riše piksle in ne razmaže slike (če razmaže se v gradientih zgubijo prave barve ki jih lahko primerjamo)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	
	# materiali bi verjetno lahko tudi bli v naprej pripravljeni (za šparat ne samo da bi šparalo spomin ma mogoče bi tudi izrisovalo boljše - no idea if it's true though)
	material = ShaderMaterial.new()
	material.shader = my_shader
	
	material.set_shader_parameter("transparentColor", color_from_rgb(255, 0, 255))
	material.set_shader_parameter("useTransparentColor", true)
	
	material.set_shader_parameter("replaceColor", color_from_rgb(255, 255, 0))
	material.set_shader_parameter("withColor", color_from_rgb(new_red, new_green, new_blue))

func color_from_rgb(r: int, g: int, b: int) -> Vector4:
	return Vector4(r / 255.0, g / 255.0, b / 255.0, 1.0)
