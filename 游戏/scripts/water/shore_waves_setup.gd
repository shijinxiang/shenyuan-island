extends RefCounted

const WATER_SHADER = preload("res://shaders/physical_water.gdshader")
const DATA_FOLDER := "res://assets/generated/shallow_water/"

static func create_surface() -> ArrayMesh:
	var raw := FileAccess.get_file_as_bytes(DATA_FOLDER + "water_vertices.bin").to_float32_array()
	var vertices := PackedVector3Array()
	vertices.resize(raw.size() / 3)
	for index in vertices.size():
		vertices[index] = Vector3(raw[index * 3], raw[index * 3 + 1], raw[index * 3 + 2])
	var normals := PackedVector3Array()
	normals.resize(vertices.size())
	normals.fill(Vector3.UP)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = FileAccess.get_file_as_bytes(DATA_FOLDER + "water_indices.bin").to_int32_array()
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

static func setup(scene: Node3D) -> void:
	var ocean := scene.find_child("W02*", true, false) as MeshInstance3D
	if ocean == null or not ocean.material_override is ShaderMaterial:
		push_error("Shallow water requires the existing ocean material")
		return
	var material := ocean.material_override as ShaderMaterial
	material.shader = WATER_SHADER
	if ocean.get_meta("wave_grid_version", 0) != 2:
		ocean.mesh = create_surface()
		ocean.global_transform = Transform3D.IDENTITY
		ocean.extra_cull_margin = 2.5
		ocean.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ocean.set_meta("wave_grid_version", 2)
	var far_ocean := scene.get_node_or_null("FarOcean") as MeshInstance3D
	if far_ocean:
		far_ocean.visible = false
	if RenderingServer.get_current_rendering_method() == "mobile":
		scene.get_node("Sun").light_energy = .85
		scene.get_node("WorldEnvironment").environment.ambient_light_energy = .50
	if not scene.has_node("ShallowWaterSimulation"):
		var simulation = load("res://scripts/water/shallow_water_simulation.gd").new()
		simulation.name = "ShallowWaterSimulation"
		simulation.scene_root = scene
		simulation.water_material = material
		simulation.validation_enabled = false
		scene.add_child(simulation)
	scene.set_meta("shore_waves_ready", true)
