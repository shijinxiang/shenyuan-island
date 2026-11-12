extends RefCounted
const Utility=preload("res://scripts/core/island_static_setup.gd")
static func setup(scene:Node3D) -> void:
	if scene.get_meta("forest_biome_version",0)==1:return
	var image:=Image.create_from_data(1024,1024,false,Image.FORMAT_R8,FileAccess.get_file_as_bytes("res://assets/generated/forest_mask.bin"))
	var texture:=ImageTexture.create_from_image(image)
	var materials:Dictionary={}
	for mesh in Utility.meshes(scene):
		for surface in mesh.mesh.get_surface_count():
			var material:=mesh.get_active_material(surface)
			if material is ShaderMaterial and material.shader.resource_path in ["res://shaders/shore_sand.gdshader","res://shaders/island_trail.gdshader"]:
				materials[material.get_instance_id()]=material
	for chunk in scene.get_node("IslandGrass").get_children():
		if chunk.material_override is ShaderMaterial:materials[chunk.material_override.get_instance_id()]=chunk.material_override
	for material in materials.values():material.set_shader_parameter("forest_mask",texture)
	scene.set_meta("forest_biome_version",1)
