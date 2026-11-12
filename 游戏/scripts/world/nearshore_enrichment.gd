extends RefCounted
const Utility=preload("res://scripts/core/island_static_setup.gd")

static func build() -> Node3D:
	var group:=Node3D.new()
	group.name="NearshoreEnrichment"
	var rows:Array=JSON.parse_string(FileAccess.get_file_as_string("res://assets/generated/nearshore_enrichment.json"))
	var by_asset:Dictionary={}
	for row:Dictionary in rows:
		if not by_asset.has(row.id):by_asset[row.id]=[]
		by_asset[row.id].append(row)
	for code:String in by_asset:
		var instances:Array=by_asset[code]
		var model:=Utility.local_model(instances[0].res_path)
		model.set_meta("asset_id",code)
		Utility.style(model,instances[0].category)
		var bounds:=Utility.bounds(model)
		var centering:=Transform3D(Basis.IDENTITY,Vector3(-bounds.get_center().x,-bounds.position.y,-bounds.get_center().z))
		var native_size:=maxf(bounds.size.x,maxf(bounds.size.y,bounds.size.z))
		for mesh:MeshInstance3D in Utility.meshes(model):
			var local_transform:=centering*Utility.world_transform(mesh)
			var multi:=MultiMesh.new()
			multi.transform_format=MultiMesh.TRANSFORM_3D
			multi.mesh=mesh.mesh.duplicate()
			for surface in mesh.mesh.get_surface_count():multi.mesh.surface_set_material(surface,mesh.get_active_material(surface))
			multi.instance_count=instances.size()
			for index in instances.size():
				var row:Dictionary=instances[index]
				var normal:=Vector3(row.normal[0],row.normal[1],row.normal[2]).normalized()
				var tangent:=Vector3.FORWARD.cross(normal).normalized()
				var basis:=Basis(tangent,normal,tangent.cross(normal).normalized())*Basis(Vector3.UP,row.yaw)
				basis=basis.scaled(Vector3.ONE*float(row.size)/native_size)
				var position:=Vector3(row.position[0],row.position[1],row.position[2])-normal*float(row.embed)
				var transform:=Transform3D(basis,position)*local_transform
				multi.set_instance_transform(index,transform)
				if row.large:
					var body:=StaticBody3D.new()
					body.name=code+"_SeabedRock_"+str(index)
					body.transform=transform
					var collision:=CollisionShape3D.new()
					collision.shape=mesh.mesh.create_trimesh_shape()
					body.add_child(collision)
					group.add_child(body)
			var batch:=MultiMeshInstance3D.new()
			batch.name=code+"_"+str(group.get_child_count())
			batch.multimesh=multi
			batch.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			group.add_child(batch)
		model.free()
	group.set_meta("added_instances",rows.size())
	return group

static func setup(scene:Node3D) -> void:
	if scene.has_node("NearshoreEnrichment"):return
	var group:=build()
	scene.add_child(group)
	print("NEARSHORE_ENRICHED ",group.get_meta("added_instances"))
