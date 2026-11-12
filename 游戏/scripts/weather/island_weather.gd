extends Node3D

const Utility = preload("res://scripts/core/island_static_setup.gd")
const WIND := Vector3(-0.6111623, 0.0, -0.7915053)
const WEATHER_NAMES := ["晴天", "阴天", "下雨", "雷暴"]
var hour := 11.0
var daylight := 1.0
var rain_amount := 0.0
var current_weather := 0
var cloud_cover := 0.12
var elapsed := 0.0
var next_weather := 480.0
var update_timer := 0.0
var shelter_timer := 0.0
var sheltered := false
var world: Node3D
var player: Node3D
var sun: DirectionalLight3D
var moon: DirectionalLight3D
var flash_light: DirectionalLight3D
var environment: Environment
var sky_material: ShaderMaterial
var controller: WeatherController3D
var rain: NimbluxRain3D
var rain_anchor: Node3D
var profiles: Array[WeatherProfile] = []
var cloud_nodes: Array[Node3D] = []
var cloud_materials: Array[StandardMaterial3D] = []
var ground_materials: Array[ShaderMaterial] = []
var water_material: ShaderMaterial
var simulation: Node
var rain_audio: AudioStreamPlayer
var thunder_audio: AudioStreamPlayer
var status: Label
var selection: OptionButton
var flash_tween: Tween
var bolt: Node3D
var rng := RandomNumberGenerator.new()
var fog_material: ShaderMaterial
var fog_density := 0.0

func _ready() -> void:
	rng.seed = 61106
	world = get_parent()
	player = world.get_node("Player")
	sun = world.get_node("Sun")
	var world_environment: WorldEnvironment = world.get_node("WorldEnvironment")
	environment = world_environment.environment.duplicate()
	world_environment.environment = environment
	_setup_sky()
	_setup_controller()
	_setup_volume_fog()
	_setup_clouds()
	_setup_rain()
	_setup_audio()
	_setup_controls()
	simulation = world.get_node_or_null("ShallowWaterSimulation")
	var ocean := world.find_child("W02*", true, false) as MeshInstance3D
	if ocean: water_material = ocean.material_override
	var seen := {}
	for mesh: MeshInstance3D in Utility.meshes(world):
		if mesh.mesh == null: continue
		for surface in mesh.mesh.get_surface_count():
			var material := mesh.get_active_material(surface) as ShaderMaterial
			if material and not seen.has(material.get_instance_id()):
				seen[material.get_instance_id()] = true
				if material.shader and ("shore_sand" in material.shader.resource_path or "island_grass" in material.shader.resource_path or "island_trail" in material.shader.resource_path):
					ground_materials.append(material)
	for grass: MultiMeshInstance3D in world.find_children("*", "MultiMeshInstance3D", true, false):
		var material := grass.material_override as ShaderMaterial
		if material and material.shader and "island_grass" in material.shader.resource_path and not ground_materials.has(material):
			ground_materials.append(material)
	set_weather(0, 0.1)
	_update_environment(1.0)
	print("ISLAND_WEATHER_READY sunny/overcast/rain/thunderstorm day/night")

func _setup_sky() -> void:
	sky_material = ShaderMaterial.new()
	sky_material.shader = preload("res://shaders/island_weather_sky.gdshader")
	for pair in [["day_sky", "day_fair"], ["night_sky", "night_full_moon"], ["dusk_sky", "sunset_orange"], ["cloudy_sky", "overcast_grey"]]:
		sky_material.set_shader_parameter(pair[0], load("res://addons/low_poly_skies/skies/" + pair[1] + ".png"))
	var sky := Sky.new()
	sky.sky_material = sky_material
	sky.process_mode = Sky.PROCESS_MODE_REALTIME
	sky.radiance_size = Sky.RADIANCE_SIZE_256
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.fog_enabled = false
	environment.volumetric_fog_enabled = true
	environment.volumetric_fog_density = 0.0
	environment.volumetric_fog_length = 240.0
	environment.volumetric_fog_detail_spread = 1.4
	environment.volumetric_fog_ambient_inject = 0.55
	environment.volumetric_fog_temporal_reprojection_enabled = true
	environment.volumetric_fog_temporal_reprojection_amount = 0.85
	moon = DirectionalLight3D.new()
	moon.name = "Moonlight"
	moon.rotation_degrees = Vector3(-48, 125, 0)
	moon.light_color = Color(0.48, 0.64, 0.92)
	moon.shadow_enabled = false
	add_child(moon)
	flash_light = DirectionalLight3D.new()
	flash_light.name = "LightningFlash"
	flash_light.light_color = Color(0.77, 0.86, 1.0)
	flash_light.light_energy = 0.0
	flash_light.rotation_degrees = Vector3(-65, -35, 0)
	add_child(flash_light)

func _setup_controller() -> void:
	controller = preload("res://addons/weather_atmosphere/core/weather_controller_3d.gd").new()
	controller.name = "WeatherAtmosphereController"
	controller.manage_environment = false
	controller.enable_forward_plus_volumetric_fog = true
	controller.quality = WeatherController3D.Quality.MEDIUM
	controller.camera = get_viewport().get_camera_3d()
	controller.effect_target = player
	for preset in ["clear_calm", "breezy_day", "steady_rain", "thunderstorm"]:
		var profile := load("res://addons/weather_atmosphere/presets/" + preset + ".tres").duplicate() as WeatherProfile
		profile.wind_direction = WIND
		profile.lightning_interval_min = 16.0
		profile.lightning_interval_max = 32.0
		profiles.append(profile)
	profiles[0].wind_speed = 2.0
	profiles[1].sun_energy_multiplier = 0.5
	profiles[1].fog_density = 0.006
	profiles[1].mist_intensity = 0.05
	profiles[2].wind_speed = 6.0
	profiles[3].wind_speed = 11.0
	controller.initial_profile = profiles[0]
	add_child(controller)
	var lightning := preload("res://addons/weather_atmosphere/components/lightning_3d.gd").new()
	controller.add_child(lightning)
	lightning.flash_started.connect(_lightning_flash)
	controller.thunder_requested.connect(_thunder)

func _setup_volume_fog() -> void:
	var noise := FastNoiseLite.new()
	noise.seed = 61106
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.08
	noise.fractal_octaves = 3
	var texture := NoiseTexture3D.new()
	texture.width = 64
	texture.height = 32
	texture.depth = 64
	texture.seamless = true
	texture.noise = noise
	fog_material = ShaderMaterial.new()
	fog_material.shader = preload("res://shaders/coastal_volume_fog.gdshader")
	fog_material.set_shader_parameter("density_noise", texture)
	var data := FileAccess.get_file_as_bytes("res://assets/generated/shallow_water/global_terrain.bin")
	var ground := ImageTexture.create_from_image(Image.create_from_data(384,384,false,Image.FORMAT_RGBAF,data))
	fog_material.set_shader_parameter("ground_height",ground)
	var volume := FogVolume.new()
	volume.name = "CoastalVolumetricFog"
	volume.shape = RenderingServer.FOG_VOLUME_SHAPE_BOX
	volume.size = Vector3(680,40,680)
	volume.position = Vector3(0,12,0)
	volume.material = fog_material
	add_child(volume)

func _setup_clouds() -> void:
	for i in 18:
		var cloud := load("res://addons/low_poly_skies/props/" + ("cloud_storm" if i % 3 == 0 else "cloud_cumulus") + ".tscn").instantiate() as Node3D
		add_child(cloud)
		for animation: AnimationPlayer in cloud.find_children("*", "AnimationPlayer", true, false): animation.stop()
		var bounds := Utility.bounds(cloud)
		var size := rng.randf_range(24.0, 48.0)
		cloud.scale *= size / maxf(bounds.size.x, 0.01)
		cloud.position = Vector3(rng.randf_range(-260, 260), rng.randf_range(38, 58), rng.randf_range(-260, 260))
		for mesh: MeshInstance3D in Utility.meshes(cloud):
			mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var material := StandardMaterial3D.new()
			material.albedo_color = Color(0.87, 0.91, 0.93)
			material.roughness = 1.0
			material.cull_mode = BaseMaterial3D.CULL_DISABLED
			mesh.material_override = material
			cloud_materials.append(material)
		cloud_nodes.append(cloud)
	bolt = load("res://addons/low_poly_skies/props/lightning.tscn").instantiate()
	add_child(bolt)
	for animation: AnimationPlayer in bolt.find_children("*", "AnimationPlayer", true, false): animation.stop()
	var bounds := Utility.bounds(bolt)
	bolt.scale *= 25.0 / maxf(bounds.size.y, 0.1)
	for mesh: MeshInstance3D in Utility.meshes(bolt):
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = Color(0.8, 0.9, 1.0)
		material.emission_enabled = true
		material.emission = Color(0.75, 0.85, 1.0)
		material.emission_energy_multiplier = 3.0
		mesh.material_override = material
	bolt.visible = false

func _setup_rain() -> void:
	rain_anchor = Node3D.new()
	add_child(rain_anchor)
	rain = preload("res://scripts/water/island_rain.gd").new()
	rain.name = "WindDrivenRain"
	rain.amount = 0.0
	rain.max_drops = 8500
	rain.max_ripples = 450
	rain.ripples = false
	rain.max_splashes = 500
	rain.splash_radius = 22.0
	rain.ripple_size = 0.25
	rain.splash_size = 0.18
	rain.follow_target = rain_anchor
	rain.follow_camera = false
	rain.area_size = Vector3(54, 32, 54)
	rain.drop_width = 0.020
	rain.drop_length = 0.065
	rain.color = Color(0.76, 0.83, 0.9, 0.65)
	rain.emission = 0.08
	add_child(rain)

func _setup_audio() -> void:
	rain_audio = AudioStreamPlayer.new()
	var stream := load("res://assets/fauna/ambience/rain.wav") as AudioStreamWAV
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = stream.data.size() / 2
	rain_audio.stream = stream
	rain_audio.volume_db = -80.0
	add_child(rain_audio)
	rain_audio.play()
	thunder_audio = AudioStreamPlayer.new()
	thunder_audio.stream = load("res://assets/fauna/ambience/thunder.wav")
	thunder_audio.volume_db = -8.0
	add_child(thunder_audio)

func _setup_controls() -> void:
	var layer := CanvasLayer.new()
	layer.name = "WeatherControls"
	add_child(layer)
	var panel := VBoxContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	panel.position = Vector2(-218, 16)
	panel.custom_minimum_size.x = 202
	layer.add_child(panel)
	status = Label.new()
	status.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	status.add_theme_constant_override("shadow_offset_x", 1)
	status.add_theme_constant_override("shadow_offset_y", 1)
	panel.add_child(status)
	selection = OptionButton.new()
	for i in WEATHER_NAMES.size(): selection.add_item(str(i + 4) + "  " + WEATHER_NAMES[i], i)
	selection.item_selected.connect(func(index: int): set_weather(index))
	panel.add_child(selection)
	var time_button := Button.new()
	time_button.text = "T  切换白天 / 黑夜"
	time_button.pressed.connect(toggle_time)
	panel.add_child(time_button)

func set_weather(index: int, duration := 9.0) -> void:
	current_weather = clampi(index, 0, 3)
	controller.transition_to(profiles[current_weather], duration)
	next_weather = 600.0
	if selection: selection.select(current_weather)

func toggle_time() -> void:
	hour = 22.0 if daylight > 0.5 else 10.0

func _unhandled_input(event: InputEvent) -> void:
	var game:=get_parent().get_node_or_null("IslandAdventure")
	if game==null or not game.creative():return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode >= KEY_4 and event.keycode <= KEY_7: set_weather(event.keycode - KEY_4)
		elif event.keycode == KEY_T: toggle_time()

func _process(delta: float) -> void:
	elapsed += delta
	var game:=get_parent().get_node_or_null("IslandAdventure")
	var multiplier:float=float(game.time_scale) if game and not game.cinematic_active else 1.0
	var next_hour:=hour+delta/60.0*multiplier
	if game and next_hour>=24.0:game.day_count+=int(next_hour/24.0)
	hour = fposmod(next_hour,24.0)
	next_weather -= delta*multiplier
	if next_weather <= 0.0: set_weather(rng.randi_range(0, 3), 25.0)
	controller.camera = get_viewport().get_camera_3d()
	rain_anchor.global_position = player.global_position + Vector3.UP * 9.0
	var state := controller.get_effective_state()
	var target_density: float = [0.0,0.006,0.008,0.014][current_weather]
	fog_density = move_toward(fog_density,target_density,delta*0.002)
	fog_material.set_shader_parameter("weather_density",fog_density)
	var active_camera := get_viewport().get_camera_3d()
	if active_camera: environment.volumetric_fog_length = maxf(200.0,active_camera.global_position.y+85.0)
	rain_amount = float(state.get("rain_intensity", 0.0))
	rain.amount = rain_amount * (0.0 if sheltered else 1.0)
	rain.horizontal_wind = controller.get_wind_velocity() * 0.32
	rain.fall_speed = lerpf(11.0, 18.0, rain_amount)
	rain_audio.volume_db = linear_to_db(maxf(0.0001, rain_amount * (0.18 if sheltered else 0.5)))
	for i in cloud_nodes.size():
		var cloud := cloud_nodes[i]
		cloud.position += WIND * delta * (0.5 + float(state.get("wind_speed", 2.0)) * 0.07)
		if cloud.position.x < -300: cloud.position.x += 600
		if cloud.position.z < -300: cloud.position.z += 600
		var camera := get_viewport().get_camera_3d()
		cloud.visible = i < int(lerpf(6.0, 18.0, cloud_cover)) and (camera == null or cloud.global_position.distance_to(camera.global_position) > 50.0)
	update_timer -= delta
	if update_timer <= 0.0:
		update_timer = 0.1
		_update_environment(0.1)

func _physics_process(delta: float) -> void:
	shelter_timer -= delta
	if shelter_timer > 0.0: return
	shelter_timer = 0.3
	var start := player.global_position + Vector3.UP * 1.75
	var query := PhysicsRayQueryParameters3D.create(start, start + Vector3.UP * 15.0, 1)
	query.exclude = [player.get_rid()]
	sheltered = not get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func _update_environment(delta: float) -> void:
	var solar_height := sin((hour - 6.0) / 24.0 * TAU)
	var target_day := smoothstep(-0.13, 0.25, solar_height)
	daylight = move_toward(daylight, target_day, delta * 0.35)
	var state := controller.get_effective_state()
	var cover_target: float = [0.12, 0.72, 0.86, 1.0][current_weather]
	cloud_cover = move_toward(cloud_cover, cover_target, delta * 0.075)
	var dusk := (1.0 - smoothstep(0.0, 0.40, absf(solar_height))) * daylight
	sky_material.set_shader_parameter("daylight", daylight)
	sky_material.set_shader_parameter("dusk", dusk)
	sky_material.set_shader_parameter("cloud_cover", cloud_cover)
	sun.rotation_degrees = Vector3(-maxf(6.0, solar_height * 66.0), (hour - 12.0) * 9.0 - 32.0, 0)
	sun.light_energy = daylight * 0.86 * float(state.get("sun_energy_multiplier", 1.0))
	sun.light_color = Color(1.0, 0.94, 0.82).lerp(Color(1.0, 0.64, 0.36), dusk * 0.6).lerp(Color(0.78, 0.84, 0.94), cloud_cover * 0.55)
	moon.light_energy = (1.0 - daylight) * lerpf(0.24, 0.12, cloud_cover)
	environment.ambient_light_color = Color(0.27, 0.39, 0.62).lerp(Color(0.80, 0.85, 0.88), daylight)
	environment.ambient_light_energy = lerpf(0.23, 0.52, daylight) * lerpf(1.0, 0.75, cloud_cover)
	environment.background_energy_multiplier = 1.0
	environment.fog_density = 0.0008 + float(state.get("fog_density", 0.0)) * 0.22
	environment.fog_light_color = Color(0.08, 0.14, 0.24).lerp(Color(0.63, 0.73, 0.78), daylight).lerp(Color(0.24, 0.29, 0.35), cloud_cover * 0.30)
	for material in cloud_materials:
		material.albedo_color = Color(0.92, 0.94, 0.95).lerp(Color(0.39, 0.44, 0.51), cloud_cover)
	var surface_light := lerpf(0.12, 1.0, daylight) * lerpf(1.0, 0.61, cloud_cover)
	if water_material:
		water_material.set_shader_parameter("weather_daylight", surface_light)
		water_material.set_shader_parameter("rain_intensity",rain_amount)
		water_material.set_shader_parameter("rain_time",elapsed)
		rain.water_material = water_material
	for material in ground_materials:
		material.set_shader_parameter("weather_daylight", surface_light)
		material.set_shader_parameter("weather_wetness", rain_amount * 0.7)
		material.set_shader_parameter("wind_strength", 0.24 + float(state.get("wind_speed", 2.0)) * 0.035)
	if is_instance_valid(simulation): simulation.incoming_amplitude = lerpf(0.60, 0.96, rain_amount)
	status.text = "%02d:%02d  %s" % [int(hour), int(fmod(hour, 1.0) * 60.0), WEATHER_NAMES[current_weather]]

func _lightning_flash(strength: float) -> void:
	if flash_tween and flash_tween.is_valid(): flash_tween.kill()
	bolt.position = player.global_position + Vector3(rng.randf_range(-90, 90), 32.0, -rng.randf_range(45, 100))
	bolt.visible = true
	flash_tween = create_tween()
	flash_tween.tween_property(flash_light, "light_energy", 2.5 * strength, 0.035)
	flash_tween.tween_property(flash_light, "light_energy", 0.12, 0.065)
	flash_tween.tween_property(flash_light, "light_energy", 1.4 * strength, 0.045)
	flash_tween.tween_property(flash_light, "light_energy", 0.0, 0.20)
	flash_tween.tween_callback(func(): bolt.visible = false)

func _thunder(delay_seconds: float, strength: float) -> void:
	await get_tree().create_timer(delay_seconds).timeout
	thunder_audio.pitch_scale = rng.randf_range(0.85, 1.05)
	thunder_audio.volume_db = lerpf(-15.0, -5.0, strength)
	thunder_audio.play()
