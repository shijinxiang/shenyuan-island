extends RefCounted

static func setup(scene:Node3D) -> void:
	var field:=scene.get_node_or_null("IslandGrass")
	if field==null:
		var resource:=load("res://assets/vegetation/stylized_grass/island_grass.scn") as PackedScene
		if resource == null:
			push_error("Island grass resource is missing")
			return
		field=resource.instantiate()
		field.name="IslandGrass"
		scene.add_child(field)
		field.owner=scene
	var simulation:=scene.get_node_or_null("ShallowWaterSimulation")
	if simulation:
		var seen:Dictionary={}
		for chunk in field.get_children():
			var material:ShaderMaterial=chunk.material_override
			if not seen.has(material.get_instance_id()):
				material.set_shader_parameter("wind_direction",simulation.wind_direction)
				seen[material.get_instance_id()]=true
		field.set_meta("wind_direction",simulation.wind_direction)
