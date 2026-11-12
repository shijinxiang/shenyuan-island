from pathlib import Path
p=Path(r'D:\浪费GPT额度\小温的游戏\游戏\scripts\player\skinning_grip.gd')
s=p.read_text(encoding='utf-8-sig')
s=s.replace('var _active := false','var _active := false\nconst BLADE_CONTACT := Vector3(0.0, .155, .03)')
s=s.replace('var axis := (forward - up * .65).normalized()', '''var target: Vector3 = sk.global_transform.affine_inverse() * hunting.processing_target
	if not hunting.game.player.swimming:
		_lower_to_target(sk, target, forward, up)
	var axis := (forward - up * .65).normalized()''')
s=s.replace('var center := shoulder + forward * (.29 + phase * .025) - up * .37','''var blade_basis := Basis(axis.cross(hand_basis.y), axis, hand_basis.y)
	# Move the honed belly across the surface, not the grip point above it.
	var center := target - blade_basis * BLADE_CONTACT + forward * phase * .018''')
s += '''
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
'''
p.write_text(s,encoding='utf-8')
