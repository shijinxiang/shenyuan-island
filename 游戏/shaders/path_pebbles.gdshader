shader_type spatial;
uniform vec3 stone_colour : source_color=vec3(.59,.58,.51);
varying float shade;
void vertex(){shade=mix(.86,1.09,INSTANCE_CUSTOM.y);}
void fragment(){ALBEDO=stone_colour*shade;ROUGHNESS=.96;SPECULAR=.08;}
