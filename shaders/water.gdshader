// Water shader: subtle UV scroll + sine wave displacement to give static
// Kenney water tiles a sense of motion. Applied as a `ShaderMaterial` on the
// Water TileMapLayer.
shader_type canvas_item;

uniform float scroll_speed_x : hint_range(-0.2, 0.2) = 0.015;
uniform float scroll_speed_y : hint_range(-0.2, 0.2) = 0.008;
uniform float wave_amp : hint_range(0.0, 0.05) = 0.006;
uniform float wave_freq : hint_range(0.0, 32.0) = 8.0;
uniform vec3 tint : source_color = vec3(0.95, 1.0, 1.05);

void fragment() {
	vec2 uv = UV;
	uv.x += sin((UV.y + TIME * scroll_speed_y) * wave_freq) * wave_amp;
	uv.x += TIME * scroll_speed_x;
	uv.y += TIME * scroll_speed_y;
	uv = fract(uv);
	vec4 c = texture(TEXTURE, uv);
	c.rgb *= tint;
	COLOR = c;
}
