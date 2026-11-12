shader_type spatial;
uniform float weather_daylight = 1.0;
uniform float weather_wetness = 0.0;
#include "res://shaders/island_biome.gdshaderinc"
uniform vec3 grass_color : source_color=vec3(.51,.65,.36);
uniform vec3 trail_color : source_color=vec3(.53,.46,.34);
uniform vec3 gravel_color : source_color=vec3(.59,.58,.51);
uniform sampler2D trail_mask : filter_linear,repeat_disable;
uniform vec2 mask_origin;
uniform vec2 mask_size;
varying vec3 position_world;
vec2 hash2(vec2 p){return fract(sin(vec2(dot(p,vec2(127.1,311.7)),dot(p,vec2(269.5,183.3))))*43758.5453);}
void vertex(){position_world=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;}
void fragment(){
    vec2 p=position_world.xz/.16;
    vec2 cell=floor(p);vec2 f=fract(p);
    float nearest=10.;float second=10.;float tint=0.;
    for(int y=-1;y<=1;y++){
        for(int x=-1;x<=1;x++){
            vec2 offset=vec2(float(x),float(y));vec2 random=hash2(cell+offset);
            vec2 delta=offset+.15+.7*random-f;float distance=dot(delta,delta);
            if(distance<nearest){second=nearest;nearest=distance;tint=random.x;}
            else{second=min(second,distance);}
        }
    }
    float stone=smoothstep(.012,.075,second-nearest);
    float patch=.5+.24*sin(position_world.x*.74+sin(position_world.z*.47))+.24*sin(position_world.z*.61-position_world.x*.31);
    stone*=1.-smoothstep(.82,.94,patch);
    vec3 gravel=mix(trail_color,gravel_color*mix(.84,1.11,tint),stone);
    float mask=texture(trail_mask,(position_world.xz-mask_origin)/mask_size).r;
    vec3 ground=biome_grass(grass_color,position_world.xz);
    ALBEDO=mix(ground,gravel,smoothstep(.03,.95,mask));
    ALBEDO*=1.-weather_wetness*.20;
    ROUGHNESS=mix(.97,.38,weather_wetness);SPECULAR=.06;
}
