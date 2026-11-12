uniform sampler2D swe_global_state : repeat_disable, filter_linear;
uniform sampler2D swe_global_terrain : repeat_disable, filter_linear;
uniform sampler2D swe_local_state : repeat_disable, filter_linear;
uniform sampler2D swe_local_terrain : repeat_disable, filter_linear;
uniform bool swe_ready = false;

float rain_surface_height(vec2 point) {
    float bed=rain_height(point);
    if(!swe_ready) return bed;
    vec2 uv=(point+vec2(400.))/800.;
    vec4 ground=textureLod(swe_global_terrain,uv,0.);
    vec4 state=textureLod(swe_global_state,uv,0.);
    float surface=state.r+ground.r;
    vec2 local_uv=(point-vec2(88.,72.))/128.;
    if(all(greaterThanEqual(local_uv,vec2(0.))) && all(lessThanEqual(local_uv,vec2(1.)))) {
        vec4 local_ground=textureLod(swe_local_terrain,local_uv,0.);
        vec4 local_state=textureLod(swe_local_state,local_uv,0.);
        surface=local_state.r+local_ground.r;
        ground=local_ground;
    }
    return max(surface,ground.r);
}
