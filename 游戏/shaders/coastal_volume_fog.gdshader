shader_type fog;
uniform sampler3D density_noise : filter_linear, repeat_enable;
uniform sampler2D ground_height : filter_linear, repeat_disable;
uniform float weather_density = 0.0;
uniform vec3 fog_color : source_color = vec3(.65,.71,.76);

void fog() {
    vec3 p = WORLD_POSITION;
    float ground = max(texture(ground_height, (p.xz+vec2(400.))/800.).r, 0.);
    float altitude = max(p.y-ground,0.);
    vec3 drift = vec3(.35,0.,.46)*TIME;
    float broad = texture(density_noise,(p+drift)*.013).r;
    float detail = texture(density_noise,(p+drift*.8)*.035).r;
    float density = mix(.55,1.15,smoothstep(.15,.85,broad*.75+detail*.25));
    float edges = smoothstep(0.,.12,UVW.x)*smoothstep(0.,.12,1.-UVW.x);
    edges *= smoothstep(0.,.12,UVW.z)*smoothstep(0.,.12,1.-UVW.z);
    edges *= smoothstep(0.,.15,1.-UVW.y);
    DENSITY = weather_density*density*exp(-altitude/7.)*edges;
    ALBEDO = fog_color;
}
