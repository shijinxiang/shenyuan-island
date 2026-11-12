extends CharacterBody3D

const CRUISE_SPEED := 12.0
const BOOST_SPEED := 20.0
const REVERSE_SPEED := 6.0
const ACCELERATION := 8.0
const BOOST_ACCELERATION := 12.0
const BRAKING := 14.0
const COAST_DRAG := 6.0
const MAX_SLOPE := 50.0
const WHEELBASE := 1.7
const MAX_TURN_RATE := 1.6

var game: Node3D
var player: CharacterBody3D
var model: Node3D
var seat: Node3D
var boarded := false
var entering := false
var drive_speed := 0.0
var steering := 0.0
var saved_layer := 2
var saved_mask := 1
var enter_tween: Tween

func _ready() -> void:
	game = get_parent()
	player = game.player
	player.vehicle = self
	model = load("res://assets/vehicle/beach_buggy.glb").instantiate()
	add_child(model)
	seat = model.get_node("DriverSeat")
	# A bevel under both bumpers lets the hull pass small road lips in either direction.
	var shape := ConvexPolygonShape3D.new()
	var points := PackedVector3Array()
	for layer in [Vector3(.52,0,.70), Vector3(.675,.32,1.15), Vector3(.675,.90,1.15)]:
		for x in [-1.0,1.0]:
			for z in [-1.0,1.0]:
				points.append(Vector3(layer.x*x,layer.y,layer.z*z))
	shape.points = points
	var collision := CollisionShape3D.new()
	collision.shape = shape
	add_child(collision)
	floor_snap_length = 1.1
	floor_max_angle = deg_to_rad(MAX_SLOPE)
	floor_constant_speed = true
	floor_stop_on_slope = true
	safe_margin = .015
	var point: Array = game.progress.get("buggy_position", [])
	if point.size() == 3:
		global_position = Vector3(point[0],point[1],point[2])
		rotation.y = float(game.progress.get("buggy_yaw", 0.0))
	else:
		global_position = game.survival.cabin.to_global(Vector3(5.0,0,3.5))
		global_position.y = game.wildlife.ground.height(global_position.x,global_position.z) + .03
	_refresh_active()

func _refresh_active() -> void:
	visible = game.has_good("beach_buggy")
	collision_layer = 1 if visible else 0
	collision_mask = 1 | 2 | 4 if visible else 0

func unlock() -> void:
	var cabin: Node3D = game.survival.cabin
	for x in [5.5,-5.5,8.0,-8.0]:
		for z in [4.0,6.0,-4.0]:
			var point := cabin.to_global(Vector3(x,0,z))
			point.y = game.wildlife.ground.height(point.x,point.z)
			if point.y < .4:
				continue
			var query := PhysicsShapeQueryParameters3D.new()
			var box := BoxShape3D.new()
			box.size = Vector3(1.7,1.5,2.9)
			query.shape = box
			query.transform = Transform3D(Basis.IDENTITY,point+Vector3.UP*.8)
			query.collision_mask = 1
			query.exclude = [get_rid(),player.get_rid()]
			if get_world_3d().direct_space_state.intersect_shape(query,1).is_empty():
				global_position = point + Vector3.UP*.03
				_store_position()
				_refresh_active()
				return
	_store_position()
	_refresh_active()

func _store_position() -> void:
	game.progress.buggy_position = [global_position.x,global_position.y,global_position.z]
	game.progress.buggy_yaw = rotation.y

func context() -> Dictionary:
	if not visible:
		return {}
	if boarded:
		var speed := roundi(absf(drive_speed)*3.6)
		var hint := "Shift 加速中" if drive_speed>.1 and Input.is_action_pressed("sprint") and not player.controls_locked else "Shift 加速"
		return {"text":"E  下车 · %d km/h · %s" % [speed,hint]}
	if not entering and not player.swimming and not player.rowing.boarded and player.global_position.distance_to(global_position)<3.0:
		return {"text":"E  驾驶沙滩车"}
	return {}

func interact() -> void:
	if entering:
		return
	if boarded:
		leave_vehicle()
	elif not context().is_empty():
		board_vehicle()

func board_vehicle() -> void:
	if entering or boarded or not visible:
		return
	if player.fishing_active:
		game.fishing.set_active(false)
	entering = true
	player.interaction_time = 0
	drive_speed = 0
	saved_layer = player.collision_layer
	saved_mask = player.collision_mask
	player._set_swimming(false)
	player.collision_layer = 0
	player.collision_mask = 0
	player.velocity = Vector3.ZERO
	if player.visual_water_tween and player.visual_water_tween.is_valid():
		player.visual_water_tween.kill()
	player.global_basis = global_basis
	player.global_position = model.get_node("EntryPoint").global_position
	player.visual.transform = Transform3D.IDENTITY
	player.orbit.rotation.y = rotation.y + PI
	player._play_motion("Entering Car", player.animation.get_animation("Entering Car").length / 2.4)
	enter_tween = create_tween()
	enter_tween.tween_property(player,"global_position",seat.global_position,2.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await enter_tween.finished
	entering = false
	boarded = true
	_sync_driver()
	player._play_motion("Driving",1.0)

func leave_vehicle(force := false) -> bool:
	if not boarded and not entering:
		return true
	if enter_tween and enter_tween.is_valid():
		enter_tween.kill()
	var destination: Vector3 = player.spawn_point
	var found := force
	if not force:
		for offset in [Vector3(1.3,0,-.25),Vector3(-1.3,0,-.25),Vector3(0,0,-2.0)]:
			var point: Vector3 = global_transform * offset
			point.y = game.wildlife.ground.height(point.x,point.z)+.03
			if point.y > .2 and player._water_capsule_clear(point,false):
				destination = point
				found = true
				break
	if not found:
		game.ui.notify("车旁空间不够，先把车挪开一点。")
		return false
	boarded = false
	entering = false
	drive_speed = 0
	player.collision_layer = saved_layer
	player.collision_mask = saved_mask
	player.global_basis = Basis.IDENTITY
	player.global_position = destination
	player.visual.rotation = Vector3(0,rotation.y,0)
	player._play_motion("Idle",1.0)
	_store_position()
	game.save()
	return true

func _sync_driver() -> void:
	player.global_transform = Transform3D(model.global_basis,seat.global_position)
	player.visual.transform = Transform3D.IDENTITY
	player.planar_speed = absf(drive_speed)

func return_to_home() -> void:
	leave_vehicle(true)
	unlock()
	game.save()

func _physics_process(delta: float) -> void:
	_refresh_active()
	if not visible or entering:
		return
	var throttle := 0.0
	var turn := 0.0
	if boarded and not player.controls_locked and not game.dead:
		throttle = Input.get_action_strength("move_forward")-Input.get_action_strength("move_back")
		turn = Input.get_action_strength("move_right")-Input.get_action_strength("move_left")
	# The model faces +Z, so the driver's right is local -X.
	var steering_limit := lerpf(.55,.23,clampf(absf(drive_speed)/BOOST_SPEED,0.0,1.0))
	steering = move_toward(steering,-turn*steering_limit,delta*2.1)
	var boosting: bool = boarded and not player.controls_locked and Input.is_action_pressed("sprint")
	var target_speed := throttle * (BOOST_SPEED if boosting else CRUISE_SPEED)
	if throttle < 0:
		target_speed = throttle * REVERSE_SPEED
	var motion_sign := signf(drive_speed) if absf(drive_speed) > .15 else signf(target_speed)
	var stopping_distance := 1.8 + drive_speed * drive_speed / (2.0 * BRAKING)
	var ahead := global_position + global_basis.z * motion_sign * stopping_distance
	var floor_ahead: float = game.wildlife.ground.height(ahead.x,ahead.z)
	var current_ground: float = game.wildlife.ground.height(global_position.x,global_position.z)
	var recovering_from_shore := current_ground < .2 and floor_ahead > current_ground + .02
	if floor_ahead < .2 and not recovering_from_shore:
		target_speed = 0
	var opposing_input := absf(throttle) > .01 and absf(drive_speed) > .15 and signf(throttle) != signf(drive_speed)
	var acceleration := BOOST_ACCELERATION if boosting and throttle > 0 else ACCELERATION
	if opposing_input or (absf(throttle) > .01 and is_zero_approx(target_speed)):
		acceleration = BRAKING
	elif is_zero_approx(throttle):
		acceleration = COAST_DRAG
	drive_speed = move_toward(drive_speed,target_speed,delta*acceleration)
	if absf(drive_speed)>.05:
		var yaw_rate := clampf(tan(steering)*drive_speed/WHEELBASE,-MAX_TURN_RATE,MAX_TURN_RATE)
		rotation.y += yaw_rate * delta
	var forward := global_basis.z.normalized()
	var direction := forward
	if is_on_floor():
		direction = forward.slide(get_floor_normal()).normalized()
	velocity.x = direction.x * drive_speed
	velocity.z = direction.z * drive_speed
	velocity.y = direction.y * drive_speed - 24.0*delta if is_on_floor() else velocity.y - 24.0*delta
	var previous_position := global_position
	move_and_slide()
	var new_ground: float = game.wildlife.ground.height(global_position.x,global_position.z)
	if new_ground < .15 and new_ground <= current_ground:
		global_position = previous_position
		drive_speed = 0
		velocity = Vector3.ZERO
	var front: Vector3 = global_position + global_basis.z*.85
	var back: Vector3 = global_position - global_basis.z*.85
	var right: Vector3 = global_position + global_basis.x*.60
	var left: Vector3 = global_position - global_basis.x*.60
	var front_height: float = game.wildlife.ground.height(front.x,front.z)
	var back_height: float = game.wildlife.ground.height(back.x,back.z)
	var right_height: float = game.wildlife.ground.height(right.x,right.z)
	var left_height: float = game.wildlife.ground.height(left.x,left.z)
	var max_tilt := deg_to_rad(MAX_SLOPE)
	model.rotation.x = lerp_angle(model.rotation.x,clampf(-atan2(front_height-back_height,1.7),-max_tilt,max_tilt),1-exp(-delta*8))
	model.rotation.z = lerp_angle(model.rotation.z,clampf(atan2(right_height-left_height,1.2),-max_tilt,max_tilt),1-exp(-delta*8))
	# Ground contact must not consume engine speed, including on an uphill slope.
	for index in get_slide_collision_count():
		var normal := get_slide_collision(index).get_normal()
		if normal.dot(Vector3.UP) < cos(floor_max_angle) and normal.dot(direction*signf(drive_speed)) < -.25:
			var actual_speed := get_real_velocity().dot(direction)
			drive_speed = signf(drive_speed)*minf(absf(drive_speed),absf(actual_speed))
			break
	for path in ["Steer_L/Wheel_FL","Steer_R/Wheel_FR","Wheel_RL","Wheel_RR"]:
		model.get_node(path).rotate_x(drive_speed*delta/.329)
	model.get_node("Steer_L").rotation.y = steering
	model.get_node("Steer_R").rotation.y = steering
	model.get_node("SteeringWheel").rotation.z = -steering*1.5
	if boarded:
		_sync_driver()
		player._play_motion("Driving",1.0)
	_store_position()
