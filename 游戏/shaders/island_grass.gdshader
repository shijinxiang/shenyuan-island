// Based on StayAtHomeDev's stylized grass shader, Copyright (c) 2023.
// MIT license is retained in assets/vegetation/stylized_grass/license.txt.
shader_type spatial;
uniform float weather_daylight = 1.0;
uniform float weather_wetness = 0.0;
render_mode cull_disabled, diffuse_lambert_wrap;
#include "res://shaders/island_biome.gdshaderinc"

uniform vec3 color : source_color = vec3(.42,.58,.23);
uniform vec3 color2 : source_color = vec3(.61,.73,.36);
uniform sampler2D noise : repeat_enable, filter_linear_mipmap;
uniform float noiseScale = 85.;
uniform vec2 wind_direction = vec2(-.6111623,-.7915053);
uniform float wind_strength = .32;
uniform float wind_speed = 1.6;
uniform float fade_start = 170.;
uniform float fade_end = 220.;
uniform float preview_time = -1.;

varying vec3 world_root;
varying float blade_height;
varying float instance_shade;

void vertex() {
    float time = preview_time >= 0. ? preview_time : TIME;
    world_root = (MODEL_MATRIX * vec4(0.,0.,0.,1.)).xyz;
    blade_height = clamp(VERTEX.y,0.,1.);
    instance_shade = INSTANCE_CUSTOM.y;
    vec2 direction = normalize(wind_direction);
    float phase = dot(world_root.xz,direction)*.55-time*wind_speed+INSTANCE_CUSTOM.x*1.2;
    float gust = textureLod(noise,world_root.xz*.026-direction*time*.018,0.).r;
    float bend = (.45+.30*sin(phase)+.25*gust)*mix(.8,1.2,INSTANCE_CUSTOM.z);
    float tip_weight = blade_height*blade_height;
    vec3 local_wind = normalize(transpose(mat3(MODEL_MATRIX))*vec3(direction.x,0.,direction.y));
    float flutter = sin(time*4.3+VERTEX.x*3.+INSTANCE_CUSTOM.w*TAU)*.035*tip_weight;
    VERTEX += local_wind*(wind_strength*bend*tip_weight+flutter);
    VERTEX.y -= .045*tip_weight*bend;
    float distance_to_camera = distance(CAMERA_POSITION_WORLD,world_root);
    VERTEX *= 1.-smoothstep(fade_start,fade_end,distance_to_camera);
}

void fragment() {
    float field_tint = texture(noise,world_root.xz/noiseScale).r;
    vec3 gradient = mix(color,color2,smoothstep(0.,1.,blade_height));
    gradient*=biome_grass(meadow_grass_color,world_root.xz)/meadow_grass_color;
    ALBEDO = gradient*mix(.86,1.08,field_tint)*mix(.93,1.07,instance_shade);
    vec3 up_view = normalize((VIEW_MATRIX*vec4(0.,1.,0.,0.)).xyz);
    vec3 facing_normal = FRONT_FACING ? NORMAL : -NORMAL;
    NORMAL = normalize(mix(facing_normal,up_view,.90));
    ALBEDO*=1.-weather_wetness*.10;
    ROUGHNESS = mix(1.,.65,weather_wetness);
    SPECULAR = .05;
    AO = mix(.90,1.,blade_height);
    AO_LIGHT_AFFECT = .2;
}
