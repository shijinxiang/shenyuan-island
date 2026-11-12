extends CharacterBody3D

var boat_visual:Node3D
var player:CharacterBody3D
var water:Node
var boarded:=false
var drive_speed:=0.0
var seat:Marker3D
var paddle:Node3D
var skeleton:Skeleton3D
var hull:CollisionShape3D
var prompt:Label
var initial_position:=Vector3.ZERO
var initial_yaw:=0.0
var saved_player_layer:=2
var saved_player_mask:=1
var wake_timer:=0.0
var splash_timer:=0.0
var tip_submerged:=[false,false]
var fishing_deck_position:=Vector3(0,.24,.62)
var cruise_speed:=6.5
var boost_speed:=8.5
var upgraded:=false

func _ready() -> void:
	player=get_parent().get_node("Player")
	water=get_parent().get_node("ShallowWaterSimulation")
	var original_scale:=boat_visual.global_basis.get_scale()
	initial_position=boat_visual.global_position
	var forward:=boat_visual.global_basis.z.normalized()
	initial_yaw=atan2(forward.x,forward.z)+PI
	global_position=Vector3(initial_position.x,-.28,initial_position.z)
	rotation.y=initial_yaw
	boat_visual.set_meta("rowboat_controlled",true)
	boat_visual.reparent(self)
	boat_visual.transform=Transform3D(Basis.IDENTITY.scaled(original_scale),Vector3.ZERO)
	var lining:=load("res://assets/boating/hull_lining.glb").instantiate() as Node3D
	boat_visual.add_child(lining)
	hull=CollisionShape3D.new()
	var shape:=BoxShape3D.new()
	shape.size=Vector3(1.62,.70,3.85)
	hull.shape=shape
	hull.position.y=.30
	add_child(hull)
	collision_layer=1
	collision_mask=1
	motion_mode=CharacterBody3D.MOTION_MODE_FLOATING
	safe_margin=.025
	seat=Marker3D.new()
	seat.name="RowerSeat"
	seat.position=Vector3(0,.78,.10)/original_scale
	boat_visual.add_child(seat)
	paddle=load("res://assets/boating/wooden_paddle.glb").instantiate()
	paddle.name="HeldWoodenPaddle"
	get_parent().add_child(paddle)
	paddle.hide()
	skeleton=player.visual.find_children("*","Skeleton3D",true,false)[0]
	player.rowing=self
	var wake=preload("res://scripts/boating/boat_wake.gd").new()
	wake.name="BowAndSternWake"
	add_child(wake)
	var hud:=CanvasLayer.new()
	add_child(hud)
	prompt=Label.new()
	prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	prompt.position=Vector2(-220,-72)
	prompt.size=Vector2(440,36)
	prompt.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	prompt.add_theme_font_size_override("font_size",18)
	prompt.add_theme_color_override("font_shadow_color",Color(0,0,0,.9))
	prompt.add_theme_constant_override("shadow_offset_x",2)
	prompt.add_theme_constant_override("shadow_offset_y",2)
	hud.add_child(prompt)
	print("ROWBOAT_READY one_paddle=true")

func interact() -> void:
	if boarded:leave_boat()
	elif player.global_position.distance_to(global_position)<6.0:board_boat()

func board_boat() -> void:
	if boarded:return
	if player.fishing_active:player.fishing.set_active(false)
	boarded=true
	player.interaction_time = 0
	saved_player_layer=player.collision_layer
	saved_player_mask=player.collision_mask
	player._set_swimming(false)
	player.collision_layer=0
	player.collision_mask=0
	player.velocity=Vector3.ZERO
	player.planar_speed=0.0
	player.visual.rotation=Vector3.ZERO
	player.arm.add_excluded_object(get_rid())
	paddle.show()
	_sync_rider()
	player._play_motion("PaddleIdle",1.0)
	player.animation.advance(0.0)

func leave_boat(force:=false) -> void:
	if not boarded:return
	if player.fishing_active:player.fishing.set_active(false)
	var exit_position:=Vector3.ZERO
	var found:=false
	var dry:=false
	var surface:float=water.boat_elevation
	for offset in [Vector3(2.0,0,0),Vector3(-2.0,0,0),Vector3(0,0,-2.8),Vector3(0,0,2.8)]:
		var point:Vector3=global_position+global_basis*offset
		var query:=PhysicsRayQueryParameters3D.create(Vector3(point.x,surface+2.0,point.z),Vector3(point.x,surface-14.0,point.z),1,[get_rid(),player.get_rid()])
		var hit:=get_world_3d().direct_space_state.intersect_ray(query)
		var height:float=hit.position.y if not hit.is_empty() else surface-9.0
		if height>surface+1.4:continue
		var on_land:=height>surface-.65
		point.y=height+.06 if on_land else surface
		var capsule:=CapsuleShape3D.new()
		capsule.radius=.29
		capsule.height=1.68 if on_land else .72
		var clearance:=PhysicsShapeQueryParameters3D.new()
		clearance.shape=capsule
		clearance.transform=Transform3D(Basis.IDENTITY,point+Vector3.UP*(.85 if on_land else -.12))
		clearance.collision_mask=1
		clearance.exclude=[get_rid(),player.get_rid()]
		if not get_world_3d().direct_space_state.intersect_shape(clearance,1).is_empty():continue
		exit_position=point
		found=true
		dry=on_land
		if dry:break
	if not found and not force:
		prompt.text="这里空间不足，划到开阔处再下船"
		return
	boarded=false
	drive_speed=0.0
	player.collision_layer=saved_player_layer
	player.collision_mask=saved_player_mask
	player.arm.remove_excluded_object(get_rid())
	player.global_basis=Basis.IDENTITY
	if found:player.global_position=exit_position
	player.visual.rotation.y=rotation.y
	player._set_swimming(not dry and not force)
	player.velocity=Vector3.ZERO
	player.floor_probe_timer=0.0
	paddle.hide()
	player._play_motion("SwimIdle" if player.swimming else "Idle",1.0)

func return_to_mooring() -> void:
	leave_boat(true)
	drive_speed=0.0
	velocity=Vector3.ZERO
	global_position=Vector3(initial_position.x,-.28,initial_position.z)
	rotation.y=initial_yaw

func _safe_water(point:Vector3) -> bool:
	var surface:float=water.boat_elevation
	var query:=PhysicsRayQueryParameters3D.create(Vector3(point.x,surface+1.5,point.z),Vector3(point.x,surface-16.0,point.z),1,[get_rid(),player.get_rid()])
	var hit:=get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or float(hit.position.y)<surface-.70

func _physics_process(delta:float) -> void:
	var surface:float=water.boat_elevation if water.boat_sample_valid else 0.0
	var throttle:=0.0
	if boarded and not player.fishing_active and not _hunting_on_deck() and not player.controls_locked:
		throttle=Input.get_action_strength("move_forward")-Input.get_action_strength("move_back")
		var steering:=Input.get_action_strength("move_right")-Input.get_action_strength("move_left")
		if absf(steering)>.01:
			var target_basis:=Basis(Vector3.UP,rotation.y-steering*delta*.85)
			var clearance:=PhysicsShapeQueryParameters3D.new()
			clearance.shape=hull.shape
			clearance.transform=Transform3D(target_basis,global_position)*hull.transform
			clearance.collision_mask=1
			clearance.exclude=[get_rid(),player.get_rid()]
			if get_world_3d().direct_space_state.intersect_shape(clearance,1).is_empty():global_basis=target_basis
	var forward:=global_basis.z.normalized()
	var maximum:=boost_speed if Input.is_action_pressed("sprint") else cruise_speed
	if is_instance_valid(player.adventure):
		maximum *= player.adventure.skills.boat_multiplier()
	var target_speed:=throttle*maximum if throttle>=0.0 else throttle*2.0
	if absf(target_speed)>.01:
		var ahead:=global_position+forward*signf(target_speed)*(2.2+absf(drive_speed)*delta)
		if not _safe_water(ahead):target_speed=0.0
	drive_speed=move_toward(drive_speed,target_speed,delta*(2.0 if absf(target_speed)>.01 else 3.0))
	velocity=forward*drive_speed
	velocity.y=clampf((surface-.28-global_position.y)*7.0,-3.0,3.0)
	move_and_slide()
	if get_slide_collision_count()>0:drive_speed=Vector2(get_real_velocity().x,get_real_velocity().z).length()*signf(drive_speed)
	var gradient:Vector2=water.boat_gradient
	boat_visual.rotation.x=atan(gradient.dot(Vector2(forward.x,forward.z)))*.8
	var right:=global_basis.x
	boat_visual.rotation.z=-atan(gradient.dot(Vector2(right.x,right.z)))*.8
	if boarded:
		if player.fishing_active or _hunting_on_deck():_move_on_deck(delta)
		_sync_rider()
		if _hunting_on_deck():
			player._play_motion("Walk" if player.planar_speed > .05 else "Idle", .6 if player.planar_speed > .05 else 1.0)
		elif not player.fishing_active:player._play_motion("Paddle" if absf(throttle)>.05 else "PaddleIdle",1.35 if absf(throttle)>.05 else 1.0)

func _hunting_on_deck() -> bool:
	return is_instance_valid(player.adventure) and is_instance_valid(player.adventure.hunting) and player.adventure.hunting.equipped in ["hunting_rifle", "bow"] and player.adventure.has_good(player.adventure.hunting.equipped) and not player.fishing_active

func _sync_rider() -> void:
	var position:=boat_visual.to_global(fishing_deck_position/boat_visual.scale) if player.fishing_active or _hunting_on_deck() else seat.global_position
	player.global_transform=Transform3D(seat.global_basis.orthonormalized(),position)
	if not player.fishing_active and not _hunting_on_deck():player.visual.rotation=Vector3.ZERO
	if not player.fishing_active and not _hunting_on_deck():
		player.planar_speed=0.0
		player.fishing_move_velocity=Vector3.ZERO

func _move_on_deck(delta:float) -> void:
	var previous:=fishing_deck_position
	var local_direction:Vector3=global_basis.inverse()*player.movement_direction()
	fishing_deck_position+=local_direction*.85*delta
	fishing_deck_position.x=clampf(fishing_deck_position.x,-.38,.38)
	fishing_deck_position.z=clampf(fishing_deck_position.z,.35,.78)
	fishing_deck_position.y=.24
	player.fishing_move_velocity=global_basis*(fishing_deck_position-previous)/maxf(delta,.001)
	player.planar_speed=player.fishing_move_velocity.length()

func _process(delta:float) -> void:
	if water.water_material:
		water.water_material.set_shader_parameter("boat_cutout_enabled",true)
		water.water_material.set_shader_parameter("boat_center",Vector2(global_position.x,global_position.z))
		water.water_material.set_shader_parameter("boat_forward",Vector2(global_basis.z.x,global_basis.z.z))
	prompt.visible=(boarded or player.global_position.distance_to(global_position)<6.0) and not player.fishing_active
	if is_instance_valid(player.adventure):prompt.hide()
	if is_instance_valid(player.fishing) and is_instance_valid(player.fishing.pickup_candidate):prompt.visible=false
	prompt.text="W/S 划船 · A/D 转向 · Shift 加速 · E 下船" if boarded else "E  上船"
	paddle.visible = boarded and not player.fishing_active and not _hunting_on_deck()
	if not boarded or player.fishing_active or _hunting_on_deck():return
	var left:=_grip("LeftHand","LeftHandMiddle1")
	var right:=_grip("RightHand","RightHandMiddle1")
	var axis:=(left-right).normalized()
	var normal:=global_basis.y-axis*global_basis.y.dot(axis)
	if normal.length_squared()<.01:normal=global_basis.z-axis*global_basis.z.dot(axis)
	normal=normal.normalized()
	var x_axis:=axis.cross(normal).normalized()
	paddle.global_transform=Transform3D(Basis(x_axis,axis,x_axis.cross(axis).normalized()),(left+right)*.5)
	wake_timer-=delta
	splash_timer-=delta
	var movement_fx:=player.get_node("MovementVFX")
	var surface:float=water.boat_elevation
	for index in 2:
		var tip:=paddle.global_position+paddle.global_basis.y*(1.40 if index==0 else -1.40)
		var submerged:=tip.y<surface+.04
		if submerged and not tip_submerged[index] and splash_timer<=0.0:
			tip.y=surface+.04
			movement_fx._spawn_water(tip,.7)
			splash_timer=.25
		tip_submerged[index]=submerged

func _grip(hand_name:String,finger_name:String) -> Vector3:
	var wrist:=skeleton.get_bone_global_pose(skeleton.find_bone(hand_name)).origin
	var finger:=skeleton.get_bone_global_pose(skeleton.find_bone(finger_name)).origin
	return skeleton.to_global(wrist.lerp(finger,.65))

func apply_upgrade() -> void:
	if upgraded:return
	for child in boat_visual.get_children():
		if child is Node3D and child!=seat:child.hide()
	var replacement:Node3D=load("res://assets/adventure/voyager_boat.glb").instantiate()
	boat_visual.add_child(replacement)
	replacement.scale=Vector3.ONE/boat_visual.scale
	(hull.shape as BoxShape3D).size=Vector3(1.9,.75,4.65)
	cruise_speed=9.0;boost_speed=12.0;upgraded=true
