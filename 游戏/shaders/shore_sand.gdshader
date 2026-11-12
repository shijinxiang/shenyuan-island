shader_type spatial;
uniform float weather_daylight = 1.0;
uniform float weather_wetness = 0.0;
render_mode cull_disabled;
#include "res://shaders/island_biome.gdshaderinc"
uniform vec4 base_color:source_color=vec4(.51,.65,.36,1);
uniform vec4 coastal_grass:source_color=vec4(.51,.65,.36,1);
uniform float coast[41];
uniform vec2 outer_center;
uniform float outer_radius[180];
uniform float outer_beach[180];
uniform bool lagoon_patch_enabled=false;
uniform vec4 lagoon_patch_rim:source_color=vec4(.6343,.6422,.6343,1.);
uniform vec4 lagoon_patch_grass:source_color=vec4(.5137,.651,.3608,1.);
uniform vec4 lagoon_patch_sand:source_color=vec4(.8471,.7608,.5961,1.);
varying vec3 pos;
uniform sampler2D swe_global_state : repeat_disable, filter_linear;
uniform sampler2D swe_global_terrain : repeat_disable, filter_linear;
uniform vec2 swe_origin=vec2(-400.);
uniform float swe_extent=800.;
uniform bool swe_ready=false;
void vertex(){pos=(MODEL_MATRIX*vec4(VERTEX,1)).xyz;}
float hash21(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float soft_noise(vec2 p){
 vec2 i=floor(p);vec2 f=fract(p);f=f*f*(3.-2.*f);
 return mix(mix(hash21(i),hash21(i+vec2(1,0)),f.x),mix(hash21(i+vec2(0,1)),hash21(i+vec2(1,1)),f.x),f.y);
}
void fragment(){
 vec2 op=pos.xz-outer_center;float af=mod(atan(op.y,op.x)+6.283185307,6.283185307)*180./6.283185307;
 int oi=int(af);int oj=(oi+1)%180;float shore=mix(outer_radius[oi],outer_radius[oj],fract(af))-length(op);
 float beach=mix(outer_beach[oi],outer_beach[oj],fract(af));
 float width=13.+3.*sin(pos.x*.037+pos.z*.021)+2.*sin(pos.z*.061-pos.x*.013);
 float sand_mask=1.-smoothstep(.55,2.8,max(pos.y,0.));
 float variation=.96+.025*sin(pos.x*.21+pos.z*.11)*sin(pos.z*.17);
 // Warm beige, moderated from the original bright yellow band.
 vec3 sand=vec3(.82,.74,.57)*variation;
 // Continuous coastal grass base prevents old exposed-rock material stripes.
 float coastal_blend=(1.-smoothstep(30.,50.,abs(shore)))*beach;
 vec3 base=biome_grass(coastal_grass.rgb,pos.xz);
 float rocky=(1.-beach)*(1.-smoothstep(8.,34.,abs(shore)));
 base=mix(base,vec3(.24,.255,.205)*variation,rocky*.88);
 ALBEDO=mix(base,sand,sand_mask);
 float wet_limit=.16+.08*(soft_noise(pos.xz*.65)-.5);
 float lake_mask=0.;
 if(swe_ready){
  vec2 simulation_uv=(pos.xz-swe_origin)/swe_extent;
  vec4 state=texture(swe_global_state,simulation_uv);
  vec4 ground=texture(swe_global_terrain,simulation_uv);
  if(state.r>.008) wet_limit=max(wet_limit,state.r+ground.r+.08);
  lake_mask=ground.a;
 }
 float wet=1.-smoothstep(wet_limit,wet_limit+.20,max(pos.y,0.));
 ALBEDO*=1.-wet*.10*sand_mask;
 if(pos.y<=0.01) {
  vec2 q=pos.xz*.65;
  q+=vec2(sin(q.y*.83+TIME*.25),cos(q.x*.71-TIME*.23))*.14;
  vec2 k1=vec2(2.2,.7),k2=vec2(-1.15,2.65),k3=vec2(3.75,-1.7),k4=vec2(.55,4.3);
  vec3 h=-.15*cos(dot(q,k1)+TIME*.63)*vec3(k1.x*k1.x,k1.y*k1.y,k1.x*k1.y);
  h-=.12*cos(dot(q,k2)-TIME*.81)*vec3(k2.x*k2.x,k2.y*k2.y,k2.x*k2.y);
  h-=.035*cos(dot(q,k3)+TIME*1.04)*vec3(k3.x*k3.x,k3.y*k3.y,k3.x*k3.y);
  h-=.025*cos(dot(q,k4)-TIME*.91)*vec3(k4.x*k4.x,k4.y*k4.y,k4.x*k4.y);
  float focus=clamp(-pos.y,.4,3.4)*.65;
  float determinant=(1.-focus*h.x)*(1.-focus*h.y)-focus*focus*h.z*h.z;
  float width=max(fwidth(determinant)*.85,.10);
  float threads=pow(width/(abs(determinant)+width),1.55);
  float fade=smoothstep(.10,.48,-pos.y)*(1.-smoothstep(3.8,7.,-pos.y));
  EMISSION=vec3(.43,.69,.66)*threads*.48*weather_daylight*fade*(1.-lake_mask*.94);
 }
 ALBEDO*=1.-weather_wetness*.12;
 ROUGHNESS=mix(.93,.36,max(wet,weather_wetness));SPECULAR=.20;
}






