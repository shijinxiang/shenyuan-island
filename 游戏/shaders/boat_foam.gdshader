shader_type spatial;
render_mode unshaded,blend_mix,depth_draw_never,cull_disabled;
uniform sampler2D swe_global_state : filter_linear,repeat_disable;
uniform sampler2D swe_global_terrain : filter_linear,repeat_disable;
uniform sampler2D swe_local_state : filter_linear,repeat_disable;
uniform sampler2D swe_local_terrain : filter_linear,repeat_disable;
uniform bool swe_ready=false;
uniform float daylight=1.;
varying vec3 world_position;
void vertex(){
 if(swe_ready){
  vec2 uv=(VERTEX.xz+vec2(400.))/800.;
  float y=textureLod(swe_global_state,uv,0.).r+textureLod(swe_global_terrain,uv,0.).r;
  vec2 local_uv=(VERTEX.xz-vec2(88.,72.))/128.;
  if(all(greaterThanEqual(local_uv,vec2(0.)))&&all(lessThanEqual(local_uv,vec2(1.))))y=textureLod(swe_local_state,local_uv,0.).r+textureLod(swe_local_terrain,local_uv,0.).r;
  VERTEX.y=y+.035;
 }
 world_position=VERTEX;
}
void fragment(){
 float grain=fract(sin(dot(floor(world_position.xz*20.),vec2(127.1,311.7)))*43758.54);
 float edge=smoothstep(0.,.18,UV.x)*(1.-smoothstep(.75,1.,UV.x));
 ALBEDO=vec3(.84,.94,.91)*daylight;
 ALPHA=COLOR.a*edge*mix(.35,.9,smoothstep(.18,.75,grain));
}
