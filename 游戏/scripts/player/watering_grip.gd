extends SkeletonModifier3D

# The closed watering hand also supplies a cylindrical grip. Its empty grip
# channel runs along local X, in front of the palm (negative local Z).
const PALM_ANCHOR := Vector3(0.0, 0.09, -0.048)
const CARRY_ARM := ["RightShoulder", "RightArm", "RightForeArm", "RightHand"]
var farming: Node3D
var finger_rotations: Dictionary = {}
var carry_rotations: Dictionary = {}
var left_finger_rotations: Dictionary = {}

func _ready() -> void:
	var skeleton := get_skeleton()
	var clip: Animation = load("res://assets/characters/C01_watering.res")
	for track in clip.get_track_count():
		if clip.track_get_type(track) != Animation.TYPE_ROTATION_3D:
			continue
		var bone := String(clip.track_get_path(track).get_subname(0))
		var index := skeleton.find_bone(bone)
		if index < 0:
			continue
		var rotation := clip.rotation_track_interpolate(track, 0.0)
		if bone.begins_with("RightHand") and bone != "RightHand":
			finger_rotations[index] = rotation
			var left_index := skeleton.find_bone(bone.replace("RightHand", "LeftHand"))
			left_finger_rotations[left_index] = Quaternion(rotation.x, -rotation.y, -rotation.z, rotation.w)
		elif bone in CARRY_ARM:
			carry_rotations[index] = rotation

func _process_modification_with_delta(_delta: float) -> void:
	if not is_instance_valid(farming):
		return
	var game = farming.game
	var player = game.player
	if is_instance_valid(game.hunting) and game.hunting.processing_corpse:
		return
	if player.current_motion == "Harvest":
		return
	var tool: String = farming.base_tool(farming.selected_tool)
	var spear: bool = game.harpoon_equipped and not game.cinematic_active and not game.dead and not player.fishing_active and not player.swim_moving and not player.in_vehicle()
	if not spear and (tool.is_empty() or not farming.on_land()):
		return
	var skeleton := get_skeleton()
	for index: int in finger_rotations:
		skeleton.set_bone_pose_rotation(index, finger_rotations[index])
	# Preserve the existing Watering correction without changing its wrist.
	if tool == "watering_can" and not spear:
		if player.current_motion != "Watering":
			for index: int in carry_rotations:
				skeleton.set_bone_pose_rotation(index, carry_rotations[index])
		return
	# A stable bent carrying arm keeps the shaft clear of the thigh during gait.
	# Chop supplies its own two-handed shoulder/elbow movement.
	if player.current_motion != "Chop":
		for index: int in carry_rotations:
			skeleton.set_bone_pose_rotation(index, carry_rotations[index])
		var reach := -.65
		if not spear and farming.swing_remaining > 0.0:
			reach += .7 * sin((1.0 - farming.swing_remaining / .5) * PI)
		elif spear:
			reach -= .3 * sin(clampf((1.0 - game.capture_cooldown) / .35, 0.0, 1.0) * PI)
		_rotate_joint(skeleton, "RightArm", player.visual.global_basis.x.normalized(), reach)
		if not spear and farming.swing_remaining > 0.0:
			_rotate_joint(skeleton, "RightArm", player.visual.global_basis.z.normalized(), -.3 * sin((1.0 - farming.swing_remaining / .5) * PI))
	var forward: Vector3 = player.visual.global_basis.z.normalized()
	var elevation := .15 if spear else .8
	if not spear and farming.swing_remaining > 0.0:
		elevation -= sin((1.0 - farming.swing_remaining / .5) * PI) * 1.5
	var axis := (forward * cos(elevation) + Vector3.UP * sin(elevation)).normalized()
	if tool == "axe" and player.current_motion == "Chop" and not spear:
		var right: Vector3 = game.fishing._hand_center("RightHand", "RightHandMiddle1")
		var left: Vector3 = game.fishing._hand_center("LeftHand", "LeftHandMiddle1")
		if right.distance_to(left) > .035:
			axis = (right-left).normalized()
			var head: Vector3 = skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone("Head")).origin
			var outward := right-head
			outward.y = 0.0
			if outward.length_squared() > .001:
				axis = (axis + outward.normalized() * .5 * clampf((axis.y-.1)/.4,0.0,1.0)).normalized()
	_align_wrist(skeleton, "RightHand", axis)
	if tool == "axe" and player.current_motion == "Chop" and not spear:
		for index: int in left_finger_rotations:
			skeleton.set_bone_pose_rotation(index, left_finger_rotations[index])
		_align_wrist(skeleton, "LeftHand", axis)
		var right_pose := skeleton.get_bone_global_pose(skeleton.find_bone("RightHand"))
		var left_pose := skeleton.get_bone_global_pose(skeleton.find_bone("LeftHand"))
		var local_axis := (skeleton.global_basis.inverse() * axis).normalized()
		left_pose.basis = _swing_hand_basis(skeleton, "Left", right_pose * PALM_ANCHOR - local_axis * .17, local_axis, left_pose.basis)
		var target := right_pose * PALM_ANCHOR - local_axis * .17 - left_pose.basis * PALM_ANCHOR
		# Bring the main hand toward the supporting shoulder when a blended
		# wind-up pose would put the lower grip beyond the left arm's reach.
		var shoulder := skeleton.get_bone_global_pose(skeleton.find_bone("LeftArm")).origin
		var elbow := skeleton.get_bone_global_pose(skeleton.find_bone("LeftForeArm")).origin
		var reach := shoulder.distance_to(elbow) + elbow.distance_to(left_pose.origin) - .003
		var excess := shoulder.distance_to(target) - reach
		if excess > 0.0:
			_solve_arm(skeleton, "Right", right_pose.origin + (shoulder-target).normalized() * excess, right_pose.basis.y)
			right_pose.origin = skeleton.get_bone_global_pose(skeleton.find_bone("RightHand")).origin
			_match_forearm_roll(skeleton, "Right", right_pose.basis.z)
			skeleton.set_bone_global_pose(skeleton.find_bone("RightHand"), right_pose)
			left_pose.basis = _swing_hand_basis(skeleton, "Left", right_pose * PALM_ANCHOR - local_axis * .17, local_axis, left_pose.basis)
			target = right_pose * PALM_ANCHOR - local_axis * .17 - left_pose.basis * PALM_ANCHOR
		_solve_arm(skeleton, "Left", target, left_pose.basis.y)
		left_pose.origin = skeleton.get_bone_global_pose(skeleton.find_bone("LeftHand")).origin
		_match_forearm_roll(skeleton, "Left", left_pose.basis.z)
		skeleton.set_bone_global_pose(skeleton.find_bone("LeftHand"), left_pose)

func _align_wrist(skeleton: Skeleton3D, bone: String, world_axis: Vector3) -> void:
	var side := "Right" if bone == "RightHand" else "Left"
	var index := skeleton.find_bone(bone)
	var pose := skeleton.get_bone_global_pose(index)
	var shaft := (skeleton.global_basis.inverse() * world_axis).normalized()
	# Preserve the cleared tool path while turning the hand over the handle.
	var source_basis := pose.basis
	var old_axis := shaft if side == "Right" else -shaft
	var old_basis := Basis(Quaternion(pose.basis.x.normalized(), old_axis)) * pose.basis
	var center := pose.origin + old_basis * PALM_ANCHOR

	# C01 local -Z is the palm; -X runs toward the tool head for the right
	# hand. This keeps the finger direction continuous with the forearm.
	var across := -shaft if side == "Right" else shaft
	var body := skeleton.get_bone_global_pose(skeleton.find_bone("Spine2"))
	var inward := body.basis.x.normalized() * (1.0 if side == "Right" else -1.0)
	inward = inward - across * inward.dot(across)
	if inward.length_squared() < .001:
		inward = Vector3.DOWN - across * Vector3.DOWN.dot(across)
	var dorsal := -inward.normalized()
	pose.basis = Basis(across, dorsal.cross(across).normalized(), dorsal)
	if farming.game.player.current_motion == "Chop":
		# Choose a reachable inward roll through the follow-through; a fixed
		# torso-space palm normal would force the wrist to bend backwards.
		pose.basis = _swing_hand_basis(skeleton, side, center, across, source_basis)
	_solve_arm(skeleton, side, center - pose.basis * PALM_ANCHOR, pose.basis.y)
	pose.origin = skeleton.get_bone_global_pose(index).origin
	_match_forearm_roll(skeleton, side, pose.basis.z)
	skeleton.set_bone_global_pose(index, pose)

func _swing_hand_basis(skeleton: Skeleton3D, side: String, center: Vector3, across: Vector3, source: Basis) -> Basis:
	# Select roll in the inward-facing half of the grip circle, scoring the
	# wrist angle after a length-preserving elbow solve. This avoids forcing
	# a static palm normal onto a moving two-handed swing.
	var shoulder := skeleton.get_bone_global_pose(skeleton.find_bone(side + "Arm")).origin
	var elbow := skeleton.get_bone_global_pose(skeleton.find_bone(side + "ForeArm")).origin
	var wrist := skeleton.get_bone_global_pose(skeleton.find_bone(side + "Hand")).origin
	var upper_length := shoulder.distance_to(elbow)
	var lower_length := elbow.distance_to(wrist)
	var inward := skeleton.get_bone_global_pose(skeleton.find_bone("Spine2")).basis.x.normalized() * (1.0 if side == "Right" else -1.0)
	var dorsal := -(inward-across*inward.dot(across)).normalized()
	var base := Basis(across,dorsal.cross(across).normalized(),dorsal)
	var best := base
	var best_score := INF
	for step in 49:
		var roll := lerpf(-PI*.49,PI*.49,float(step)/48.0)
		var candidate := Basis(across,roll)*base
		var target := center-candidate*PALM_ANCHOR
		var offset := target-shoulder
		var direction := offset.normalized()
		var distance := clampf(offset.length(),.01,upper_length+lower_length-.0001)
		var along := (upper_length*upper_length-lower_length*lower_length+distance*distance)/(2.0*distance)
		var bend := -candidate.y+direction*candidate.y.dot(direction)
		if bend.length_squared() < .000001:
			continue
		var solved_elbow := shoulder+direction*along+bend.normalized()*sqrt(maxf(0.0,upper_length*upper_length-along*along))
		var flex := candidate.y.dot((target-solved_elbow).normalized())
		var facing := -candidate.z.dot(inward)
		var excess := maxf(0.0,offset.length()-upper_length-lower_length+.003)
		var score := (1.0-flex)*10.0+(1.0-facing)+(1.0-candidate.y.dot(source.y.normalized()))*.1+excess*100.0
		if score < best_score:
			best_score = score
			best = candidate
	return best
func _match_forearm_roll(skeleton: Skeleton3D, side: String, dorsal: Vector3) -> void:
	# Put pronation/supination into the forearm's long axis rather than a
	# half-turn at the wrist. Neither elbow nor wrist position is translated.
	var index := skeleton.find_bone(side + "ForeArm")
	var pose := skeleton.get_bone_global_pose(index)
	var along := pose.basis.y.normalized()
	var reference := pose.basis.z - along * pose.basis.z.dot(along)
	var target := dorsal - along * dorsal.dot(along)
	if target.length_squared() > .00001 and reference.length_squared() > .00001:
		var roll := reference.normalized().signed_angle_to(target.normalized(), along)
		pose.basis = Basis(along, roll) * pose.basis
		skeleton.set_bone_global_pose(index, pose)
func _rotate_joint(skeleton: Skeleton3D, bone: String, world_axis: Vector3, angle: float) -> void:
	var index := skeleton.find_bone(bone)
	var pose := skeleton.get_bone_global_pose(index)
	pose.basis = Basis((skeleton.global_basis.inverse() * world_axis).normalized(), angle) * pose.basis
	skeleton.set_bone_global_pose(index, pose)

func _solve_arm(skeleton: Skeleton3D, side: String, target: Vector3, fingers := Vector3.ZERO) -> void:
	var upper := skeleton.find_bone(side + "Arm")
	var lower := skeleton.find_bone(side + "ForeArm")
	var hand := skeleton.find_bone(side + "Hand")
	var a := skeleton.get_bone_global_pose(upper).origin
	var b := skeleton.get_bone_global_pose(lower).origin
	var c := skeleton.get_bone_global_pose(hand).origin
	var length_a := a.distance_to(b)
	var length_b := b.distance_to(c)
	var direction := (target-a).normalized()
	var distance := clampf(a.distance_to(target), .01, length_a+length_b-.0001)
	var bend := b-a-direction*(b-a).dot(direction)
	if fingers.length_squared() > .5:
		var hand_bend := -fingers + direction * fingers.dot(direction)
		if hand_bend.length_squared() > .000001:
			bend = hand_bend
	if bend.length_squared() < .000001:
		bend = direction.cross(Vector3.FORWARD)
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













