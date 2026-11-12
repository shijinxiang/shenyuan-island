// Rain streaks (Lite). Positions are computed here from the element index, so the mesh is
// a static list of quads and the CPU does no per-drop work.
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, world_vertex_coords, shadows_disabled, diffuse_lambert_wrap, specular_disabled;

#include "res://addons/nimblux_fx/shaders/nimblux_common.gdshaderinc"

uniform int seed = 1;
uniform vec3 area_center;
uniform vec3 area_size = vec3(30.0, 16.0, 30.0);
uniform vec3 offset;
uniform vec3 velocity = vec3(0.0, -12.0, 0.0);
uniform float amount : hint_range(0.0, 1.0) = 1.0;
uniform float size = 0.012;
uniform float size_variation = 0.4;
uniform float speed_variation = 0.25;
uniform float stretch = 0.035;
uniform float time = 0.0;
uniform vec4 color : source_color = vec4(0.8, 0.85, 0.95, 0.35);
uniform float emission = 0.3;
uniform float near_fade = 0.6;
uniform float edge_fade = 0.3;
uniform float pixel_angle = 0.002;


uniform sampler2D rain_ground : filter_linear, repeat_disable;
uniform sampler2D rain_local_ground : filter_linear, repeat_disable;
float rain_height(vec2 p) {
 float h=texture(rain_ground,(p+vec2(400.))/800.).r;
 if(p.x>88. && p.x<216. && p.y>72. && p.y<200.) h=texture(rain_local_ground,(p-vec2(88.,72.))/128.).r;
 return max(h,0.);
}

#include "res://shaders/rain_surface_height.gdshaderinc"

varying vec2 v_uv;
varying float v_alpha;
varying float v_tone;

void vertex() {
	uint idx = uint(VERTEX.x + 0.5);
	vec4 r = nimblux_rand4(idx, uint(seed), 0u);
	vec4 r2 = nimblux_rand4(idx, uint(seed), 1u);
	vec3 cam = INV_VIEW_MATRIX[3].xyz;
	v_uv = UV;
	v_alpha = 0.0;
	v_tone = 0.85 + 0.3 * r2.w;
	VERTEX = area_center;
	if (r.w < amount) {
		float sp = 1.0 + (r2.x * 2.0 - 1.0) * speed_variation;
		vec3 lo = area_center - area_size * 0.5;
		vec3 p = nimblux_wrap(r.xyz * area_size + offset * sp, lo, area_size);
		vec3 vel = velocity * sp;
		float surface_height=rain_surface_height(p.xz);

		vec3 rel = (p - area_center) / (area_size * 0.5);
		float fade = 1.0 - smoothstep(1.0 - edge_fade, 1.0, length(rel.xz));
		fade *= 1.0 - smoothstep(1.0 - edge_fade * 0.6, 1.0, rel.y);
		fade *= smoothstep(-1.0, -1.0 + edge_fade * 0.3, rel.y);

		vec3 to_cam = cam - p;
		float dist = max(length(to_cam), 0.001);
		vec3 n = to_cam / dist;
		fade *= smoothstep(near_fade, near_fade * 2.5, dist);
		float sz = size * (1.0 + (r2.z * 2.0 - 1.0) * size_variation);
		float w = max(sz, dist * pixel_angle * 1.3);
		v_alpha = fade * clamp(sz / w, 0.0, 1.0);

		v_alpha *= smoothstep(surface_height,surface_height+.15,p.y);
		float speed = length(vel);
		vec3 dir = speed > 0.0001 ? vel / speed : vec3(0.0, -1.0, 0.0);
		float len = speed * stretch;
		vec3 side = normalize(cross(dir, n) + vec3(1e-5, 0.0, 0.0));
		vec3 tail = p - dir * len;
		VERTEX = mix(tail, p, UV.y) + side * (UV.x - 0.5) * w;
		NORMAL = n;
	}
}

void fragment() {
	float across = 1.0 - abs(v_uv.x * 2.0 - 1.0);
	float a = across * smoothstep(0.0, 0.85, v_uv.y) * (1.0 - smoothstep(0.94, 1.0, v_uv.y));
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
	ALBEDO = color.rgb * v_tone;
	EMISSION = color.rgb * v_tone * emission;
	ALPHA = clamp(a * v_alpha * color.a, 0.0, 1.0);
}
