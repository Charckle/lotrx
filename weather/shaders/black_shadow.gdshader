shader_type canvas_item;

void fragment() {
	COLOR = vec4(vec3(0), texture(TEXTURE, UV).a);
}
