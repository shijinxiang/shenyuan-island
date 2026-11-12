extends Node3D
var boat: Node3D
var boat_origin := Transform3D.IDENTITY
var palms: Array[Node3D] = []
var angles: Array[float] = []
var elapsed := 0.0
var hero_transform := Transform3D.IDENTITY
var hero_size := 49.0
var water_simulation: Node

func _ready() -> void:
	preload("res://scripts/core/island_static_setup.gd").setup(self)
	preload("res://scripts/world/building_revision.gd").setup(self)
	preload("res://scripts/world/coastal_palm_setup.gd").setup(self)
	if not has_node("PebblePaths"):
		add_child(load("res://assets/library/pebble_paths.scn").instantiate())
	preload("res://scripts/water/shore_waves_setup.gd").setup(self)
	water_simulation=get_node_or_null("ShallowWaterSimulation")
	preload("res://scripts/world/island_grass_setup.gd").setup(self)
	preload("res://scripts/core/island_static_setup.gd").finish_ground(self)
	preload("res://scripts/world/forest_biome_setup.gd").setup(self)
	get_viewport().msaa_3d=Viewport.MSAA_4X
	preload("res://scripts/player/fisherwoman_setup.gd").setup(self)
	$Player/Orbit/Arm/FollowCamera.make_current()
	hero_transform=get_meta("landing_camera_transform",$CoastalCamera.transform)
	hero_size=get_meta("landing_camera_size",$CoastalCamera.size)
	boat=$Island.find_child("P02_*",true,false) as Node3D
	if boat:boat_origin=boat.transform
	for n in $CoastalDressing.get_children():
		if n.name.begins_with("V03") or n.name.begins_with("V04"):
			palms.append(n);angles.append(n.rotation.z)
	preload("res://scripts/core/world_life_setup.gd").setup(self)
	print("COASTAL_PRESENTATION_READY")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode==KEY_1:
			$Sun.directional_shadow_max_distance=1000.
			$CoastalCamera.position=Vector3(0,650,0.01)
			$CoastalCamera.look_at(Vector3.ZERO,Vector3(0,0,-1))
			$CoastalCamera.size=480.0
		elif event.keycode==KEY_2:
			$Sun.directional_shadow_max_distance=240.
			$CoastalCamera.transform=hero_transform
			$CoastalCamera.size=hero_size
		elif event.keycode==KEY_3 and has_node("LighthouseCamera"):
			$Sun.directional_shadow_max_distance=240.
			$CoastalCamera.transform=$LighthouseCamera.transform
			$CoastalCamera.size=$LighthouseCamera.size

func _process(delta: float) -> void:
	elapsed+=delta
	if is_instance_valid(boat) and not boat.get_meta("rowboat_controlled",false):
		boat.transform=boat_origin
		if is_instance_valid(water_simulation) and water_simulation.boat_sample_valid:
			boat.position.y+=water_simulation.boat_elevation
			var along:Vector3=boat.global_basis.z.normalized()
			var across:Vector3=boat.global_basis.x.normalized()
			boat.rotation.x+=atan(water_simulation.boat_gradient.dot(Vector2(along.x,along.z)))
			boat.rotation.z-=atan(water_simulation.boat_gradient.dot(Vector2(across.x,across.z)))
	for i in palms.size(): palms[i].rotation.z=angles[i]+sin(elapsed*0.65+i*1.7)*0.006
