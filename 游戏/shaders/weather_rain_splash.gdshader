// Rain impacts: expanding ripple rings on the ground (mode 0) and small splash crowns (mode 1).
// Every element loops on its own cycle and picks a new random spot each cycle. (Lite)
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, world_vertex_coords, shadows_disabled, diffuse_lambert_wrap, specular_disabled;

#include "res://addons/nimblux_fx/shaders/nimblux_common.gdshaderinc"

uniform int mode = 0;
uniform int seed = 1;
uniform vec3 area_center;
uniform float radius = 8.0;
uniform float ground_height = 0.0;
uniform float time = 0.0;
uniform float rate = 1.5;
uniform float amount : hint_range(0.0, 1.0) = 1.0;
uniform float size = 0.35;
uniform vec4 color : source_color = vec4(0.8, 0.85, 0.95, 0.5);
uniform float emission = 0.3;


uniform sampler2D rain_ground : filter_linear, repeat_disable;
uniform sampler2D rain_local_ground : filter_linear, repeat_disable;
float rain_height(vec2 p) {
 float h=texture(rain_ground,(p+vec2(400.))/800.).r;
 if(p.x>88. && p.x<216. && p.y>72. && p.y<200.) h=texture(rain_local_ground,(p-vec2(88.,72.))/128.).r;
 return max(h,0.);
}

#include "res://shaders/rain_surface_height.gdshaderinc"

varying vec2 v_uv;
varying float v_phase;
varying float v_alpha;
varying vec4 v_rand;

void vertex() {
	uint idx = uint(VERTEX.x + 0.5);
	vec4 r = nimblux_rand4(idx, uint(seed), 7u);
	float t = time * rate * (0.75 + 0.5 * r.x) + r.y * 8.0;
	float cyc = floor(t);
	v_phase = fract(t);
	vec4 h = nimblux_rand4(idx * 7919u + uint(cyc), uint(seed), 11u);
	v_rand = h;
	v_uv = UV;
	v_alpha = 0.0;
	VERTEX = area_center;
	if (h.z < amount) {
		float rad = sqrt(h.x) * radius;
		float ang = h.y * TAU;
		vec3 p = vec3(area_center.x + cos(ang) * rad, ground_height, area_center.z + sin(ang) * rad);
		p.y=rain_surface_height(p.xz);
		float fade = 1.0 - smoothstep(radius * 0.6, radius, rad);
		float s = size * (0.7 + 0.6 * h.w);
		if (mode == 0) {
			VERTEX = p + vec3((UV.x - 0.5) * s, 0.012, (UV.y - 0.5) * s);
			NORMAL = vec3(0.0, 1.0, 0.0);
		} else {
			vec3 cam = INV_VIEW_MATRIX[3].xyz;
			vec3 tc = cam - p;
			tc.y = 0.0;
			vec3 right = normalize(cross(vec3(0.0, 1.0, 0.0), tc + vec3(1e-4, 0.0, 0.0)));
			VERTEX = p + right * (UV.x - 0.5) * s + vec3(0.0, (1.0 - UV.y) * s * 0.75, 0.0);
			NORMAL = normalize(tc + vec3(1e-4, 0.0, 0.0));
		}
		v_alpha = fade;
	}
}

void fragment() {
	float a = 0.0;
	float ph = v_phase;
	if (mode == 0) {
		float d = length(v_uv * 2.0 - 1.0);
		float r1 = ph;
		float r2 = max(ph - 0.25, 0.0) * 1.2;
		float w = 0.03 + 0.05 * ph;
		a = exp(-pow((d - r1) / w, 2.0)) * pow(1.0 - ph, 1.6);
		a += 0.6 * exp(-pow((d - r2) / w, 2.0)) * pow(1.0 - ph, 2.0) * step(0.25, ph);
		a *= 1.0 - smoothstep(0.92, 1.0, d);
	} else if (ph < 0.46) {
		float life = clamp(ph * 2.2, 0.0, 1.0);
		vec2 p = vec2(v_uv.x - 0.5, 1.0 - v_uv.y);
		for (int i = 0; i < 7; i++) {
			float fi = float(i);
			float ang = (fi / 6.0 - 0.5) * 2.2 + (v_rand.x - 0.5) * 0.4;
			float spd = 0.55 + 0.35 * fract(v_rand.y * 7.0 + fi * 0.37);
			vec2 c = vec2(sin(ang) * spd * 0.45, cos(ang) * spd * 1.25) * life - vec2(0.0, 1.35 * life * life);
			c.y = max(c.y, 0.0);
			float rr = 0.035 * (1.0 - life * 0.5);
			a += 1.0 - smoothstep(rr * 0.4, rr, length(p - c));
		}
		float stem = (1.0 - smoothstep(0.0, 0.04, abs(p.x))) * (1.0 - smoothstep(0.0, 0.35 * (1.0 - life), p.y)) * (1.0 - life);
		a += stem * 0.7;
		a *= 1.0 - life * 0.7;
	}
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
	ALBEDO = color.rgb;
	EMISSION = color.rgb * emission;
	ALPHA = clamp(a * v_alpha * color.a, 0.0, 1.0);
}
