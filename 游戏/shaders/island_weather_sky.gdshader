shader_type sky;
uniform sampler2D day_sky : source_color, filter_linear;
uniform sampler2D dusk_sky : source_color, filter_linear;
uniform sampler2D night_sky : source_color, filter_linear;
uniform sampler2D cloudy_sky : source_color, filter_linear;
uniform float daylight = 1.0;
uniform float dusk = 0.0;
uniform float cloud_cover = 0.0;
void sky() {
    vec2 uv=vec2(atan(EYEDIR.x,EYEDIR.z)/TAU+.5,acos(clamp(EYEDIR.y,-1.,1.))/PI);
    vec3 clear=mix(texture(night_sky,uv).rgb*.55,texture(day_sky,uv).rgb,daylight);
    clear=mix(clear,texture(dusk_sky,uv).rgb,dusk*.75);
    vec3 grey=texture(cloudy_sky,uv).rgb*mix(.12,.78,daylight);
    COLOR=mix(clear,grey,cloud_cover);
}
