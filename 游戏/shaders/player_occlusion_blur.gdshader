shader_type canvas_item;
render_mode unshaded;

uniform float opacity : hint_range(0.0, 1.0) = 0.0;
uniform vec4 silhouette_color : source_color = vec4(0.96, 0.92, 0.78, 1.0);

void fragment() {
	vec2 step_uv = TEXTURE_PIXEL_SIZE * 2.0;
	float alpha = texture(TEXTURE, UV).a * 4.0;
	alpha += texture(TEXTURE, UV + vec2(step_uv.x, 0.0)).a * 2.0;
	alpha += texture(TEXTURE, UV - vec2(step_uv.x, 0.0)).a * 2.0;
	alpha += texture(TEXTURE, UV + vec2(0.0, step_uv.y)).a * 2.0;
	alpha += texture(TEXTURE, UV - vec2(0.0, step_uv.y)).a * 2.0;
	alpha += texture(TEXTURE, UV + step_uv).a;
	alpha += texture(TEXTURE, UV - step_uv).a;
	alpha += texture(TEXTURE, UV + vec2(step_uv.x, -step_uv.y)).a;
	alpha += texture(TEXTURE, UV + vec2(-step_uv.x, step_uv.y)).a;
	COLOR = vec4(silhouette_color.rgb, alpha * (opacity / 16.0));
}
