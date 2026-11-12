extends Node

const COMPUTE_SHADER_PATH := "res://shaders/shallow_water_solver.glsl"
const DATA_FOLDER := "res://assets/generated/shallow_water/"
const GLOBAL_STEP := 1.0 / 30.0
const LOCAL_SUBSTEPS := 4
const WARMUP_SECONDS := 90.0

var wind_direction := Vector2(-0.6111623, -0.7915053)
var incoming_amplitude := 0.65
var simulation_time := 0.0
var warmup_remaining := int(WARMUP_SECONDS / GLOBAL_STEP)
var ready_for_render := false
var initialized := false
var in_flight := false
var pending_time := 0.0
var validation_enabled := false
var validation_dumped := false

var device: RenderingDevice
var shader_rid := RID()
var pipeline_rid := RID()
var domains: Array[Dictionary] = []
var definitions: Dictionary
var water_material: ShaderMaterial
var scene_root: Node3D
var texture_resources: Array[Texture2DRD] = []
var owned_rids: Array[RID] = []
var boat_sampling_position := Vector2(153.3,128.7)
var boat_elevation := 0.0
var boat_gradient := Vector2.ZERO
var boat_sample_valid := false
var boat_target_elevation := 0.0
var boat_target_gradient := Vector2.ZERO
var player_sampling_position := Vector2.ZERO
var player_elevation := 0.0
var player_target_elevation := 0.0
var next_boat_sample_time := 0.0

func _ready() -> void:
	definitions = JSON.parse_string(FileAccess.get_file_as_string(DATA_FOLDER + "domains.json"))
	RenderingServer.call_on_render_thread(_initialize_compute)

func _new_texture(bytes: PackedByteArray, resolution: int) -> RID:
	var format := RDTextureFormat.new()
	format.width = resolution
	format.height = resolution
	format.texture_type = RenderingDevice.TEXTURE_TYPE_2D
	format.format = RenderingDevice.DATA_FORMAT_R32G32B32A32_SFLOAT
	format.usage_bits = RenderingDevice.TEXTURE_USAGE_STORAGE_BIT | RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT | RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT | RenderingDevice.TEXTURE_USAGE_CAN_COPY_TO_BIT | RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT
	var texture := device.texture_create(format, RDTextureView.new(), [bytes])
	owned_rids.append(texture)
	return texture

func _create_domain(name: String, terrain_file: String) -> Dictionary:
	var definition: Dictionary = definitions["global" if name == "global" else "local"]
	var terrain_bytes := FileAccess.get_file_as_bytes(DATA_FOLDER + terrain_file)
	var ground := terrain_bytes.to_float32_array()
	var initial := PackedFloat32Array()
	initial.resize(ground.size())
	initial.fill(0.0)
	for index in range(0, ground.size(), 4):
		if ground[index + 1] < 0.5:
			initial[index] = maxf(-ground[index], 0.0)
	var initial_bytes := initial.to_byte_array()
	var resolution := int(definition["size"])
	return {
		"name":name,
		"resolution":resolution,
		"origin":Vector2(definition.origin[0], definition.origin[1]),
		"spacing":float(definition.spacing),
		"extent":float(definition.extent),
		"terrain":_new_texture(terrain_bytes, resolution),
		"bed_values":ground,
		"state":[_new_texture(initial_bytes, resolution), _new_texture(initial_bytes, resolution)],
		"display":_new_texture(initial_bytes, resolution),
		"current":0,
		"uniform_sets":[]
	}

func _create_uniform_sets(domain: Dictionary) -> void:
	var uniform_sets: Array[RID] = []
	for previous in 2:
		for coarse in 2:
			var images := [domain.state[previous], domain.state[1 - previous], domain.terrain, domains[0].state[coarse], domains[0].terrain]
			var uniforms: Array[RDUniform] = []
			for binding in images.size():
				var uniform := RDUniform.new()
				uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
				uniform.binding = binding
				uniform.add_id(images[binding])
				uniforms.append(uniform)
			var uniform_set := device.uniform_set_create(uniforms, shader_rid, 0)
			uniform_sets.append(uniform_set)
			owned_rids.append(uniform_set)
	domain.uniform_sets = uniform_sets

func _initialize_compute() -> void:
	device = RenderingServer.get_rendering_device()
	if device == null:
		push_error("Realtime shallow water requires a RenderingDevice renderer")
		return
	var shader_file := load(COMPUTE_SHADER_PATH) as RDShaderFile
	if shader_file == null:
		push_error("Shallow-water compute shader could not be loaded")
		return
	shader_rid = device.shader_create_from_spirv(shader_file.get_spirv())
	pipeline_rid = device.compute_pipeline_create(shader_rid)
	owned_rids.append(shader_rid)
	owned_rids.append(pipeline_rid)
	domains.append(_create_domain("global", "global_terrain.bin"))
	domains.append(_create_domain("local", "local_terrain.bin"))
	if validation_enabled:
		domains.append(_create_domain("control_without_piles", "local_without_piles.bin"))
	for domain in domains:
		_create_uniform_sets(domain)
	_bind_render_textures.call_deferred()

func _as_texture(rid: RID) -> Texture2DRD:
	var texture := Texture2DRD.new()
	texture.texture_rd_rid = rid
	texture_resources.append(texture)
	return texture

func _bind_render_textures() -> void:
	var global_state := _as_texture(domains[0].display)
	var global_terrain := _as_texture(domains[0].terrain)
	var local_state := _as_texture(domains[1].display)
	var local_terrain := _as_texture(domains[1].terrain)
	water_material.set_shader_parameter("swe_global_state", global_state)
	water_material.set_shader_parameter("swe_global_terrain", global_terrain)
	water_material.set_shader_parameter("swe_local_state", local_state)
	water_material.set_shader_parameter("swe_local_terrain", local_terrain)
	water_material.set_shader_parameter("global_origin", domains[0].origin)
	water_material.set_shader_parameter("global_extent", domains[0].extent)
	water_material.set_shader_parameter("local_origin", domains[1].origin)
	water_material.set_shader_parameter("local_extent", domains[1].extent)
	water_material.set_shader_parameter("wind_direction", wind_direction)
	water_material.set_shader_parameter("incoming_amplitude", incoming_amplitude)
	water_material.set_shader_parameter("swe_ready", true)
	for mesh in scene_root.find_children("*", "MeshInstance3D", true, false):
		if mesh.name == "ShoreSeabed" or mesh.name.begins_with("TERRAIN"):
			var materials: Array[Material] = []
			if mesh.material_override:
				materials.append(mesh.material_override)
			else:
				for surface in mesh.mesh.get_surface_count():
					materials.append(mesh.get_active_material(surface))
			for material in materials:
				if material is ShaderMaterial:
					material.set_shader_parameter("swe_global_state", global_state)
					material.set_shader_parameter("swe_global_terrain", global_terrain)
					material.set_shader_parameter("swe_origin", domains[0].origin)
					material.set_shader_parameter("swe_extent", domains[0].extent)
					material.set_shader_parameter("swe_ready", true)
	initialized = true
	print("SHALLOW_WATER_INITIALIZED global=384 local=384 local_dx=0.333m wind=", wind_direction)

func _dispatch(compute_list: int, domain: Dictionary, dt: float, time: float) -> void:
	var origin: Vector2 = domain.origin
	var coarse_origin: Vector2 = domains[0].origin
	var constants := PackedFloat32Array([
		origin.x, origin.y, domain.spacing, dt,
		time, wind_direction.x, wind_direction.y, 0.0 if domain.name == "global" else 1.0,
		coarse_origin.x, coarse_origin.y, domains[0].spacing, domains[0].resolution,
		domain.resolution, incoming_amplitude, 9.81, 0.0
	]).to_byte_array()
	var set_index: int = domain.current * 2 + domains[0].current
	device.compute_list_bind_uniform_set(compute_list, domain.uniform_sets[set_index], 0)
	device.compute_list_set_push_constant(compute_list, constants, constants.size())
	device.compute_list_dispatch(compute_list, ceili(domain.resolution / 8.0), ceili(domain.resolution / 8.0), 1)
	device.compute_list_add_barrier(compute_list)
	domain.current = 1 - domain.current

func _advance(steps: int) -> void:
	var compute_list := device.compute_list_begin()
	device.compute_list_bind_compute_pipeline(compute_list, pipeline_rid)
	for step in steps:
		_dispatch(compute_list, domains[0], GLOBAL_STEP, simulation_time)
		for substep in LOCAL_SUBSTEPS:
			for index in range(1, domains.size()):
				_dispatch(compute_list, domains[index], GLOBAL_STEP / LOCAL_SUBSTEPS, simulation_time + substep * GLOBAL_STEP / LOCAL_SUBSTEPS)
		simulation_time += GLOBAL_STEP
	device.compute_list_end()
	for domain in domains:
		device.texture_copy(domain.state[domain.current], domain.display, Vector3.ZERO, Vector3.ZERO, Vector3(domain.resolution,domain.resolution,1), 0,0,0,0)
	if ready_for_render and simulation_time >= next_boat_sample_time:
		_sample_boat()
		next_boat_sample_time = simulation_time + .2
	_frame_finished.call_deferred(simulation_time, steps)

func _height_from_bytes(bytes: PackedByteArray, position: Vector2, domain_index := 1) -> float:
	var domain: Dictionary = domains[domain_index]
	var coordinate: Vector2 = (position - domain.origin) / domain.spacing - Vector2(.5,.5)
	var cell := Vector2i(coordinate.floor())
	var blend := coordinate - Vector2(cell)
	var elevations: Array[float] = []
	for offset in [Vector2i(0,0),Vector2i(1,0),Vector2i(0,1),Vector2i(1,1)]:
		var point: Vector2i = (cell + offset).clamp(Vector2i.ZERO,Vector2i(domain.resolution - 1,domain.resolution - 1))
		var index: int = point.y * domain.resolution + point.x
		var water_depth:=bytes.decode_float(index*16)
		elevations.append(water_depth+domain.bed_values[index*4] if water_depth>.005 else 0.0)
	return lerpf(lerpf(elevations[0],elevations[1],blend.x),lerpf(elevations[2],elevations[3],blend.x),blend.y)

func _sample_boat() -> void:
	var boat_index:=1 if Rect2(88,72,128,128).has_point(boat_sampling_position) else 0
	var domain: Dictionary = domains[boat_index]
	var bytes := device.texture_get_data(domain.state[domain.current],0)
	var elevation := _height_from_bytes(bytes,boat_sampling_position,boat_index)
	var slope_x := (_height_from_bytes(bytes,boat_sampling_position+Vector2(1,0),boat_index) - _height_from_bytes(bytes,boat_sampling_position-Vector2(1,0),boat_index)) / 2.0
	var slope_z := (_height_from_bytes(bytes,boat_sampling_position+Vector2(0,1),boat_index) - _height_from_bytes(bytes,boat_sampling_position-Vector2(0,1),boat_index)) / 2.0
	_set_boat_sample.call_deferred(elevation,Vector2(slope_x,slope_z))
	var point := player_sampling_position
	var player_index:=1 if Rect2(88,72,128,128).has_point(point) else 0
	if player_index==boat_index:
		_set_player_sample.call_deferred(_height_from_bytes(bytes,point,player_index))
	else:
		var player_domain:Dictionary=domains[player_index]
		var player_bytes:=device.texture_get_data(player_domain.state[player_domain.current],0)
		_set_player_sample.call_deferred(_height_from_bytes(player_bytes,point,player_index))

func _set_player_sample(elevation:float) -> void:
	player_target_elevation=clampf(elevation,-1.2,1.5)

func _set_boat_sample(elevation: float, gradient: Vector2) -> void:
	boat_target_elevation = elevation
	boat_target_gradient = gradient
	boat_sample_valid = true

func _frame_finished(time: float, steps: int) -> void:
	in_flight = false
	water_material.set_shader_parameter("simulation_time", time)
	if warmup_remaining > 0:
		warmup_remaining = maxi(0, warmup_remaining - steps)
		if warmup_remaining == 0:
			ready_for_render = true
			print("SHALLOW_WATER_READY time=", time)
			if validation_enabled and not validation_dumped:
				validation_dumped = true
				request_snapshot("validation")

func _process(delta: float) -> void:
	if is_instance_valid(scene_root):
		var player:=scene_root.get_node_or_null("Player") as Node3D
		if player:player_sampling_position=Vector2(player.global_position.x,player.global_position.z)
		var boat:Node3D=scene_root.boat
		if is_instance_valid(boat):boat_sampling_position=Vector2(boat.global_position.x,boat.global_position.z)
	player_elevation=lerpf(player_elevation,player_target_elevation,1.0-exp(-delta*8.0))
	boat_elevation = lerpf(boat_elevation,boat_target_elevation,1.0-exp(-delta*7.0))
	boat_gradient = boat_gradient.lerp(boat_target_gradient,1.0-exp(-delta*7.0))
	if not initialized:
		return
	if warmup_remaining <= 0:
		pending_time = minf(pending_time + delta, .2)
	if in_flight:
		return
	var steps: int
	if warmup_remaining > 0:
		steps = mini(24, warmup_remaining)
	else:
		steps = mini(int(pending_time / GLOBAL_STEP), 6)
		pending_time -= steps * GLOBAL_STEP
	if steps > 0:
		in_flight = true
		RenderingServer.call_on_render_thread(_advance.bind(steps))

func request_snapshot(label: String) -> void:
	RenderingServer.call_on_render_thread(_write_snapshot.bind(label))

func _write_snapshot(label: String) -> void:
	var report_base := "res://../整理记录/运行诊断/浅水模拟/" if OS.has_feature("editor") else "user://diagnostics/shallow_water/"
	var folder := ProjectSettings.globalize_path(report_base + label)
	DirAccess.make_dir_recursive_absolute(folder)
	for domain in domains:
		var bytes := device.texture_get_data(domain.state[domain.current], 0)
		FileAccess.open(folder + "/" + domain.name + "_state.bin", FileAccess.WRITE).store_buffer(bytes)
	FileAccess.open(folder + "/time.json", FileAccess.WRITE).store_string(JSON.stringify({"simulation_time":simulation_time,"wind":[wind_direction.x,wind_direction.y],"period":14.0,"amplitude":incoming_amplitude}))
	print("SHALLOW_WATER_SNAPSHOT ", label)

func _exit_tree() -> void:
	set_process(false)
	for texture in texture_resources:
		texture.texture_rd_rid = RID()
	if device:
		RenderingServer.call_on_render_thread(_release_resources)

func _release_resources() -> void:
	for index in range(owned_rids.size() - 1, -1, -1):
		if owned_rids[index].is_valid():
			device.free_rid(owned_rids[index])
	owned_rids.clear()
