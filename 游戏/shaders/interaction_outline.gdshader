shader_type canvas_item;
render_mode unshaded;

uniform float edge_pixels = 2.0;
uniform float edge_opacity = 0.65;
uniform sampler2D player_mask : filter_linear;

void fragment() {
	vec2 step_uv = TEXTURE_PIXEL_SIZE * edge_pixels;
	float center = texture(TEXTURE, UV).a;
	float expanded = center;
	expanded = max(expanded, texture(TEXTURE, UV + vec2(step_uv.x, 0.0)).a);
	expanded = max(expanded, texture(TEXTURE, UV - vec2(step_uv.x, 0.0)).a);
	expanded = max(expanded, texture(TEXTURE, UV + vec2(0.0, step_uv.y)).a);
	expanded = max(expanded, texture(TEXTURE, UV - vec2(0.0, step_uv.y)).a);
	expanded = max(expanded, texture(TEXTURE, UV + step_uv).a);
	expanded = max(expanded, texture(TEXTURE, UV - step_uv).a);
	expanded = max(expanded, texture(TEXTURE, UV + vec2(step_uv.x, -step_uv.y)).a);
	expanded = max(expanded, texture(TEXTURE, UV + vec2(-step_uv.x, step_uv.y)).a);
	float character = texture(player_mask, UV).a;
	COLOR = vec4(vec3(1.0), max(0.0, expanded - center) * edge_opacity * (1.0 - character));
}
