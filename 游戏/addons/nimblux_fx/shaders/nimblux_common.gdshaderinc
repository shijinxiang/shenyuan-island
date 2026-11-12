// Shared helpers for NIMBLUX weather shaders: integer hashing and value noise.
// Parameter names here must not match any uniform name in a shader that includes this file:
// Godot 4.4 (Forward+ / Mobile) reads the uniform instead of the parameter in that case.

uint nimblux_pcg(uint v) {
	uint state = v * 747796405u + 2891336453u;
	uint word = ((state >> ((state >> 28u) + 4u)) ^ state) * 277803737u;
	return (word >> 22u) ^ word;
}

float nimblux_rand(uint n) {
	return float(nimblux_pcg(n) >> 8u) / 16777215.0;
}

// Four independent randoms for element `index` of stream `stream`.
vec4 nimblux_rand4(uint index, uint seed_u, uint stream) {
	uint h = nimblux_pcg(index ^ nimblux_pcg(seed_u + stream * 9973u));
	return vec4(nimblux_rand(h), nimblux_rand(h + 1u), nimblux_rand(h + 2u), nimblux_rand(h + 3u));
}

float nimblux_hash3(vec3 p) {
	uvec3 q = uvec3(ivec3(floor(p)) + ivec3(32768));
	return nimblux_rand(q.x * 73856093u ^ q.y * 19349663u ^ q.z * 83492791u);
}

float nimblux_vnoise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = mix(nimblux_hash3(i), nimblux_hash3(i + vec3(1.0, 0.0, 0.0)), f.x);
	float b = mix(nimblux_hash3(i + vec3(0.0, 1.0, 0.0)), nimblux_hash3(i + vec3(1.0, 1.0, 0.0)), f.x);
	float c = mix(nimblux_hash3(i + vec3(0.0, 0.0, 1.0)), nimblux_hash3(i + vec3(1.0, 0.0, 1.0)), f.x);
	float d = mix(nimblux_hash3(i + vec3(0.0, 1.0, 1.0)), nimblux_hash3(i + vec3(1.0, 1.0, 1.0)), f.x);
	return mix(mix(a, b, f.y), mix(c, d, f.y), f.z);
}

float nimblux_fbm(vec3 p, int octaves) {
	float sum = 0.0;
	float amp = 0.5;
	float norm = 0.0;
	for (int i = 0; i < octaves; i++) {
		sum += nimblux_vnoise(p) * amp;
		norm += amp;
		p = p * 2.03 + vec3(17.1, 5.3, 11.7);
		amp *= 0.5;
	}
	return sum / norm;
}

// Wraps p into the box [lo, lo + box_size) so elements stay anchored in world space.
vec3 nimblux_wrap(vec3 p, vec3 lo, vec3 box_size) {
	return lo + mod(p - lo, box_size);
}
