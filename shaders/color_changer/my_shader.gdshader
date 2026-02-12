shader_type canvas_item;

uniform vec4 transparentColor = vec4(1., 1., 1., 1.);
uniform bool useTransparentColor = false;

uniform vec4 replaceColor = vec4(1., 1., 1., 1.);
uniform vec4 withColor = vec4(1., 1., 1., 1.);

void fragment() {
	// Called for every pixel the material is visible on.
	COLOR = texture(TEXTURE, UV);
	
	if (COLOR == transparentColor && useTransparentColor) {
		COLOR = vec4(0., 0., 0., 0.);
	} else if (COLOR == replaceColor) {
		COLOR = withColor;
	}
}
