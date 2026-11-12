extends Node3D

const Utility = preload("res://scripts/core/island_static_setup.gd")
var fish: Array[Dictionary] = []
var birds: Array[Dictionary] = []
var elapsed := 0.0
var player: Node3D
var weather: Node
var rng := RandomNumberGenerator.new()
var ground = preload("res://scripts/world/ground_sampler.gd").new()
var schools:RefCounted

func _ready() -> void:
	rng.seed = 61106
	player = get_parent().get_node("Player")
	weather = get_parent().get_node_or_null("IslandWeather")
	var terrain := get_parent().find_child("TERRAIN*",true,false) as MeshInstance3D
	if terrain: ground.build(terrain)
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/fauna/habitats.json"))
	var templates := {}
	var definitions := {}
	for definition: Dictionary in manifest.species:
		definitions[definition.name] = definition
		templates[definition.name] = load("res://assets/fauna/marine/" + definition.name + ".glb")
	schools=preload("res://scripts/wildlife/fish_schools.gd").new(get_parent())
	var expanded:Array=[]
	for original:Dictionary in manifest.fish:
		var definition:Dictionary=definitions[original.species]
		var small:bool=float(definition.length)<=.65 and not definition.benthic
		for copy_index in (4 if small else 1):
			var entry:Dictionary=original.duplicate()
			if small and copy_index>0:entry.school_key="%s_%s_%.3f_%.3f"%[entry.species,entry.zone,entry.path[0][0],entry.path[0][2]]
			entry.animation_phase=rng.randf()
			expanded.append(entry)
	for entry: Dictionary in expanded:
		var definition: Dictionary = definitions[entry.species]
		var actor := Node3D.new()
		actor.name = entry.species + "_" + entry.zone + "_" + str(fish.size())
		add_child(actor)
		var facing := Node3D.new()
		actor.add_child(facing)
		facing.rotation.y = definition.yaw
		var model: Node3D = templates[entry.species].instantiate()
		facing.add_child(model)
		model.scale = Vector3.ONE * float(definition.scale)
		model.position = Vector3(definition.offset[0], definition.offset[1], definition.offset[2])
		actor.scale = Vector3.ONE * float(entry.scale)
		var animator := model.find_child("*", true, false) as AnimationPlayer
		var animators := model.find_children("*", "AnimationPlayer", true, false)
		if not animators.is_empty(): animator = animators[0]
		_play(animator, definition.clip, float(entry.animation_phase))
		for mesh: MeshInstance3D in Utility.meshes(model):
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var route := PackedVector3Array()
		for point: Array in entry.path: route.append(Vector3(point[0], point[1], point[2]))
		var curve := Curve3D.new()
		for i in route.size() + 1:
			var index := i % route.size()
			var tangent := (route[(index + 1) % route.size()] - route[posmod(index - 1, route.size())]) / 6.0
			curve.add_point(route[index], -tangent, tangent)
		curve.bake_interval = 0.25
		var speed:float=entry.speed
		if definition.get("speed_scale_from_stride",false):
			speed=maxf(.12,float(definition.stride_speed))*float(entry.scale)*animator.speed_scale
		fish.append({"node": actor, "animator": animator, "curve": curve, "distance": float(entry.phase) / 64.0 * curve.get_baked_length(), "speed": speed, "offset": float(entry.offset), "bottom": bool(definition.benthic)})
		fish.back().species=entry.species
		fish.back().habitat=entry.zone
		fish.back().fish_length=float(definition.length)*float(entry.scale)
		if entry.has("school_key"):schools.register(fish.back(),entry)
	var bird_scene := load("res://assets/fauna/birds/American_Robin.glb") as PackedScene
	for entry: Dictionary in manifest.birds:
		var bird := Node3D.new()
		bird.name = "Robin_" + str(birds.size())
		add_child(bird)
		var model := bird_scene.instantiate() as Node3D
		bird.add_child(model)
		model.scale = Vector3.ONE * rng.randf_range(2.6, 3.3)
		model.rotation.y = PI
		var animator: AnimationPlayer = model.find_children("*", "AnimationPlayer", true, false)[0]
		var home := Vector3(entry.home[0], entry.home[1], entry.home[2])
		home.y = ground.height(home.x,home.z)+0.025
		bird.position = home
		birds.append({"node":bird,"animator":animator,"home":home,"state":"rest","timer":rng.randf_range(1,4),"clip":"","start":home,"target":home,"duration":1.0,"progress":0.0,"scared":false})
		_play_bird(birds.back(),"A_Idle_01")
		if entry.flying:_begin_flight(birds.back(),false)
	print("WILDLIFE_READY species=25 marine_animals=", fish.size(), " robins=", birds.size())
	print("FISH_SCHOOLS_READY schools=",schools.groups.size()," fish=",schools.members.size())

func _play(animator: AnimationPlayer, suffix: String, phase := 0.0) -> void:
	if animator == null: return
	var chosen := ""
	for clip in animator.get_animation_list():
		if clip == "RESET": continue
		if chosen.is_empty(): chosen = clip
		if clip.ends_with(suffix):
			chosen = clip
			break
	if chosen.is_empty(): return
	var animation := animator.get_animation(chosen)
	animation.loop_mode = Animation.LOOP_LINEAR
	animator.play(chosen, 0.18)
	animator.seek(phase * animation.length, true)
	animator.speed_scale = rng.randf_range(0.82, 1.12)

func _process(delta: float) -> void:
	elapsed += delta
	var camera := get_viewport().get_camera_3d()
	if camera == null: return
	schools.update(delta,player.global_position)
	for animal in fish:
		var actor: Node3D = animal.node
		if animal.get("caught",false):
			actor.hide()
			continue
		if animal.get("adventure_control",false):continue
		if animal.has("school"):
			var nearby:=camera.global_position.distance_squared_to(actor.position)<120.0*120.0
			actor.visible=nearby
			if animal.animator:animal.animator.active=nearby
			continue
		if animal.has("fishing_target"):
			var direction:Vector3=animal.fishing_target-actor.position
			actor.position=actor.position.move_toward(animal.fishing_target,delta*1.1)
			if direction.length_squared()>.01:actor.rotation.y=lerp_angle(actor.rotation.y,atan2(-direction.x,-direction.z),delta*5.0)
			continue
		var curve: Curve3D = animal.curve
		animal.distance = fposmod(float(animal.distance) + delta * float(animal.speed), curve.get_baked_length())
		var point := curve.sample_baked(animal.distance, true)
		var next := curve.sample_baked(fposmod(float(animal.distance) + 0.35, curve.get_baked_length()), true)
		point.y += float(animal.offset)
		actor.position = point
		var direction := next - point
		direction.y = 0.0
		if direction.length_squared() > 0.00001:
			actor.rotation.y = lerp_angle(actor.rotation.y, atan2(-direction.x, -direction.z), 1.0 - exp(-delta * 4.0))
		var nearby := camera.global_position.distance_squared_to(point) < 210.0 * 210.0
		actor.visible = nearby
		if animal.animator: animal.animator.active = nearby
	for bird in birds:_update_bird(bird,delta,camera)

func _play_bird(bird: Dictionary,clip: String) -> void:
	if bird.clip==clip:return
	bird.clip=clip
	_play(bird.animator,clip)
	bird.animator.speed_scale=1.0

func _landing_near(point: Vector3,direction: Vector3,distance: float) -> Vector3:
	for attempt in 12:
		var heading:=direction.rotated(Vector3.UP,rng.randf_range(-0.7,0.7))
		var candidate:=point+heading*distance*rng.randf_range(0.75,1.2)
		var height:float=ground.height(candidate.x,candidate.z)
		if height>0.35 and absf(height-point.y)<4.0:
			candidate.y=height+0.025
			if candidate.distance_to(player.global_position)>8.0:return candidate
	return point

func _begin_flight(bird: Dictionary,scared: bool) -> void:
	var actor:Node3D=bird.node
	var direction:=actor.position-player.global_position if scared else Vector3(rng.randf_range(-1,1),0,rng.randf_range(-1,1))
	direction.y=0.0
	if direction.length_squared()<0.01:direction=Vector3.RIGHT
	direction=direction.normalized()
	bird.start=actor.position
	bird.target=_landing_near(actor.position,direction,rng.randf_range(16,25))
	if bird.target.distance_to(actor.position)<5.0:
		# Stay aloft while selecting another safe landing instead of dropping beside the player.
		bird.target=actor.position+direction*15.0
		bird.target.y=actor.position.y+4.0
	bird.duration=maxf(5.0,actor.position.distance_to(bird.target)/3.2)
	bird.progress=0.0
	bird.state="flight"
	bird.scared=scared
	_play_bird(bird,"A_Fly_01")

func _update_bird(bird: Dictionary,delta: float,camera: Camera3D) -> void:
	var actor:Node3D=bird.node
	if bird.get("caught", false):
		actor.hide()
		bird.animator.active = false
		return
	var horizontal:=Vector2(actor.position.x-player.global_position.x,actor.position.z-player.global_position.z).length()
	var threatened:=horizontal<7.0 and absf(actor.position.y-player.global_position.y)<5.0
	if bird.state!="flight" and threatened:_begin_flight(bird,true)
	var previous:=actor.position
	if bird.state=="flight":
		bird.progress=minf(1.0,float(bird.progress)+delta/float(bird.duration))
		var t:float=bird.progress
		actor.position=Vector3(bird.start).lerp(bird.target,t)
		actor.position.y+=sin(PI*t)*6.0
		actor.rotation.z=sin(t*TAU)*0.12
		if t>=1.0:
			var floor_height:float=ground.height(actor.position.x,actor.position.z)
			if floor_height<0.35 or threatened:_begin_flight(bird,true)
			else:
				actor.position.y=floor_height+0.025
				bird.home=actor.position
				bird.state="rest"
				bird.timer=rng.randf_range(1,3)
				_play_bird(bird,"A_Idle_02")
	elif bird.state=="hop":
		var to_target:Vector3=bird.target-actor.position
		to_target.y=0.0
		if to_target.length()<0.10:
			bird.state="rest"
			bird.timer=rng.randf_range(1.5,4.0)
			_play_bird(bird,"A_PeckGround_01")
		else:
			actor.position+=to_target.normalized()*minf(delta*0.8,to_target.length())
			actor.position.y=ground.height(actor.position.x,actor.position.z)+0.025
	else:
		actor.rotation.z=0.0
		bird.timer=float(bird.timer)-delta
		if bird.timer<=0.0:
			var direction:=Vector3(rng.randf_range(-1,1),0,rng.randf_range(-1,1)).normalized()
			var candidate:=actor.position+direction*rng.randf_range(0.7,2.2)
			var height:float=ground.height(candidate.x,candidate.z)
			if height>0.35 and absf(height-actor.position.y)<0.3:
				candidate.y=height+0.025
				bird.target=candidate
				bird.state="hop"
				_play_bird(bird,"A_Hop_01")
			else:
				bird.timer=2.0
				_play_bird(bird,"A_Preen_01")
	var motion:=actor.position-previous
	if Vector2(motion.x,motion.z).length_squared()>0.000001:
		actor.rotation.y=lerp_angle(actor.rotation.y,atan2(-motion.x,-motion.z),1.0-exp(-delta*12.0))
	var nearby:=camera.global_position.distance_squared_to(actor.position)<200.0*200.0
	actor.visible=nearby
	bird.animator.active=nearby
