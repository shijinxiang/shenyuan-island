shader_type canvas_item;
render_mode unshaded;
uniform float severity : hint_range(0.0, 1.0) = 0.0;
void fragment() {
	vec2 p = (UV - vec2(0.5)) * 2.0;
	float edge = smoothstep(0.35, 1.1, length(p)) * severity * 0.58;
	COLOR = vec4(0.015, 0.025, 0.02, edge);
}
