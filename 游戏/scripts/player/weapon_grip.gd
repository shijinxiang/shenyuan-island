extends SkeletonModifier3D
# C01 upper-body overlay and two-bone IK. Model local +Z is firing direction.
const PALM_ANCHOR := Vector3(0.0, 0.09, -0.048)
var hunting: Node3D
var clips: Dictionary = {}
var model_transform := Transform3D.IDENTITY
var string_center := Vector3.ZERO
var _active := false
var reload_elapsed := 0.0
var finger_pose: Dictionary = {}
var _body_mesh: MeshInstance3D
var _original_mesh: Mesh
var _original_skin: Skin
var _bow_body_mesh: Mesh
var _bow_body_skin: Skin
var _hat_compact := false
var _bow_last_draw := 1.0
var _bow_releasing := false

func _ready() -> void:
	for id in ["gun_aim", "gun_fire", "gun_reload", "bow"]:
		clips[id] = load("res://assets/characters/C01_" + id + ".res")
	var grip: Animation = load("res://assets/characters/C01_watering.res")
	for t in grip.get_track_count():
		if grip.track_get_type(t) == Animation.TYPE_ROTATION_3D:
			var name := String(grip.track_get_path(t).get_subname(0))
			if name.begins_with("RightHand") and name != "RightHand":
				var q := grip.rotation_track_interpolate(t,0.0)
				finger_pose[name] = q
				finger_pose[name.replace("RightHand","LeftHand")] = Quaternion(q.x,-q.y,-q.z,q.w)
	get_skeleton().skeleton_updated.connect(sync_models)
	_prepare_bow_hat()

func _process_modification_with_delta(_delta: float) -> void:
	_active = is_instance_valid(hunting) and hunting.can_use() and hunting.equipped in ["hunting_rifle", "bow"]
	_set_bow_hat(_active and hunting.equipped == "bow")
	if not _active:
		return
	reload_elapsed = reload_elapsed + _delta if hunting.reloading else 0.0
	var sk := get_skeleton()
	var gun: bool = hunting.equipped == "hunting_rifle"
	if not gun:
		_apply_source_bow(sk)
		return
	var clip: Animation = clips["gun_aim" if gun else "bow"]
	var at := 0.0 if gun else lerpf(2.15, 2.5, clampf(hunting.draw_amount, 0.0, 1.0))
	if gun and hunting.shot_cooldown > 0.0:
		clip = clips["gun_fire"]
		at = clampf((0.18 - hunting.shot_cooldown) / 0.18, 0.0, 1.0) * clip.length
	elif gun and hunting.reloading:
		clip = clips["gun_reload"]
		at = clampf(reload_elapsed / maxf(hunting.reload_duration, 0.01), 0.0, 1.0) * clip.length
	for t in clip.get_track_count():
		if clip.track_get_type(t) != Animation.TYPE_ROTATION_3D:
			continue
		var name := String(clip.track_get_path(t).get_subname(0))
		if not (name.begins_with("Left") or name.begins_with("Right")) or "Leg" in name or "Foot" in name or "Toe" in name:
			continue
		if name in finger_pose:
			continue
		var index := sk.find_bone(name)
		if index >= 0:
			sk.set_bone_pose_rotation(index, clip.rotation_track_interpolate(t, at))
	for name in finger_pose:
		var index := sk.find_bone(name)
		if index >= 0:
			sk.set_bone_pose_rotation(index,finger_pose[name])
	var forward: Vector3 = hunting.aim_direction.normalized()
	if forward.length_squared() < .5:
		forward = hunting.game.player.visual.global_basis.z.normalized()
	var up := Vector3.UP
	var right := up.cross(forward)
	if right.length_squared() < .000001:
		right = Vector3.RIGHT - forward * forward.dot(Vector3.RIGHT)
	if right.length_squared() < .000001:
		right = Vector3.FORWARD - forward * forward.dot(Vector3.FORWARD)
	right = right.normalized()
	up = forward.cross(right).normalized()
	# Follow steep aim with the neck, lifting the broad brim out of the line
	# of fire instead of letting a fixed, level hat intersect the barrel.
	var neck_index := sk.find_bone("Neck")
	if neck_index >= 0:
		var neck_pose := sk.get_bone_global_pose(neck_index)
		var neck_axis := (sk.global_basis.inverse() * right).normalized()
		neck_pose.basis = Basis(neck_axis, -maxf(asin(clampf(forward.y, -1.0, 1.0)), 0.0) * .8) * neck_pose.basis
		sk.set_bone_global_pose(neck_index, neck_pose)
	var basis := Basis(right, up, forward)
	var horizontal_forward := Vector3(forward.x, 0.0, forward.z)
	if horizontal_forward.length_squared() < .000001:
		horizontal_forward = Vector3.BACK
	horizontal_forward = horizontal_forward.normalized()
	if not gun:
		# Cant a steeply aimed bow sideways so the upper limb cannot sweep
		# through the wide hat and the lower limb cannot sweep through the body.
		var cant := smoothstep(.35, .85, absf(forward.y)) * PI * .5
		basis = basis * Basis(Vector3.BACK, cant)
	var shoulder_name := "RightArm" if gun else "LeftArm"
	var shoulder: Vector3 = sk.global_transform * sk.get_bone_global_pose(sk.find_bone(shoulder_name)).origin
	var origin: Vector3
	if gun:
		var low_aim_clearance := smoothstep(.2, .9, -forward.y) * .14
		origin = shoulder + horizontal_forward * (.33 + low_aim_clearance) - Vector3.UP * .16
		if not hunting.aiming:
			basis = basis * Basis(Vector3.RIGHT, .28)
		if hunting.reloading:
			basis = basis * Basis(Vector3.RIGHT, .3)
	else:
		origin = shoulder + horizontal_forward * .40 - Vector3.UP * .29
		if not hunting.aiming:
			origin -= up * .25
	model_transform = Transform3D(basis, origin)
	var left_grip := Vector3(0,.008,.23) if gun else Vector3.ZERO
	var right_grip := Vector3.ZERO if gun else Vector3(.035,.055,lerpf(-.08,-.25,clampf(hunting.draw_amount,0,1)))
	if gun and hunting.reloading:
		right_grip += Vector3(.035,.06,.10) * sin(minf(reload_elapsed / maxf(hunting.reload_duration, .01),1.0)*PI)
	string_center = right_grip
	if not gun:
		right_grip.z = -.25
	_fit_model_to_reach(sk, left_grip, right_grip, gun)
	_place_hand(sk,"Left", model_transform * left_grip, basis.z if gun else basis.y, basis.y if gun else basis.z)
	_place_hand(sk,"Right", model_transform * right_grip, basis.y, basis.z)

# Bow uses the actual Mixamo upper-body and finger rotations. No arm IK.
# Whole-body aim rotates the source posture as one unit; the mesh follows the hand.
func _apply_source_bow(sk: Skeleton3D) -> void:
	var clip: Animation = clips["bow"]
	var draw: float = clampf(hunting.draw_amount, 0.0, 1.0)
	if draw < _bow_last_draw - .2:
		_bow_releasing = true
	if draw >= .999:
		_bow_releasing = false
	_bow_last_draw = draw
	var at := lerpf(2.15, 2.50, smoothstep(0.0, 1.0, draw))
	var blend := 0.0
	if _bow_releasing:
		if draw < .16:
			at = lerpf(2.50, 2.80, draw / .16)
		elif draw < .30:
			at = 2.80
			blend = smoothstep(.16, .30, draw)
		else:
			at = lerpf(2.15, 2.50, smoothstep(.30, 1.0, draw))
	var walking := false
	if is_instance_valid(hunting.game):
		var player = hunting.game.player
		walking = Vector2(player.velocity.x, player.velocity.z).length() > .12
	var hips_index := sk.find_bone("Hips")
	var hips_rotation := sk.get_bone_pose_rotation(hips_index)
	for t in clip.get_track_count():
		if clip.track_get_type(t) != Animation.TYPE_ROTATION_3D:
			continue
		var bone_name := String(clip.track_get_path(t).get_subname(0))
		if walking and ("Leg" in bone_name or "Foot" in bone_name or "Toe" in bone_name):
			continue
		var index := sk.find_bone(bone_name)
		if index < 0:
			continue
		var q := clip.rotation_track_interpolate(t, at)
		if blend > 0.0:
			q = q.slerp(clip.rotation_track_interpolate(t, 2.15), blend)
		sk.set_bone_pose_rotation(index, q)
	var spine_index := sk.find_bone("Spine")
	var spine_pose := sk.get_bone_global_pose(spine_index)
	if walking:
		sk.set_bone_pose_rotation(hips_index, hips_rotation.slerp(sk.get_bone_pose_rotation(hips_index), .55))
		spine_pose.origin = sk.get_bone_global_pose(spine_index).origin
		sk.set_bone_global_pose(spine_index, spine_pose)
	# Four degrees of head clearance keeps the original hair off the taut upper string.
	var bow_neck := sk.find_bone("Neck")
	var bow_neck_pose := sk.get_bone_global_pose(bow_neck)
	bow_neck_pose.basis = Basis(Vector3.BACK, deg_to_rad(-4.0)) * bow_neck_pose.basis
	sk.set_bone_global_pose(bow_neck, bow_neck_pose)
	var aim_local: Vector3 = (sk.global_basis.inverse() * hunting.aim_direction).normalized()
	if aim_local.length_squared() < .5:
		aim_local = Vector3.BACK
	# The original full-draw line is slightly to the source character's left.
	var source_forward := Vector3(.0766, 0.0, .6600).normalized()
	var aim_rotation := Basis(Quaternion(source_forward, aim_local))
	spine_pose = sk.get_bone_global_pose(spine_index)
	spine_pose.basis = aim_rotation * spine_pose.basis
	sk.set_bone_global_pose(spine_index, spine_pose)
	var left := sk.global_transform * sk.get_bone_global_pose(sk.find_bone("LeftHand"))
	var right_hand := sk.global_transform * sk.get_bone_global_pose(sk.find_bone("RightHand"))
	# Source hand rotations remain untouched. Anchors sit inside the curled fingers.
	var grip := left * Vector3(0.0, .065, -.025)
	var nock := right_hand * Vector3(0.0, .065, -.025)
	var index_hook := sk.find_bone("RightHandIndex2")
	var middle_hook := sk.find_bone("RightHandMiddle2")
	if index_hook >= 0 and middle_hook >= 0:
		nock = sk.global_transform * ((sk.get_bone_global_pose(index_hook).origin + sk.get_bone_global_pose(middle_hook).origin) * .5)
	var forward := (grip - nock).normalized()
	var up := (sk.global_basis * aim_rotation * Vector3.UP).normalized()
	var across := up.cross(forward).normalized()
	up = forward.cross(across).normalized()
	model_transform = Transform3D(Basis(across, up, forward), grip)
	string_center = model_transform.affine_inverse() * nock
	if _bow_releasing and draw < .30:
		string_center = Vector3(0.0, .045, -.08).lerp(string_center, 1.0 - smoothstep(0.0, .07, draw))

func _hand_basis(sk: Skeleton3D, axis: Vector3, along: Vector3, support := false) -> Basis:
	# Gun-only: source bow bypasses this IK. Local -Z is the palm; turn
	# the across-grip axis over while keeping the finger direction along.
	var local_axis := -(sk.global_basis.inverse() * axis).normalized()
	var local_y := (sk.global_basis.inverse() * along).normalized()
	if support:
		# Support the fore-end from below and inward, with the fingers following
		# the forearm instead of forcing an upright, backward-bent wrist.
		local_axis = -local_axis
		var right := local_y.cross(local_axis).normalized()
		local_y = (-local_y*.6-right*.8).normalized()
	var hand := Basis(local_axis, local_y, local_axis.cross(local_y).normalized())
	return hand if support else Basis(local_axis, .2) * hand

func _fit_model_to_reach(sk: Skeleton3D, left_grip: Vector3, right_grip: Vector3, gun: bool) -> void:
	# Project the shared weapon origin into both arms' reachable wrist spheres.
	# Moving the weapon preserves the exact grip spacing and avoids stretching bones.
	var basis := model_transform.basis
	for iteration in 16:
		var largest_excess := 0.0
		for side in ["Left", "Right"]:
			var upper := sk.get_bone_global_pose(sk.find_bone(side + "Arm")).origin
			var lower := sk.get_bone_global_pose(sk.find_bone(side + "ForeArm")).origin
			var hand := sk.get_bone_global_pose(sk.find_bone(side + "Hand")).origin
			var radius := upper.distance_to(lower) + lower.distance_to(hand) - .003
			var support: bool = side == "Left" and gun
			var wrist_basis := _hand_basis(sk, basis.z if support else basis.y, basis.y if support else basis.z, support)
			var grip := left_grip if side == "Left" else right_grip
			var wrist := sk.global_transform.affine_inverse() * (model_transform * grip) - wrist_basis * PALM_ANCHOR
			var offset := wrist - upper
			var excess := offset.length() - radius
			if excess > 0.0:
				model_transform.origin -= sk.global_basis * offset.normalized() * excess
				largest_excess = maxf(largest_excess, excess)
		if largest_excess < .00001:
			break

func _place_hand(sk: Skeleton3D, side: String, center: Vector3, axis: Vector3, along: Vector3) -> void:
	var index := sk.find_bone(side + "Hand")
	var pose := sk.get_bone_global_pose(index)
	pose.basis = _hand_basis(sk, axis, along, side == "Left")
	var desired := sk.global_transform.affine_inverse() * center - pose.basis * PALM_ANCHOR
	_solve_arm(sk,side,desired,pose.basis.y if side == "Right" else Vector3.ZERO)
	pose.origin = sk.get_bone_global_pose(index).origin
	_match_forearm_roll(sk, side, pose.basis.z)
	sk.set_bone_global_pose(index,pose)

func _match_forearm_roll(sk: Skeleton3D, side: String, dorsal: Vector3) -> void:
	# Match the inward grip with forearm pronation, not a wrist half-turn.
	var index := sk.find_bone(side + "ForeArm")
	var pose := sk.get_bone_global_pose(index)
	var along := pose.basis.y.normalized()
	var reference := pose.basis.z - along * pose.basis.z.dot(along)
	var target := dorsal - along * dorsal.dot(along)
	if target.length_squared() > .00001 and reference.length_squared() > .00001:
		pose.basis = Basis(along, reference.normalized().signed_angle_to(target.normalized(), along)) * pose.basis
		sk.set_bone_global_pose(index, pose)
func sync_models() -> void:
	if not _active or not is_instance_valid(hunting):
		return
	var model: Node3D = hunting.models.get(hunting.equipped)
	if not is_instance_valid(model):
		return
	model.global_transform = model_transform
	if hunting.equipped == "bow":
		# Replace the exported rest string with two live segments meeting at the draw hand.
		for name in ["StringUpper","StringLower"]:
			var part := model.find_child(name,true,false) as Node3D
			if part:
				part.visible = false
		var center := string_center
		_string_segment(model,"LiveUpper",Vector3(0,.64,-.08),center)
		_string_segment(model,"LiveLower",Vector3(0,-.64,-.08),center)
		var arrow := model.get_node_or_null("NockedArrow") as Node3D
		if arrow == null:
			arrow = load("res://assets/hunting/wooden_arrow.glb").instantiate()
			arrow.name = "NockedArrow"
			model.add_child(arrow)
		arrow.visible = hunting.aiming and (not _bow_releasing or hunting.draw_amount >= .30)
		var arrow_forward := (Vector3(0, .045, 0) - string_center).normalized()
		var arrow_right := Vector3.UP.cross(arrow_forward).normalized()
		arrow.basis = Basis(arrow_right, arrow_forward.cross(arrow_right), arrow_forward)
		arrow.position = string_center + arrow_forward * .38

func _string_segment(model: Node3D,name: String,a:Vector3,b:Vector3) -> void:
	var mesh := model.get_node_or_null(name) as MeshInstance3D
	if mesh == null:
		mesh = MeshInstance3D.new()
		mesh.name=name
		var cylinder := CylinderMesh.new()
		cylinder.top_radius=.0018
		cylinder.bottom_radius=.0018
		cylinder.radial_segments=6
		mesh.mesh=cylinder
		var material := StandardMaterial3D.new()
		material.albedo_color=Color(.65,.47,.25)
		mesh.material_override=material
		model.add_child(mesh)
	mesh.position=(a+b)*.5
	mesh.basis=Basis(Quaternion(Vector3.UP,(b-a).normalized()))
	mesh.scale=Vector3(1,a.distance_to(b)/2.0,1)

func _solve_arm(skeleton: Skeleton3D, side: String, target: Vector3, fingers := Vector3.ZERO) -> void:
	var upper := skeleton.find_bone(side + "Arm")
	var lower := skeleton.find_bone(side + "ForeArm")
	var hand := skeleton.find_bone(side + "Hand")
	var a := skeleton.get_bone_global_pose(upper).origin
	var b := skeleton.get_bone_global_pose(lower).origin
	var c := skeleton.get_bone_global_pose(hand).origin
	var length_a := a.distance_to(b)
	var length_b := b.distance_to(c)
	var offset := target - a
	if offset.length_squared() < .000001:
		offset = c - a
	if offset.length_squared() < .000001:
		offset = Vector3.DOWN
	var direction := offset.normalized()
	var distance := clampf(a.distance_to(target), absf(length_a - length_b) + .0001, length_a + length_b - .0001)
	target = a + direction * distance
	var bend := b-a-direction*(b-a).dot(direction)
	if fingers.length_squared() > .5:
		var hand_bend := -fingers + direction * fingers.dot(direction)
		if hand_bend.length_squared() > .000001:
			bend = hand_bend
	if bend.length_squared() < .000001:
		var reference := Vector3.UP if absf(direction.dot(Vector3.UP)) < .9 else Vector3.RIGHT
		bend = direction.cross(reference)
	bend = bend.normalized()
	var along := (length_a*length_a-length_b*length_b+distance*distance)/(2.0*distance)
	var elbow := a+direction*along+bend*sqrt(maxf(0.0,length_a*length_a-along*along))
	var pose := skeleton.get_bone_global_pose(upper)
	pose.basis = Basis(Quaternion((b-a).normalized(), (elbow-a).normalized())) * pose.basis
	skeleton.set_bone_global_pose(upper,pose)
	b = skeleton.get_bone_global_pose(lower).origin
	c = skeleton.get_bone_global_pose(hand).origin
	pose = skeleton.get_bone_global_pose(lower)
	pose.basis = Basis(Quaternion((c-b).normalized(), (target-b).normalized())) * pose.basis
	skeleton.set_bone_global_pose(lower,pose)




func _prepare_bow_hat() -> void:
	var sk := get_skeleton()
	for candidate in sk.find_children("*", "MeshInstance3D", true, false):
		if candidate.skin != null:
			_body_mesh = candidate
			break
	if not is_instance_valid(_body_mesh):
		return
	_original_mesh = _body_mesh.mesh
	_original_skin = _body_mesh.skin
	var variant: Node3D = load("res://assets/hunting/C01_bow_hat.glb").instantiate()
	for candidate in variant.find_children("*", "MeshInstance3D", true, false):
		if candidate.skin != null:
			_bow_body_mesh = candidate.mesh
			_bow_body_skin = candidate.skin
			break
	variant.free()
func _set_bow_hat(stowed: bool) -> void:
	if not is_instance_valid(_body_mesh) or _bow_body_mesh == null or _hat_compact == stowed:
		return
	_hat_compact = stowed
	_body_mesh.mesh = _bow_body_mesh if stowed else _original_mesh
	_body_mesh.skin = _bow_body_skin if stowed else _original_skin









