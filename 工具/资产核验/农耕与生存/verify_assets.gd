extends SceneTree

var failures: Array[String] = []
var report: Dictionary = {}

func _initialize() -> void:
	var names: Array[String] = ["axe", "hoe", "watering_can", "log", "stump", "soil_plot"]
	for crop in ["turnip", "tomato", "pumpkin"]:
		for stage in range(4):
			names.append("%s_stage_%d" % [crop, stage])
	for asset_name in names:
		var packed := load("res://assets/farming/%s.glb" % asset_name) as PackedScene
		if packed == null:
			failures.append(asset_name + ": cannot load")
			continue
		var instance := packed.instantiate()
		var meshes: Array[MeshInstance3D] = []
		_collect_meshes(instance, meshes)
		var asset_report := {"mesh_count": meshes.size(), "meshes": []}
		if meshes.size() != 1:
			failures.append(asset_name + ": expected one joined mesh")
		for mi in meshes:
			var m := mi.mesh
			var mesh_report := {"name": str(mi.name), "surfaces": m.get_surface_count(), "vertices": 0, "triangles": 0, "has_uv": true, "has_materials": true, "transform_identity": mi.transform.is_equal_approx(Transform3D.IDENTITY)}
			if not mesh_report.transform_identity:
				failures.append(asset_name + ": nonidentity mesh transform")
			for s in range(m.get_surface_count()):
				var arr := m.surface_get_arrays(s)
				var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
				var uv: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
				var indices: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
				mesh_report.vertices += verts.size()
				mesh_report.triangles += indices.size() / 3 if not indices.is_empty() else verts.size() / 3
				mesh_report.has_uv = mesh_report.has_uv and uv.size() == verts.size()
				mesh_report.has_materials = mesh_report.has_materials and m.surface_get_material(s) != null
				for v in verts:
					if not v.is_finite(): failures.append(asset_name + ": invalid vertex")
			var box := m.get_aabb()
			mesh_report.aabb_min = [box.position.x, box.position.y, box.position.z]
			mesh_report.aabb_size = [box.size.x, box.size.y, box.size.z]
			if absf(box.position.y) > 0.0001: failures.append(asset_name + ": floor is not y=0")
			if not mesh_report.has_uv: failures.append(asset_name + ": missing UV")
			if not mesh_report.has_materials: failures.append(asset_name + ": missing material")
			if asset_name == "soil_plot":
				if box.size.y < 0.08 or box.size.y > 0.13: failures.append("soil thickness out of range")
				var mat := m.surface_get_material(0) as StandardMaterial3D
				if mat == null or mat.albedo_texture == null: failures.append("soil missing embedded texture")
			asset_report.meshes.append(mesh_report)
		report[asset_name] = asset_report
		instance.free()
	for state in ["dry", "wet"]:
		var mat := load("res://assets/farming/soil_%s.tres" % state) as StandardMaterial3D
		if mat == null or mat.albedo_texture == null or mat.roughness_texture == null:
			failures.append("missing soil state: " + state)
	report["failures"] = failures
	report["passed"] = failures.is_empty()
	var arguments := OS.get_cmdline_user_args()
	var output := arguments[0] if not arguments.is_empty() else "res://../整理记录/运行诊断/农耕模型核验.json"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output.get_base_dir()))
	var file := FileAccess.open(output, FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	print("FARMING_IMPORT_VALIDATION ", "PASS" if failures.is_empty() else "FAIL", " assets=", names.size(), " failures=", failures)
	quit(0 if failures.is_empty() else 1)

func _collect_meshes(node: Node, result: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		result.append(node)
	for child in node.get_children():
		_collect_meshes(child, result)
