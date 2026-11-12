extends SkeletonModifier3D
# C01 closed fingers surround a local-X channel; local -Z is the palm.
const PALM_ANCHOR := Vector3(0.0, 0.09, -0.048)
var hunting: Node3D
var finger_pose: Dictionary = {}
var arm_pose: Dictionary = {}
var _active := false
var _water_drop := 0.0
var _water_lean := 0.0
var _water_entry_drop := 0.0
var _water_entry_lean := 0.0
const BLADE_CONTACT := Vector3(0.0, .155, .03)

func _ready() -> void:
	var clip: Animation = load("res://assets/characters/C01_watering.res")
	for t in clip.get_track_count():
		if clip.track_get_type(t) != Animation.TYPE_ROTATION_3D:
			continue
		var bone := String(clip.track_get_path(t).get_subname(0))
		if bone.begins_with("RightHand") and bone != "RightHand":
			finger_pose[bone] = clip.rotation_track_interpolate(t, 0.0)
		elif bone in ["RightShoulder", "RightArm", "RightForeArm", "RightHand"]:
			arm_pose[bone] = clip.rotation_track_interpolate(t, 0.0)
	get_skeleton().skeleton_updated.connect(sync_model)

func _process_modification_with_delta(delta: float) -> void:
	var was_active := _active
	_active = is_instance_valid(hunting) and hunting.processing_corpse
	if _active and not was_active:
		_water_entry_drop = _water_drop
		_water_entry_lean = _water_lean
	var sk := get_skeleton()
	if not _active:
		if (absf(_water_drop) > .00001 or _water_lean > .00001) and is_instance_valid(hunting) and hunting.game.player.swimming:
			_water_drop = move_toward(_water_drop, 0.0, delta * 4.0)
			_water_lean = move_toward(_water_lean, 0.0, delta * 2.0)
			_lean_water_torso(sk, _water_lean)
			_shift_water_hips(sk, _water_drop)
		else:
			_water_drop = 0.0
			_water_lean = 0.0
		return
	for name in arm_pose:
		sk.set_bone_pose_rotation(sk.find_bone(name), arm_pose[name])
	for name in finger_pose:
		sk.set_bone_pose_rotation(sk.find_bone(name), finger_pose[name])
	var visual: Node3D = hunting.game.player.visual
	var forward := (sk.global_basis.inverse() * visual.global_basis.z).normalized()
	var up := (sk.global_basis.inverse() * Vector3.UP).normalized()
	var phase: float = sin(clampf(hunting.processing_progress, 0.0, 1.0) * TAU * 3.0)
	var target: Vector3 = sk.global_transform.affine_inverse() * hunting.processing_target
	if not hunting.game.player.swimming:
		_water_drop = 0.0
		_water_lean = 0.0
		_lower_to_target(sk, target, forward, up)
	else:
		# Immerse the authored tread pose as a unit. The free arm and kicking
		# legs retain their local animation rotations and exact bone lengths.
		var source_shoulder := sk.get_bone_global_pose(sk.find_bone("RightArm")).origin
		var entry := smoothstep(0.0, .12, hunting.processing_progress)
		var desired_lean := clampf(((target-source_shoulder).dot(forward) - .35) * 1.5, 0.0, .45)
		_water_lean = lerpf(_water_entry_lean, desired_lean, entry)
		_lean_water_torso(sk, _water_lean)
		source_shoulder = sk.get_bone_global_pose(sk.find_bone("RightArm")).origin
		var desired_drop := clampf((source_shoulder-target).dot(up) - .34, -.50, 1.05)
		_water_drop = lerpf(_water_entry_drop, desired_drop, entry)
		_shift_water_hips(sk, _water_drop)
	var axis := (forward - up * .65).normalized()
	var across := -axis
	var body := sk.get_bone_global_pose(sk.find_bone("Spine2"))
	var inward := body.basis.x.normalized()
	inward = (inward - across * inward.dot(across)).normalized()
	var dorsal := -inward
	var hand_basis := Basis(across, dorsal.cross(across).normalized(), dorsal)
	var shoulder := sk.get_bone_global_pose(sk.find_bone("RightArm")).origin
	var blade_basis := Basis(axis.cross(hand_basis.y), axis, hand_basis.y)
	# Move the honed belly across the surface, not the grip point above it.
	var center := target - blade_basis * BLADE_CONTACT + forward * phase * .018
	_solve_arm(sk, center - hand_basis * PALM_ANCHOR)
	_match_forearm_roll(sk, hand_basis.z)
	var index := sk.find_bone("RightHand")
	var pose := sk.get_bone_global_pose(index)
	pose.basis = hand_basis
	sk.set_bone_global_pose(index, pose)

func sync_model() -> void:
	if not is_instance_valid(hunting) or not is_instance_valid(hunting.knife_model):
		return
	hunting.knife_model.visible = _active
	if not _active:
		return
	var sk := get_skeleton()
	var hand := sk.global_transform * sk.get_bone_global_pose(sk.find_bone("RightHand"))
	# Knife +Y follows right-hand -X. Its cutting edge +Z follows fingers +Y.
	var shaft := -hand.basis.x.normalized()
	var edge := hand.basis.y.normalized()
	hunting.knife_model.global_transform = Transform3D(Basis(shaft.cross(edge), shaft, edge), hand * PALM_ANCHOR)

func _match_forearm_roll(sk: Skeleton3D, dorsal: Vector3, side := "Right") -> void:
	var index := sk.find_bone(side + "ForeArm")
	var pose := sk.get_bone_global_pose(index)
	var along := pose.basis.y.normalized()
	var reference := pose.basis.z - along * pose.basis.z.dot(along)
	var target := dorsal - along * dorsal.dot(along)
	if target.length_squared() > .00001 and reference.length_squared() > .00001:
		pose.basis = Basis(along, reference.normalized().signed_angle_to(target.normalized(), along)) * pose.basis
		sk.set_bone_global_pose(index, pose)

func _solve_arm(sk: Skeleton3D, target: Vector3, side := "Right") -> void:
	var upper := sk.find_bone(side + "Arm")
	var lower := sk.find_bone(side + "ForeArm")
	var hand := sk.find_bone(side + "Hand")
	var a := sk.get_bone_global_pose(upper).origin
	var b := sk.get_bone_global_pose(lower).origin
	var c := sk.get_bone_global_pose(hand).origin
	var la := a.distance_to(b)
	var lb := b.distance_to(c)
	var direction := (target-a).normalized()
	var distance := clampf(a.distance_to(target), absf(la-lb)+.001, la+lb-.001)
	target = a + direction * distance
	var bend := b-a-direction*(b-a).dot(direction)
	if bend.length_squared() < .000001:
		bend = direction.cross(Vector3.RIGHT)
	bend = bend.normalized()
	var along := (la*la-lb*lb+distance*distance)/(2.0*distance)
	var elbow := a+direction*along+bend*sqrt(maxf(0.0,la*la-along*along))
	var pose := sk.get_bone_global_pose(upper)
	pose.basis = Basis(Quaternion((b-a).normalized(), (elbow-a).normalized())) * pose.basis
	sk.set_bone_global_pose(upper,pose)
	b = sk.get_bone_global_pose(lower).origin
	c = sk.get_bone_global_pose(hand).origin
	pose = sk.get_bone_global_pose(lower)
	pose.basis = Basis(Quaternion((c-b).normalized(), (target-b).normalized())) * pose.basis
	sk.set_bone_global_pose(lower,pose)

func _lower_to_target(sk: Skeleton3D, target: Vector3, forward: Vector3, up: Vector3) -> void:
	var foot_poses: Dictionary = {}
	for side in ["Left", "Right"]:
		foot_poses[side] = sk.get_bone_global_pose(sk.find_bone(side + "Foot"))
	var foot_height: float = (foot_poses["Left"].origin.dot(up) + foot_poses["Right"].origin.dot(up)) * .5
	var surface_height := target.dot(up) - foot_height
	var crouch := clampf((.72 - surface_height) / .65, 0.0, 1.0)
	var hips_index := sk.find_bone("Hips")
	var hips := sk.get_bone_global_pose(hips_index)
	hips.origin += -up * (.47 * crouch) + forward * (.08 * crouch)
	sk.set_bone_global_pose(hips_index, hips)
	var spine_index := sk.find_bone("Spine")
	var spine := sk.get_bone_global_pose(spine_index)
	spine.basis = Basis(up.cross(forward).normalized(), .72 * crouch) * spine.basis
	sk.set_bone_global_pose(spine_index, spine)
	# Pin both original ankles. Only joint rotations change limb lengths.
	for side in ["Left", "Right"]:
		var foot: Transform3D = foot_poses[side]
		_solve_leg(sk, side, foot.origin, forward)
		foot.origin = sk.get_bone_global_pose(sk.find_bone(side + "Foot")).origin
		sk.set_bone_global_pose(sk.find_bone(side + "Foot"), foot)

	if crouch > .05:
		# Rest the free hand over the knee; the source open fingers stay intact.
		var knee := sk.get_bone_global_pose(sk.find_bone("LeftLeg")).origin
		var fingers := (forward - up * .30).normalized()
		var dorsal := (up - fingers * up.dot(fingers)).normalized()
		var support_basis := Basis(fingers.cross(dorsal), fingers, dorsal)
		_solve_arm(sk, knee + up * .24 - forward * .10, "Left")
		_match_forearm_roll(sk, dorsal, "Left")
		var support_index := sk.find_bone("LeftHand")
		var support := sk.get_bone_global_pose(support_index)
		support.basis = support_basis
		sk.set_bone_global_pose(support_index, support)

func _solve_leg(sk: Skeleton3D, side: String, target: Vector3, pole: Vector3) -> void:
	var upper := sk.find_bone(side + "UpLeg")
	var lower := sk.find_bone(side + "Leg")
	var foot := sk.find_bone(side + "Foot")
	var a := sk.get_bone_global_pose(upper).origin
	var b := sk.get_bone_global_pose(lower).origin
	var c := sk.get_bone_global_pose(foot).origin
	var la := a.distance_to(b)
	var lb := b.distance_to(c)
	var direction := (target-a).normalized()
	var distance := clampf(a.distance_to(target), absf(la-lb)+.001, la+lb-.001)
	target = a+direction*distance
	var bend := (pole-direction*pole.dot(direction)).normalized()
	var along := (la*la-lb*lb+distance*distance)/(2.0*distance)
	var knee := a+direction*along+bend*sqrt(maxf(0.0,la*la-along*along))
	var pose := sk.get_bone_global_pose(upper)
	pose.basis = Basis(Quaternion((b-a).normalized(), (knee-a).normalized())) * pose.basis
	sk.set_bone_global_pose(upper,pose)
	b = sk.get_bone_global_pose(lower).origin
	c = sk.get_bone_global_pose(foot).origin
	pose = sk.get_bone_global_pose(lower)
	pose.basis = Basis(Quaternion((c-b).normalized(), (target-b).normalized())) * pose.basis
	sk.set_bone_global_pose(lower,pose)


func _shift_water_hips(sk: Skeleton3D, distance: float) -> void:
	var index := sk.find_bone("Hips")
	var pose := sk.get_bone_global_pose(index)
	pose.origin -= (sk.global_basis.inverse() * Vector3.UP).normalized() * distance
	sk.set_bone_global_pose(index, pose)


func _lean_water_torso(sk: Skeleton3D, angle: float) -> void:
	var visual: Node3D = hunting.game.player.visual
	var axis := sk.global_basis.inverse() * Vector3.UP.cross(visual.global_basis.z.normalized())
	var index := sk.find_bone("Spine")
	var pose := sk.get_bone_global_pose(index)
	pose.basis = Basis(axis.normalized(), angle) * pose.basis
	sk.set_bone_global_pose(index, pose)

