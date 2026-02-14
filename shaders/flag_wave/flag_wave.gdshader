shader_type canvas_item;

// --- Wave uniforms ---
uniform float wave_amplitude : hint_range(0.0, 0.1) = 0.03;
uniform float wave_frequency : hint_range(0.0, 30.0) = 10.0;
uniform float wave_speed : hint_range(0.0, 10.0) = 3.0;

// --- Color replacement uniforms (same as my_shader) ---
uniform vec4 transparentColor = vec4(1., 1., 1., 1.);
uniform bool useTransparentColor = false;
uniform vec4 replaceColor = vec4(1., 1., 1., 1.);
uniform vec4 withColor = vec4(1., 1., 1., 1.);

void fragment() {
	vec2 uv = UV;

	// Sine wave that increases from left (pole) to right (free end).
	// uv.x acts as a mask: pixels near x=0 (pole) barely move,
	// pixels near x=1 (free edge) move the most.
	float wave = sin(uv.x * wave_frequency + TIME * wave_speed) * wave_amplitude * uv.x;
	uv.y += wave;

	COLOR = texture(TEXTURE, uv);

	// Existing color replacement logic
	if (COLOR == transparentColor && useTransparentColor) {
		COLOR = vec4(0., 0., 0., 0.);
	} else if (COLOR == replaceColor) {
		COLOR = withColor;
	}
}
