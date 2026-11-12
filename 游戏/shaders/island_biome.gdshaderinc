uniform sampler2D forest_mask : filter_linear,repeat_disable;
uniform vec2 forest_mask_origin=vec2(-260.);
uniform vec2 forest_mask_size=vec2(520.);
uniform vec3 forest_grass_color : source_color=vec3(.34,.50,.27);
uniform vec3 forest_middle_color : source_color=vec3(.43,.57,.31);
uniform vec3 meadow_grass_color : source_color=vec3(.51,.65,.36);
float forest_blend(vec2 world_xz){
    return texture(forest_mask,(world_xz-forest_mask_origin)/forest_mask_size).r;
}
vec3 biome_grass(vec3 base,vec2 world_xz){
    float value=forest_blend(world_xz);
    vec3 middle=mix(base,forest_middle_color,smoothstep(0.,.57,value));
    return mix(middle,forest_grass_color,smoothstep(.45,1.,value));
}
