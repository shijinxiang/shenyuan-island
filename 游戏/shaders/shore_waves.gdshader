shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;

uniform sampler2D scene_color : hint_screen_texture, repeat_disable, filter_linear;
uniform sampler2D scene_depth : hint_depth_texture, repeat_disable, filter_nearest;
uniform sampler2D depth_map : filter_linear, repeat_disable;
uniform vec2 bed_origin;
uniform vec2 bed_size;
uniform float wave_length = 8.5;
uniform float wave_speed = 1.65;
uniform float wave_height = .28;
uniform float foam_strength = .88;
uniform float preview_time = -1.;
uniform vec3 absorption = vec3(.76,.27,.19);
uniform vec3 sea_scatter : source_color = vec3(.025,.43,.64);
uniform float refraction_strength = .0025;

varying vec3 world_position;

float hash_noise(vec2 point) {
    return fract(sin(dot(point, vec2(127.1,311.7))) * 43758.5453);
}

float soft_noise(vec2 point) {
    vec2 cell = floor(point);
    vec2 blend = fract(point);
    blend = blend * blend * (3. - 2. * blend);
    return mix(mix(hash_noise(cell), hash_noise(cell + vec2(1,0)), blend.x),
               mix(hash_noise(cell + vec2(0,1)), hash_noise(cell + vec2(1,1)), blend.x), blend.y);
}

float bathymetry(vec2 point) {
    vec2 uv = (point - bed_origin) / bed_size;
    if (any(lessThan(uv, vec2(0))) || any(greaterThan(uv, vec2(1)))) {
        return 9.;
    }
    return textureLod(depth_map, uv, 0.).r * 12.;
}

float wave_phase(vec2 point, float water_depth, float time) {
    // Increasing time moves each crest toward smaller depth, toward the shore.
    float shore_distance = water_depth * 14.;
    float distortion = (soft_noise(point * .13) - .5) * .75;
    return (shore_distance + distortion + time * wave_speed) / wave_length;
}

float surface_height(vec2 point, float time) {
    float water_depth = bathymetry(point);
    float phase = TAU * wave_phase(point, water_depth, time);
    float shore_fade = smoothstep(.035,.65,water_depth);
    float edge_fade = 1. - smoothstep(320.,380.,max(abs(point.x),abs(point.y)));
    float wave_group = .80 + .20 * sin(time * .32 + soft_noise(point * .025) * 2.);
    float profile = .76 * sin(phase) + .24 * sin(2. * phase);
    return wave_height * profile * shore_fade * edge_fade * wave_group;
}

void vertex() {
    float time = preview_time >= 0. ? preview_time : TIME;
    vec3 original = (MODEL_MATRIX * vec4(VERTEX,1.)).xyz;
    VERTEX.y += surface_height(original.xz,time);
    world_position = (MODEL_MATRIX * vec4(VERTEX,1.)).xyz;
}

vec3 scene_world(vec2 uv, mat4 inverse_projection, mat4 inverse_view) {
    float depth_value = texture(scene_depth,uv).r;
    #if CURRENT_RENDERER == RENDERER_COMPATIBILITY
    vec3 ndc = vec3(uv,depth_value) * 2. - 1.;
    #else
    vec3 ndc = vec3(uv * 2. - 1.,depth_value);
    #endif
    vec4 reconstructed = inverse_view * inverse_projection * vec4(ndc,1.);
    return reconstructed.xyz / reconstructed.w;
}

void fragment() {
    float time = preview_time >= 0. ? preview_time : TIME;
    vec2 point = world_position.xz;
    float water_depth = bathymetry(point);
    float phase = wave_phase(point,water_depth,time);

    float sample_step = .55;
    float slope_x = (surface_height(point + vec2(sample_step,0),time) - surface_height(point - vec2(sample_step,0),time)) / (2. * sample_step);
    float slope_z = (surface_height(point + vec2(0,sample_step),time) - surface_height(point - vec2(0,sample_step),time)) / (2. * sample_step);
    vec2 ripples = vec2(sin(dot(point,vec2(1.8,.7)) + time * 1.1), cos(dot(point,vec2(-.8,2.1)) - time * 1.3)) * .025;
    vec3 wave_normal = normalize(vec3(-slope_x + ripples.x,1.,-slope_z + ripples.y));
    vec3 behind = scene_world(SCREEN_UV,INV_PROJECTION_MATRIX,INV_VIEW_MATRIX);
    float thickness = clamp(world_position.y - behind.y,0.,16.);
    vec2 screen_bend = (VIEW_MATRIX * vec4(wave_normal.x,0.,wave_normal.z,0.)).xy;
    vec2 refracted_uv = clamp(SCREEN_UV + screen_bend * refraction_strength * 6. * smoothstep(.03,.6,thickness),vec2(.001),vec2(.999));
    if (scene_world(refracted_uv,INV_PROJECTION_MATRIX,INV_VIEW_MATRIX).y > world_position.y + .02) {
        refracted_uv = SCREEN_UV;
    }
    vec3 bottom_color = textureLod(scene_color,refracted_uv,0.).rgb;
    vec3 transmission = exp(-absorption * thickness * 1.25);
    vec3 water_color = bottom_color * transmission + sea_scatter * (1. - transmission);
    vec3 view_direction = normalize(CAMERA_POSITION_WORLD - world_position);
    float fresnel = .025 + .20 * pow(1. - max(dot(wave_normal,view_direction),0.),4.);
    water_color = mix(water_color,vec3(.21,.46,.57),fresnel * smoothstep(.04,.4,thickness));
    float face_light = dot(wave_normal,normalize(vec3(-.4,1.,.3)));
    water_color *= .88 + .17 * face_light;

    // Crest, breaking sheet, and dissolving bubbles share one shoreward phase.
    float cycle = fract(phase - .19 + .5) - .5;
    float edge_width = max(fwidth(cycle),.009);
    float crest = 1. - smoothstep(.035,.073 + edge_width,abs(cycle));
    float wake = smoothstep(.02,.07,cycle) * (1. - smoothstep(.08,.38,cycle));
    float breaking_zone = smoothstep(.08,.38,water_depth) * (1. - smoothstep(1.55,3.0,water_depth));
    float patches = soft_noise(point * 1.7 + vec2(time * .10,-time * .07));
    float bubbles = soft_noise(point * 7.2 + vec2(-time * .24,time * .16));
    float crest_pattern = mix(.28,1.,smoothstep(.24,.62,patches));
    float foam_sheet = crest * crest_pattern;
    float foam_trail = wake * smoothstep(.48,.72,patches) * smoothstep(.30,.64,bubbles) * .65;
    float contact = (1. - smoothstep(.035,.19,thickness)) * smoothstep(.003,.025,thickness);
    contact *= (.25 + .75 * crest) * smoothstep(.20,.58,patches);
    float foam = clamp((foam_sheet + foam_trail) * breaking_zone + contact * .45,0.,1.) * foam_strength;
    vec3 foam_color = mix(vec3(.57,.75,.75),vec3(.95,.98,.95),smoothstep(.05,.7,foam));
    water_color = mix(water_color,foam_color,foam);
    ALBEDO = max(water_color,vec3(0.));
    ALPHA = 1.;
}
