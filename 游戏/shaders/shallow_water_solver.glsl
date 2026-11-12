#[compute]
#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;
layout(rgba32f, set = 0, binding = 0) uniform readonly image2D previous_state;
layout(rgba32f, set = 0, binding = 1) uniform writeonly image2D next_state;
layout(rgba32f, set = 0, binding = 2) uniform readonly image2D terrain;
layout(rgba32f, set = 0, binding = 3) uniform readonly image2D coarse_state;
layout(rgba32f, set = 0, binding = 4) uniform readonly image2D coarse_terrain;

layout(push_constant, std430) uniform Parameters {
    vec4 grid;       // origin x,z, cell spacing, fixed timestep
    vec4 wind;       // simulation time, direction x,z, local-domain flag
    vec4 coarse;     // coarse origin x,z, spacing, resolution
    vec4 settings;   // resolution, wave amplitude, gravity, reserved
} parameters;

const float DRY_DEPTH = 0.003;
const float PI = 3.141592653589793;

vec2 velocity(vec4 state) {
    return state.x > DRY_DEPTH ? state.yz / state.x : vec2(0.0);
}

vec3 physical_flux(vec3 state, vec2 normal) {
    vec2 speed = state.x > DRY_DEPTH ? state.yz / state.x : vec2(0.0);
    float normal_speed = dot(speed, normal);
    return vec3(state.x * normal_speed,
                state.yz * normal_speed + normal * (0.5 * parameters.settings.z * state.x * state.x));
}

// Rusanov finite-volume flux with hydrostatic reconstruction and bed-pressure correction.
vec3 outward_flux(vec4 center, vec4 neighbor, float center_bed, float neighbor_bed, vec2 normal) {
    float face_bed = max(center_bed, neighbor_bed);
    float left_depth = max(0.0, center.x + center_bed - face_bed);
    float right_depth = max(0.0, neighbor.x + neighbor_bed - face_bed);
    vec2 left_velocity = velocity(center);
    vec2 right_velocity = velocity(neighbor);
    vec3 left_state = vec3(left_depth, left_depth * left_velocity);
    vec3 right_state = vec3(right_depth, right_depth * right_velocity);
    float signal_speed = max(abs(dot(left_velocity, normal)) + sqrt(parameters.settings.z * left_depth),
                             abs(dot(right_velocity, normal)) + sqrt(parameters.settings.z * right_depth));
    vec3 flux = 0.5 * (physical_flux(left_state, normal) + physical_flux(right_state, normal));
    flux -= 0.5 * signal_speed * (right_state - left_state);
    flux.yz += normal * (0.5 * parameters.settings.z * (center.x * center.x - left_depth * left_depth));
    return flux;
}

vec4 interpolate_state(vec2 pixel) {
    ivec2 lower = ivec2(floor(pixel));
    vec2 blend = fract(pixel);
    ivec2 limit = imageSize(previous_state) - ivec2(1);
    vec4 a = imageLoad(previous_state, clamp(lower, ivec2(0), limit));
    vec4 b = imageLoad(previous_state, clamp(lower + ivec2(1,0), ivec2(0), limit));
    vec4 c = imageLoad(previous_state, clamp(lower + ivec2(0,1), ivec2(0), limit));
    vec4 d = imageLoad(previous_state, clamp(lower + ivec2(1,1), ivec2(0), limit));
    return mix(mix(a,b,blend.x), mix(c,d,blend.x), blend.y);
}

vec4 coarse_surface(ivec2 cell) {
    ivec2 bounded = clamp(cell, ivec2(0), imageSize(coarse_state) - ivec2(1));
    vec4 state = imageLoad(coarse_state, bounded);
    if (state.x < DRY_DEPTH) return vec4(0.0);
    state.x += imageLoad(coarse_terrain, bounded).x;
    return state;
}

vec4 interpolate_coarse(vec2 world_position, float bed) {
    vec2 pixel = (world_position - parameters.coarse.xy) / parameters.coarse.z - 0.5;
    ivec2 lower = ivec2(floor(pixel));
    vec2 blend = fract(pixel);
    vec4 result = mix(mix(coarse_surface(lower), coarse_surface(lower + ivec2(1,0)), blend.x),
                      mix(coarse_surface(lower + ivec2(0,1)), coarse_surface(lower + ivec2(1,1)), blend.x), blend.y);
    result.x = max(0.0, result.x - bed);
    return result;
}

void main() {
    ivec2 cell = ivec2(gl_GlobalInvocationID.xy);
    ivec2 size = imageSize(previous_state);
    if (any(greaterThanEqual(cell, size))) return;
    vec4 ground = imageLoad(terrain, cell);
    if (ground.y > 0.5) {
        imageStore(next_state, cell, vec4(0.0));
        return;
    }
    vec4 center = imageLoad(previous_state, cell);
    vec3 flux_sum = vec3(0.0);
    float divergence = 0.0;
    float impact = 0.0;
    vec2 bed_gradient = vec2(0.0);
    float surface_laplacian = 0.0;
    const ivec2 offsets[4] = ivec2[4](ivec2(1,0),ivec2(-1,0),ivec2(0,1),ivec2(0,-1));
    vec2 center_velocity = velocity(center);
    for (int face = 0; face < 4; face++) {
        vec2 normal = vec2(offsets[face]);
        ivec2 neighbor_cell = clamp(cell + offsets[face], ivec2(0), size - ivec2(1));
        vec4 neighbor_ground = imageLoad(terrain, neighbor_cell);
        vec4 neighbor = imageLoad(previous_state, neighbor_cell);
        bed_gradient += normal * (neighbor_ground.x - ground.x) / (2.0 * parameters.grid.z);
        if (neighbor_ground.y > 0.5) {
            impact += max(0.0, dot(center_velocity, normal));
            neighbor = center;
            neighbor.yz -= 2.0 * dot(neighbor.yz, normal) * normal;
            neighbor_ground.x = ground.x;
        }
        flux_sum += outward_flux(center, neighbor, ground.x, neighbor_ground.x, normal);
        surface_laplacian += (neighbor.x + neighbor_ground.x - center.x - ground.x) / (parameters.grid.z * parameters.grid.z);
        divergence += dot(velocity(neighbor) - center_velocity, normal) / (2.0 * parameters.grid.z);
    }
    float dt = parameters.grid.w;
    vec3 conserved = center.xyz - dt / parameters.grid.z * flux_sum;
    conserved.x = max(conserved.x, 0.0);
    vec2 speed = conserved.x > DRY_DEPTH ? conserved.yz / conserved.x : vec2(0.0);
    float friction = 0.006 + 0.025 / (conserved.x + 0.08);
    conserved.yz /= 1.0 + dt * friction * length(speed);
    float wind_acceleration = ground.z > 0.5 ? 0.0008 : 0.00004;
    conserved.yz += dt * conserved.x * parameters.wind.yz * wind_acceleration;
    if (conserved.x < DRY_DEPTH) conserved.yz = vec2(0.0);

    vec2 advected_pixel = vec2(cell) - speed * dt / parameters.grid.z;
    float old_foam = interpolate_state(advected_pixel).w;
    float shallow_zone = 1.0 - smoothstep(0.30,1.05,conserved.x);
    float froude = length(speed) / sqrt(parameters.settings.z * max(conserved.x,0.025));
    float uphill_speed = length(bed_gradient) > 0.002 ? max(0.0,dot(speed,normalize(bed_gradient))) : 0.0;
    float arriving_water = smoothstep(0.08,0.7,uphill_speed) * smoothstep(0.015,0.12,conserved.x);
    float breaking = shallow_zone * arriving_water * (max(0.0,-divergence-0.08) * 0.8 + max(0.0,froude-0.6) * 0.35);
    float production = 2.0 * breaking + impact * 1.1;
    float approaching_zone = smoothstep(0.6,1.2,conserved.x) * (1.0-smoothstep(3.5,6.0,conserved.x));
    float approaching_crest = (1.0-smoothstep(0.0025,0.0075,abs(divergence))) * smoothstep(0.14,0.38,conserved.x+ground.x);
    approaching_crest *= smoothstep(0.0002,0.0015,-surface_laplacian) * smoothstep(0.08,0.30,length(speed));
    production += max(0.075-old_foam,0.0) * 14.0 * approaching_zone * approaching_crest;
    // Ninety percent of unrefreshed foam disappears in about 1.5 seconds.
    float foam_lifetime = mix(0.65,0.24,smoothstep(0.85,1.3,conserved.x));
    foam_lifetime = mix(foam_lifetime,0.65,step(0.01,impact));
    float foam = clamp(old_foam * exp(-dt/foam_lifetime) + production * dt, 0.0, 1.0);
    if (conserved.x < DRY_DEPTH) foam = 0.0;
    vec4 result = vec4(conserved,foam);

    float border_distance = float(min(min(cell.x,cell.y), min(size.x-1-cell.x,size.y-1-cell.y)));
    vec2 world_position = parameters.grid.xy + (vec2(cell) + 0.5) * parameters.grid.z;
    if (parameters.wind.w > 0.5 && border_distance < 8.0) {
        vec4 target = interpolate_coarse(world_position, ground.x);
        float blend = border_distance < 1.0 ? 1.0 : dt * 8.0 * (1.0 - border_distance/8.0);
        result = mix(result, target, clamp(blend,0.0,1.0));
    } else if (parameters.wind.w < 0.5 && border_distance < 12.0 && ground.z > 0.5) {
        vec2 wind_direction = parameters.wind.yz;
        bool inlet = (cell.x > size.x-13 && wind_direction.x < 0.0) || (cell.x < 12 && wind_direction.x > 0.0)
                  || (cell.y > size.y-13 && wind_direction.y < 0.0) || (cell.y < 12 && wind_direction.y > 0.0);
        float still_depth = max(-ground.x,0.0);
        float celerity = sqrt(parameters.settings.z * max(still_depth,0.1));
        float travel = dot(world_position,wind_direction) / celerity;
        float time = parameters.wind.x;
        float ramp = smoothstep(0.0,18.0,time);
        float elevation = parameters.settings.y * ramp * (sin(2.0*PI*(travel-time)/14.0)
                        + 0.24*sin(2.0*PI*(travel-time)/19.0+1.7)
                        + 0.10*sin(2.0*PI*(travel-time)/11.0+3.1));
        if (!inlet) elevation = 0.0;
        vec4 target = vec4(max(0.0,still_depth+elevation),wind_direction*(elevation*celerity),0.0);
        float blend = border_distance < 1.0 ? 1.0 : dt * 3.0 * (1.0 - border_distance/12.0);
        result = mix(result,target,clamp(blend,0.0,1.0));
    }
    imageStore(next_state,cell,result);
}
