extends SceneTree
func _initialize() -> void:
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	assert(doc.append_from_file("D:/浪费GPT额度/小温的游戏/游戏/assets/survival/bedside_table.glb",state)==OK)
	var instance := doc.generate_scene(state)
	var meshes := instance.find_children("*","MeshInstance3D",true,false)
	assert(meshes.size()==1)
	var mesh := meshes[0] as MeshInstance3D
	var box := mesh.get_aabb()
	assert(absf(box.position.y)<.0001 and absf(box.size.y-.60)<.0001)
	assert(mesh.transform.is_equal_approx(Transform3D.IDENTITY))
	for i in range(mesh.mesh.get_surface_count()):
		assert(mesh.mesh.surface_get_material(i)!=null)
		assert(mesh.mesh.surface_get_arrays(i)[Mesh.ARRAY_TEX_UV]!=null)
	print("BEDSIDE_GODOT_PASS size=",box.size," min=",box.position," surfaces=",mesh.mesh.get_surface_count())
	instance.free()
	quit()
