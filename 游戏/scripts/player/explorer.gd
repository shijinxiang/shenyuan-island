extends CharacterBody3D

const MODEL_PATH:="res://assets/characters/C01_locomotion.glb"
const MOTION_PATH:="res://assets/characters/C01_motion.json"
@export var spawn_point:=Vector3(145.38976,2.0,127.45559)
var walk_speed:=1.4722
var run_speed:=4.8
var native_walk_speed:=1.4722
var native_run_speed:=4.96905
var current_motion:=""
var planar_speed:=0.
var placing_on_ground:=false
var visual:Node3D
var animation:AnimationPlayer
var swimming:=false
var swim_speed:=2.4
var swim_vertical_speed := 1.8
var swim_depth := 0.0
var swim_moving := false
var water_level:=0.0
var ground_depth:=0.0
var floor_probe_timer:=0.0
var collision_shape:CollisionShape3D
var third_person:=false
var third_distance:=5.2
var third_pitch:=-.26
var overhead_pitch:=-.70
var camera_dragging := false
var previous_mouse_mode := Input.MOUSE_MODE_VISIBLE
const FREE_CAMERA_MIN_PITCH := -1.48
const FREE_CAMERA_MAX_PITCH := 1.30
var rowing:Node
var vehicle: Node
var fishing:Node
var fishing_active:=false
var fishing_move_velocity:=Vector3.ZERO
var camera_safety:RefCounted
var camera_follow_offset := Vector3.UP * 1.05
var water_depth_filtered:=0.0
var water_state_initialized:=false
var swim_enter_time:=0.0
var swim_exit_time:=0.0
var water_probe_elapsed:=0.0
var visual_water_tween:Tween
var adventure:Node
var controls_locked:=false
var interaction_time:=0.0
var interaction_clip:="Swim"
var interaction_rate:=1.0
@onready var orbit:Node3D=$Orbit
@onready var arm:SpringArm3D=$Orbit/Arm
@onready var camera:Camera3D=$Orbit/Arm/FollowCamera
@onready var overview:Camera3D=get_parent().get_node("OverviewCamera")

func _ready() -> void:
	for pair in [["move_left",KEY_A],["move_right",KEY_D],["move_forward",KEY_W],["move_back",KEY_S],["sprint",KEY_SHIFT],["swim_down",KEY_CTRL],["swim_up",KEY_SPACE]]:
		if not InputMap.has_action(pair[0]):
			InputMap.add_action(pair[0])
			var key:=InputEventKey.new()
			key.physical_keycode=pair[1]
			InputMap.action_add_event(pair[0],key)
	var marker:=get_node_or_null("MovementMarker")
	if marker:
		marker.hide()
		marker.queue_free()
	visual=get_node_or_null("Visual")
	if visual:
		var old_animation:AnimationPlayer=visual.find_children("*","AnimationPlayer",true,false)[0]
		if not old_animation.has_animation("FishCast"):
			remove_child(visual)
			visual.queue_free()
			visual=null
	if visual==null:
		visual=load(MODEL_PATH).instantiate()
		visual.name="Visual"
		add_child(visual)
		visual.rotation.y=.65
	animation=visual.find_children("*","AnimationPlayer",true,false)[0]
	animation.root_node=animation.get_path_to(visual)
	# Refresh the run clip even when an older character is embedded in a saved scene.
	var motion_source:Node3D=load(MODEL_PATH).instantiate()
	var source_animation:AnimationPlayer=motion_source.find_children("*","AnimationPlayer",true,false)[0]
	var fast_run:Animation=source_animation.get_animation("Run").duplicate()
	fast_run.resource_name="Fast Run"
	var library:AnimationLibrary=animation.get_animation_library("").duplicate()
	library.remove_animation("Run")
	library.add_animation("Run",fast_run)
	if library.has_animation("Treading Water"):
		library.remove_animation("Treading Water")
	library.add_animation("Treading Water",preload("res://assets/characters/C01_treading_water.res").duplicate())
	var added_clips := {"Chop":"C01_chop.res", "Harvest":"C01_harvest.res", "Watering":"C01_watering.res", "Entering Car":"C01_entering_car.res", "Driving":"C01_driving.res", "GunAim":"C01_gun_aim.res", "GunFire":"C01_gun_fire.res", "GunReload":"C01_gun_reload.res", "Bow":"C01_bow.res"}
	for clip: String in added_clips:
		if library.has_animation(clip):
			library.remove_animation(clip)
		library.add_animation(clip, load("res://assets/characters/" + str(added_clips[clip])).duplicate())
	animation.remove_animation_library("")
	animation.add_animation_library("",library)
	motion_source.free()
	for name in ["Idle","Walk","Run","Swim","SwimIdle","Treading Water","Paddle","PaddleIdle","FishCast","FishIdle"]:
		assert(animation.has_animation(name),"Missing locomotion clip "+name)
		animation.get_animation(name).loop_mode=Animation.LOOP_LINEAR
	for clip: String in added_clips:
		animation.get_animation(clip).loop_mode = Animation.LOOP_LINEAR if clip == "Driving" else Animation.LOOP_NONE
	var info:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(MOTION_PATH))
	native_walk_speed=float(info.clips.Walk.speed_mps)
	native_run_speed=float(info.clips.Run.speed_mps)
	walk_speed=native_walk_speed
	run_speed=4.8
	floor_snap_length=.50
	floor_max_angle=deg_to_rad(50.)
	floor_stop_on_slope=true
	safe_margin=.005
	collision_shape=find_children("*","CollisionShape3D",false,false)[0]
	collision_shape.shape=collision_shape.shape.duplicate()
	# Keep the requested orbit distance and use the silhouette for obstruction visibility.
	arm.collision_mask=0
	arm.margin = 0.0
	arm.shape = null
	arm.spring_length=22.
	arm.rotation.x=-.70
	arm.add_excluded_object(get_rid())
	orbit.rotation.y=.6566678
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.size=12.
	camera.far=1800.
	var orbit_transform:=orbit.global_transform
	orbit.top_level=true
	orbit.global_transform=orbit_transform
	camera_safety=preload("res://scripts/player/follow_camera_safety.gd").new(self)
	_play_motion("Idle",1.)
	animation.advance(0.)
	var movement_fx:=Node.new()
	movement_fx.name="MovementVFX"
	movement_fx.set_script(preload("res://scripts/player/player_movement_vfx.gd"))
	add_child(movement_fx)
	var occlusion_fx := Node.new()
	occlusion_fx.name = "PlayerOcclusion"
	occlusion_fx.set_script(preload("res://scripts/player/player_occlusion.gd"))
	add_child(occlusion_fx)
	show()
	camera.make_current()
	call_deferred("_place_on_ground")
	print("FISHERWOMAN_READY walk=",walk_speed," run=",run_speed)

func _place_on_ground() -> void:
	if placing_on_ground:return
	if is_instance_valid(fishing) and fishing_active:fishing.set_active(false)
	if is_instance_valid(rowing):rowing.return_to_mooring()
	if in_vehicle():
		vehicle.return_to_home()
	placing_on_ground=true
	_set_swimming(false)
	water_state_initialized=false
	swim_enter_time=0.0
	swim_exit_time=0.0
	floor_probe_timer=0.0
	if visual_water_tween and visual_water_tween.is_valid():visual_water_tween.kill()
	visual.position.y=0.0
	await get_tree().physics_frame
	var from:=Vector3(spawn_point.x,spawn_point.y+12.,spawn_point.z)
	var to:=Vector3(spawn_point.x,spawn_point.y-14.,spawn_point.z)
	var query:=PhysicsRayQueryParameters3D.create(from,to,collision_mask,[get_rid()])
	var hit:=get_world_3d().direct_space_state.intersect_ray(query)
	global_position=hit.position+Vector3.UP*.015 if not hit.is_empty() else spawn_point
	velocity=Vector3.ZERO
	orbit.global_position=global_position+Vector3.UP*1.05
	camera_follow_offset = Vector3.UP * 1.05
	placing_on_ground=false

func _unhandled_input(event:InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and not event.pressed:
		_end_camera_drag()
		return
	if is_instance_valid(adventure) and adventure.handle_key(event):return
	if controls_locked:return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode==KEY_F and is_instance_valid(fishing):fishing.toggle()
		if event.keycode==KEY_V:toggle_camera()
		if event.keycode==KEY_E:
			if is_instance_valid(fishing) and fishing.try_pickup():return
			if is_instance_valid(rowing):rowing.interact()
		if event.keycode==KEY_TAB:
			if camera.is_current():overview.make_current()
			else:camera.make_current()
		if event.keycode==KEY_R:call_deferred("_place_on_ground")
	if event is InputEventMouseMotion and camera_dragging:
		rotate_camera(event.screen_relative if not event.screen_relative.is_zero_approx() else event.relative)
		get_viewport().set_input_as_handled()
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_begin_camera_drag()
			get_viewport().set_input_as_handled()
			return
		var zoom:=0.0
		if event.button_index==MOUSE_BUTTON_WHEEL_UP:zoom=-1.0
		if event.button_index==MOUSE_BUTTON_WHEEL_DOWN:zoom=1.0
		if third_person:
			third_distance=clampf(third_distance+zoom*.8,2.0,24.0)
			arm.spring_length=third_distance
		else:camera.size=clampf(camera.size+zoom,6.,30.)

func activate_free_camera() -> void:
	if not third_person:
		# Match the overview's visible scale when entering free perspective orbit.
		third_distance = clampf(camera.size / (2.0*tan(deg_to_rad(camera.fov)*.5)), 2.0, 24.0)
		third_person = true
		camera.projection = Camera3D.PROJECTION_PERSPECTIVE
		camera.near = .10
		arm.spring_length = third_distance
	camera.make_current()

func _begin_camera_drag() -> void:
	if camera_dragging:
		return
	activate_free_camera()
	previous_mouse_mode = Input.mouse_mode
	camera_dragging = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _end_camera_drag() -> void:
	if not camera_dragging:
		return
	camera_dragging = false
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = previous_mouse_mode

func rotate_camera(relative: Vector2) -> void:
	orbit.rotation.y = wrapf(orbit.rotation.y-relative.x*.005, -PI, PI)
	arm.rotation.x = clampf(arm.rotation.x-relative.y*.004, FREE_CAMERA_MIN_PITCH, FREE_CAMERA_MAX_PITCH)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_end_camera_drag()

func _exit_tree() -> void:
	_end_camera_drag()

func toggle_camera() -> void:
	if third_person:third_pitch=arm.rotation.x
	else:overhead_pitch=arm.rotation.x
	third_person=not third_person
	if third_person:orbit.rotation.y=visual.global_rotation.y+PI
	camera.projection=Camera3D.PROJECTION_PERSPECTIVE if third_person else Camera3D.PROJECTION_ORTHOGONAL
	camera.fov=62.0
	camera.near=.10
	arm.spring_length=third_distance if third_person else 22.0
	arm.rotation.x=clampf(third_pitch,FREE_CAMERA_MIN_PITCH,FREE_CAMERA_MAX_PITCH) if third_person else clampf(overhead_pitch,-1.48,-.10)
	arm.collision_mask=0
	arm.margin = 0.0
	arm.shape = null
	camera.make_current()

func _process(delta:float) -> void:
	if camera_dragging and (controls_locked or not camera.is_current() or not Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)):
		_end_camera_drag()
	var target_height:=1.2 if third_person else 1.05
	if swimming:target_height=.35 if third_person else .65
	if is_instance_valid(rowing) and rowing.boarded:target_height=1.1 if fishing_active else .65
	var look_offset := Vector3.ZERO
	if is_instance_valid(adventure) and is_instance_valid(adventure.hunting):
		look_offset = adventure.hunting.camera_offset
		if adventure.hunting.aiming and is_instance_valid(rowing) and rowing.boarded:
			target_height = 1.1
	camera_follow_offset = camera_follow_offset.lerp(Vector3.UP * target_height + look_offset, 1.0 - exp(-9.0 * delta))
	orbit.global_position = global_position + camera_follow_offset
	if camera_safety:camera_safety.update(delta)

func _set_swimming(enabled:bool) -> void:
	if swimming==enabled:return
	if enabled and fishing_active and is_instance_valid(fishing):
		fishing.set_active(false,false)
	swimming=enabled
	swim_depth = 0.0
	swim_moving = false
	if collision_shape:
		var capsule:=collision_shape.shape as CapsuleShape3D
		capsule.height=.72 if swimming else 1.68
		capsule.radius=.30 if swimming else .27
		collision_shape.position.y=-.12 if swimming else .84
	floor_snap_length=0.0 if swimming else .50
	motion_mode=CharacterBody3D.MOTION_MODE_FLOATING if swimming else CharacterBody3D.MOTION_MODE_GROUNDED
	swim_enter_time=0.0
	swim_exit_time=0.0
	velocity.y=0.0

func _water_capsule_clear(point:Vector3,in_water:bool) -> bool:
	var capsule:=CapsuleShape3D.new()
	capsule.radius=.30 if in_water else .27
	capsule.height=.72 if in_water else 1.68
	var query:=PhysicsShapeQueryParameters3D.new()
	query.shape=capsule
	query.transform=Transform3D(Basis.IDENTITY,point+Vector3.UP*(-.12 if in_water else .84))
	query.collision_mask=1
	query.exclude=[get_rid()]
	return get_world_3d().direct_space_state.intersect_shape(query,1).is_empty()

func _transition_water_pose(point:Vector3,in_water:bool) -> void:
	var previous_height:=global_position.y
	_set_swimming(in_water)
	global_position=point
	if visual_water_tween and visual_water_tween.is_valid():visual_water_tween.kill()
	visual.position.y+=previous_height-point.y
	visual_water_tween=create_tween()
	visual_water_tween.tween_property(visual,"position:y",0.0,.32)

func _enter_swimming() -> void:
	var surface_position:=Vector3(global_position.x,water_level,global_position.z)
	for offset in [Vector3.ZERO,Vector3(.15,0,0),Vector3(-.15,0,0),Vector3(0,0,.15),Vector3(0,0,-.15),Vector3(0,.2,0)]:
		var candidate:Vector3=surface_position+offset
		if _water_capsule_clear(candidate,true):
			_transition_water_pose(candidate,true)
			return

func _update_water_state(delta:float) -> void:
	var simulation:=get_parent().get_node_or_null("ShallowWaterSimulation")
	if simulation and simulation.ready_for_render:water_level=simulation.player_elevation
	water_probe_elapsed+=delta
	floor_probe_timer-=delta
	if floor_probe_timer>0.0:return
	floor_probe_timer=.10
	var sample_time:=water_probe_elapsed
	water_probe_elapsed=0.0
	var from:=Vector3(global_position.x,maxf(global_position.y,water_level)+.55,global_position.z)
	var query:=PhysicsRayQueryParameters3D.create(from,from+Vector3.DOWN*22.0,1,[get_rid()])
	var hit:=get_world_3d().direct_space_state.intersect_ray(query)
	var floor_height:float=hit.position.y if not hit.is_empty() else -10.0
	ground_depth=water_level-floor_height
	if not water_state_initialized:
		water_depth_filtered=ground_depth
		water_state_initialized=true
	else:water_depth_filtered=lerpf(water_depth_filtered,ground_depth,1.0-exp(-sample_time*3.0))
	if swimming:
		var can_stand:=not hit.is_empty() and floor_height>-.85 and water_depth_filtered<1.05
		swim_exit_time=swim_exit_time+sample_time if can_stand else 0.0
		if swim_exit_time>=.25:
			var standing_position:=Vector3(global_position.x,floor_height+.035,global_position.z)
			if _water_capsule_clear(standing_position,false):_transition_water_pose(standing_position,false)
	else:
		# Sea level is zero. A short crest over a standable bank should remain wading.
		var deep_enough:=floor_height<-.95 and water_depth_filtered>1.15 and global_position.y<water_level+.15
		swim_enter_time=swim_enter_time+sample_time if deep_enough else 0.0
		var submerged:=floor_height< -1.4 and global_position.y+1.1<water_level
		if swim_enter_time>=.45 or submerged:_enter_swimming()

func in_vehicle() -> bool:
	return is_instance_valid(vehicle) and (vehicle.boarded or vehicle.entering)

func movement_direction() -> Vector3:
	if controls_locked or interaction_time > 0:return Vector3.ZERO
	var input:=Input.get_vector("move_left","move_right","move_forward","move_back")
	var active_camera:=get_viewport().get_camera_3d()
	var right:=active_camera.global_basis.x
	var backward:=active_camera.global_basis.z
	right.y=0.;backward.y=0.
	if backward.length_squared()<.001:
		backward=-active_camera.global_basis.y
		backward.y=0.
	return (right.normalized()*input.x+backward.normalized()*input.y).normalized()

func _physics_process(delta:float) -> void:
	if is_instance_valid(adventure) and (adventure.cinematic_active or adventure.dead):return
	if placing_on_ground:return
	if is_instance_valid(rowing) and rowing.boarded:return
	if in_vehicle():return
	_update_water_state(delta)
	if swimming and fishing_active:fishing.set_active(false,false)
	var vertical_input := 0.0
	if swimming:
		if not controls_locked:
			vertical_input = Input.get_axis("swim_down", "swim_up")
		# Leave space below the hips for the legs of the treading pose.
		var maximum_depth := maxf(0.0, ground_depth - 1.1)
		swim_depth = clampf(swim_depth, 0.0, maximum_depth)
		var target_height := water_level - swim_depth
		if not is_zero_approx(vertical_input):
			target_height = clampf(global_position.y + vertical_input * swim_vertical_speed * delta, water_level - maximum_depth, water_level)
			velocity.y = (target_height - global_position.y) / delta
		else:
			velocity.y = clampf((target_height - global_position.y) * 6.0, -3.5, 3.5)
	elif not is_on_floor():velocity.y-=20.*delta
	else:velocity.y=0.
	var direction:=movement_direction()
	var requested_speed:=run_speed if Input.is_action_pressed("sprint") else walk_speed
	if swimming:requested_speed=swim_speed*(1.30 if Input.is_action_pressed("sprint") else 1.0)
	if is_instance_valid(adventure):
		if swimming and adventure.has_good("life_jacket"):
			requested_speed *= 1.2
		elif not swimming and adventure.has_good("boots"):
			requested_speed *= 1.1
		if is_instance_valid(adventure.nutrition):
			requested_speed *= adventure.nutrition.speed_multiplier()
	velocity.x=move_toward(velocity.x,direction.x*requested_speed,10.*delta)
	velocity.z=move_toward(velocity.z,direction.z*requested_speed,10.*delta)
	move_and_slide()
	var actual:=get_real_velocity()
	planar_speed=Vector2(actual.x,actual.z).length()
	if swimming and not is_zero_approx(vertical_input):
		swim_depth = maxf(0.0, water_level - global_position.y)
	swim_moving = swimming and (planar_speed > .08 or (not is_zero_approx(vertical_input) and absf(actual.y) > .08))
	fishing_move_velocity=Vector3(actual.x,0,actual.z)
	if fishing_active and fishing.state!=fishing.State.READY:
		var aim:Vector3=fishing.target-global_position
		if Vector2(aim.x,aim.z).length_squared()>.01:visual.global_rotation.y=lerp_angle(visual.global_rotation.y,atan2(aim.x,aim.z),1.-exp(-10.*delta))
	elif direction!=Vector3.ZERO:
		visual.rotation.y=lerp_angle(visual.rotation.y,atan2(direction.x,direction.z),1.-exp(-14.*delta))
	if fishing_active:return
	interaction_time=maxf(0.0,interaction_time-delta)
	if interaction_time>0.0:
		_play_motion(interaction_clip,interaction_rate)
		return
	if swimming:
		_play_motion("Swim" if swim_moving else "Treading Water",1.4 if swim_moving else 1.0)
	elif planar_speed<.07:_play_motion("Idle",1.)
	elif planar_speed>walk_speed*1.25:_play_motion("Run",clampf(planar_speed/native_run_speed,.25,1.6))
	else:_play_motion("Walk",clampf(planar_speed/native_walk_speed,.20,1.6))
	if not swimming and global_position.y< -12.0:call_deferred("_place_on_ground")

func _play_motion(name:String,rate:float) -> void:
	if name!=current_motion:
		var previous_moving:=current_motion in ["Walk","Run"]
		var phase:=0.
		if previous_moving and animation.current_animation_length>0.:phase=fposmod(animation.current_animation_position/animation.current_animation_length,1.)
		animation.play(name,.32 if name in ["Swim","SwimIdle","Treading Water"] or current_motion in ["Swim","SwimIdle","Treading Water"] else .18)
		if previous_moving and name in ["Walk","Run"]:animation.seek(phase*animation.get_animation(name).length,false)
		current_motion=name
	animation.speed_scale=rate
