from pathlib import Path
p=Path(r'D:\浪费GPT额度\小温的游戏\游戏\scripts\player\skinning_grip.gd')
s=p.read_text(encoding='utf8')
s=s.replace('func _match_forearm_roll(sk: Skeleton3D, dorsal: Vector3) -> void:\n\tvar index := sk.find_bone("RightForeArm")','func _match_forearm_roll(sk: Skeleton3D, dorsal: Vector3, side := "Right") -> void:\n\tvar index := sk.find_bone(side + "ForeArm")')
s=s.replace('func _solve_arm(sk: Skeleton3D, target: Vector3) -> void:\n\tvar upper := sk.find_bone("RightArm")\n\tvar lower := sk.find_bone("RightForeArm")\n\tvar hand := sk.find_bone("RightHand")','func _solve_arm(sk: Skeleton3D, target: Vector3, side := "Right") -> void:\n\tvar upper := sk.find_bone(side + "Arm")\n\tvar lower := sk.find_bone(side + "ForeArm")\n\tvar hand := sk.find_bone(side + "Hand")')
s=s.replace('func _solve_leg(sk: Skeleton3D, side: String, target: Vector3, pole: Vector3) -> void:', '''	if crouch > .05:
		# Rest the free hand over the knee; the source open fingers stay intact.
		var knee := sk.get_bone_global_pose(sk.find_bone("LeftLeg")).origin
		var fingers := (forward - up * .30).normalized()
		var dorsal := (up - fingers * up.dot(fingers)).normalized()
		var support_basis := Basis(fingers.cross(dorsal), fingers, dorsal)
		_solve_arm(sk, knee + up * .10 - forward * .08, "Left")
		_match_forearm_roll(sk, dorsal, "Left")
		var support_index := sk.find_bone("LeftHand")
		var support := sk.get_bone_global_pose(support_index)
		support.basis = support_basis
		sk.set_bone_global_pose(support_index, support)

func _solve_leg(sk: Skeleton3D, side: String, target: Vector3, pole: Vector3) -> void:''')
p.write_text(s,encoding='utf8')
p=Path(r'D:\浪费GPT额度\小温的游戏\素材\06_游戏场景资产\狩猎与烹饪\剥皮小刀\validate_low_skinning.gd')
s=p.read_text(encoding='utf-8-sig').replace('"res://assets/fauna/marine/BrownFish.glb"','("res://assets/fauna/marine/BrownFish.glb" if height < .3 else "res://assets/fauna/marine/Seal.glb")')
s=s.replace('["RightForeArm","RightHand"]]','["RightForeArm","RightHand"],["LeftArm","LeftForeArm"],["LeftForeArm","LeftHand"]]')
p.write_text(s,encoding='utf8')
