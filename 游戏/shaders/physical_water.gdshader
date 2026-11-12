shader_type spatial;
uniform float weather_daylight = 1.0;
uniform float rain_intensity = 0.0;
uniform float rain_time = 0.0;
uniform bool boat_cutout_enabled = false;
uniform vec2 boat_center = vec2(0.);
uniform vec2 boat_forward = vec2(0.,1.);
render_mode unshaded, cull_disabled, depth_draw_never;

uniform sampler2D scene_color : hint_screen_texture, repeat_disable, filter_linear;
uniform sampler2D scene_depth : hint_depth_texture, repeat_disable, filter_nearest;
uniform sampler2D swe_global_state : repeat_disable, filter_linear;
uniform sampler2D swe_global_terrain : repeat_disable, filter_linear;
uniform sampler2D swe_local_state : repeat_disable, filter_linear;
uniform sampler2D swe_local_terrain : repeat_disable, filter_linear;
uniform vec2 global_origin = vec2(-400.);
uniform float global_extent = 800.;
uniform vec2 local_origin = vec2(88.,72.);
uniform float local_extent = 128.;
uniform vec2 wind_direction = vec2(-.6111623,-.7915053);
uniform float simulation_time = 0.;
uniform float incoming_amplitude = .65;
uniform bool swe_ready = false;
uniform vec3 absorption = vec3(.42,.16,.105);
uniform vec3 sea_scatter : source_color = vec3(.02,.34,.54);
varying vec3 world_position;

float hash_noise(vec2 point) {
    return fract(sin(dot(point,vec2(127.1,311.7))) * 43758.5453);
}

float soft_noise(vec2 point) {
    vec2 cell = floor(point);
    vec2 blend = fract(point);
    blend = blend * blend * (3. - 2. * blend);
    return mix(mix(hash_noise(cell),hash_noise(cell+vec2(1,0)),blend.x),
               mix(hash_noise(cell+vec2(0,1)),hash_noise(cell+1.),blend.x),blend.y);
}

// Returns elevation, wet depth, transported foam, and enclosed-lake mask.
vec4 surface_at(vec2 point) {
    if (!swe_ready) return vec4(0.,9.,0.,0.);
    vec2 global_uv = (point-global_origin)/global_extent;
    if (any(lessThan(global_uv,vec2(0))) || any(greaterThan(global_uv,vec2(1)))) {
        float travel = dot(point,wind_direction)/sqrt(9.81*9.);
        float phase = travel-simulation_time;
        float elevation = incoming_amplitude*(sin(TAU*phase/14.)+.24*sin(TAU*phase/19.+1.7)+.1*sin(TAU*phase/11.+3.1));
        vec2 border_uv=clamp(global_uv,vec2(0.),vec2(1.));
        vec4 border_state=textureLod(swe_global_state,border_uv,0.);
        vec4 border_ground=textureLod(swe_global_terrain,border_uv,0.);
        float border_elevation=border_state.r+border_ground.r;
        float outside_distance=length((global_uv-border_uv)*global_extent);
        elevation=mix(border_elevation,elevation,smoothstep(0.,80.,outside_distance));
        return vec4(elevation,9.+elevation,0.,0.);
    }
    vec4 ground = textureLod(swe_global_terrain,global_uv,0.);
    vec4 state = textureLod(swe_global_state,global_uv,0.);
    vec4 surface = vec4(state.r+ground.r,state.r,state.a,ground.a);
    vec2 local_uv = (point-local_origin)/local_extent;
    if (all(greaterThanEqual(local_uv,vec2(0))) && all(lessThanEqual(local_uv,vec2(1)))) {
        float edge = min(min(local_uv.x,local_uv.y),min(1.-local_uv.x,1.-local_uv.y))*local_extent;
        float weight = smoothstep(0.,8.,edge);
        vec4 local_ground = textureLod(swe_local_terrain,local_uv,0.);
        vec4 local_state = textureLod(swe_local_state,local_uv,0.);
        vec4 local_surface = vec4(local_state.r+local_ground.r,local_state.r,local_state.a,local_ground.a);
        surface = mix(surface,local_surface,weight);
    }
    return surface;
}

void vertex() {
    vec3 original = (MODEL_MATRIX*vec4(VERTEX,1.)).xyz;
    vec4 surface = surface_at(original.xz);
    VERTEX.y = surface.y > .003 ? surface.x : 0.;
    world_position = (MODEL_MATRIX*vec4(VERTEX,1.)).xyz;
}

vec3 scene_world(vec2 uv,mat4 inverse_projection,mat4 inverse_view) {
    float depth = texture(scene_depth,uv).r;
    #if CURRENT_RENDERER == RENDERER_COMPATIBILITY
    vec3 ndc = vec3(uv,depth)*2.-1.;
    #else
    vec3 ndc = vec3(uv*2.-1.,depth);
    #endif
    vec4 position = inverse_view*inverse_projection*vec4(ndc,1.);
    return position.xyz/position.w;
}

// Impacts live on the displaced water surface, so wave crests cannot cover them.
vec3 rain_impacts(vec2 point) {
    vec2 cell = floor(point/1.25);
    float width = max(length(fwidth(point))*.65,.014);
    vec3 response = vec3(0.);
    for(int y=-1;y<=1;y++) {
        for(int x=-1;x<=1;x++) {
            vec2 tile = cell+vec2(float(x),float(y));
            float seed = hash_noise(tile+vec2(41.7,19.3));
            float clock = rain_time*1.65+seed*6.;
            float cycle = floor(clock);
            float phase = fract(clock);
            float drop = hash_noise(tile+vec2(cycle*17.1,cycle*7.3));
            vec2 center = (tile+vec2(hash_noise(tile+cycle+13.),hash_noise(tile-cycle+29.)))*1.25;
            vec2 delta = point-center;
            float distance = length(delta);
            float radius = .025+phase*.38;
            float ring = exp(-pow((distance-radius)/width,2.));
            float life = smoothstep(0.,.08,phase)*pow(1.-phase,1.5)*step(drop,rain_intensity*.55);
            response.xy += delta/max(distance,.001)*ring*life*.05;
            response.z += ring*life;
        }
    }
    return response;
}

void fragment() {
    vec2 point = world_position.xz;
    if(boat_cutout_enabled) {
        vec2 relative=point-boat_center;
        float along=dot(relative,boat_forward);
        float across=dot(relative,vec2(boat_forward.y,-boat_forward.x));
        float length_ratio=abs(along)/1.65;
        float width=.49*sqrt(max(0.,1.-pow(length_ratio,4.)));
        if(length_ratio<1. && abs(across)<width) discard;
    }
    vec4 surface = surface_at(point);
    if (surface.y < .004) discard;
    float step_size = .5;
    vec4 left = surface_at(point-vec2(step_size,0));
    vec4 right = surface_at(point+vec2(step_size,0));
    vec4 back = surface_at(point-vec2(0,step_size));
    vec4 front = surface_at(point+vec2(0,step_size));
    float slope_x = (right.x-left.x)/(2.*step_size);
    float slope_z = (front.x-back.x)/(2.*step_size);
    if (left.y<.006 || right.y<.006) slope_x=0.;
    if (front.y<.006 || back.y<.006) slope_z=0.;
    float wind_phase = dot(point,wind_direction)*3.7-simulation_time*1.1;
    float ripple_size = mix(.018,.003,surface.w);
    vec2 ripple = wind_direction*sin(wind_phase+sin(dot(point,vec2(.4,-.7))))*ripple_size;
    vec3 normal = normalize(vec3(-slope_x+ripple.x,1.,-slope_z+ripple.y));
    vec3 impacts=vec3(0.);
    if(rain_intensity>.01) {
        impacts=rain_impacts(point);
        normal=normalize(normal+vec3(impacts.x,0.,impacts.y));
    }
    vec3 behind = scene_world(SCREEN_UV,INV_PROJECTION_MATRIX,INV_VIEW_MATRIX);
    float thickness = clamp(world_position.y-behind.y,0.,18.);
    vec2 bend = (VIEW_MATRIX*vec4(normal.x,0.,normal.z,0.)).xy;
    vec2 refracted_uv = clamp(SCREEN_UV+bend*.012*smoothstep(.025,.5,thickness),vec2(.001),vec2(.999));
    if (scene_world(refracted_uv,INV_PROJECTION_MATRIX,INV_VIEW_MATRIX).y>world_position.y+.02) refracted_uv=SCREEN_UV;
    vec3 bottom = textureLod(scene_color,refracted_uv,0.).rgb;
    // Bed depth governs the gradual coastal colour; crest thickness adds a small correction.
    float bed_depth=max(surface.y-surface.x,0.);
    float colour_depth=min(thickness,bed_depth+max(surface.x,0.)*.12);
    colour_depth*=mix(.55,1.,smoothstep(.1,3.8,bed_depth));
    vec3 transmission = exp(-absorption*colour_depth);
    transmission*=1.-smoothstep(4.5,8.5,colour_depth);
    vec3 color = bottom*transmission+sea_scatter*weather_daylight*(1.-transmission);
    vec3 eye = normalize(CAMERA_POSITION_WORLD-world_position);
    float fresnel = .025+.18*pow(1.-max(dot(normal,eye),0.),4.);
    color=mix(color,vec3(.16,.36,.48)*weather_daylight,fresnel*smoothstep(.25,2.0,bed_depth));
    float face_light=clamp(dot(normal,normalize(vec3(-.4,1.,.3))),0.,1.);
    color*=mix(.97,1.03,face_light);
    // Foam coverage is generated and advected by the solver's collision/dissipation state.
    float density = clamp(surface.z,0.,1.);
    float texture_detail = soft_noise(point*5.4+wind_direction*simulation_time*.10);
    float bubble_holes = smoothstep(.20,.53,texture_detail);
    float faint_foam = smoothstep(.008,.055,density)*.23;
    float impact_foam = smoothstep(.06,.24,density)*.86;
    float coverage = clamp(faint_foam+impact_foam,0.,1.)*mix(bubble_holes,1.,smoothstep(.10,.32,density));
    color=mix(color,vec3(.88,.94,.91)*weather_daylight,coverage*.94);
    color=mix(color,vec3(.70,.82,.89)*max(weather_daylight,.25),clamp(impacts.z*.40,0.,.45));
    ALBEDO=max(color,vec3(0.));
    ALPHA=smoothstep(.004,.025,surface.y);
}
