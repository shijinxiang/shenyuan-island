extends SceneTree
const FOLDER := "D:/浪费GPT额度/小温的游戏/素材/06_游戏场景资产/农耕与伐木/动作/"
func _initialize() -> void: call_deferred("run")
func vec(v: Vector3) -> Array: return [v.x,v.y,v.z]
func run() -> void:
	var character = load("res://assets/characters/C01_locomotion.glb").instantiate()
	root.add_child(character)
	var player = character.find_children("*", "AnimationPlayer", true, false)[0]
	var skeleton = character.find_children("*", "Skeleton3D", true, false)[0]
	var lib = AnimationLibrary.new()
	lib.add_animation("Chop", load("res://assets/characters/C01_chop.res"))
	lib.add_animation("Watering", load("res://assets/characters/C01_watering.res"))
	player.add_animation_library("probe", lib)
	var report := {"chop":[],"watering":[]}
	for clip_name in ["Chop","Watering"]:
		player.play("probe/"+clip_name)
		for frame in (36 if clip_name=="Chop" else 169):
			player.seek(float(frame)/30.0,true);player.advance(0);skeleton.force_update_all_bone_transforms()
			var right: Transform3D = skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone("RightHand"))
			var right_middle: Vector3 = skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone("RightHandMiddle1")).origin
			var left: Vector3 = skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone("LeftHand")).origin
			var left_middle: Vector3 = skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone("LeftHandMiddle1")).origin
			var rp := right.origin.lerp(right_middle,.65)
			var lp := left.lerp(left_middle,.65)
			if clip_name=="Chop":
				var axis := (rp-lp).normalized()
				var side := (Vector3.RIGHT-axis*axis.x).normalized()
				var basis := Basis(side,axis,side.cross(axis))
				var flipped := Basis(-side,axis,-side.cross(axis))
				report.chop.append({"frame":frame+1,"right":vec(rp),"left":vec(lp),"axis":vec(axis),"old_side":vec(side),"shaft_head":vec(rp+axis*.53),"reverse_shaft_head":vec(rp-axis*.53),"old_edge":vec(rp+basis*Vector3(.34,.53,0)),"new_edge":vec(rp+flipped*Vector3(.34,.53,0))})
			else:
				var old_basis := right.basis.orthonormalized()*Basis(Vector3(-1,0,0),Vector3(0,-1,0),Vector3(0,0,1))
				var new_basis := right.basis.orthonormalized()*Basis(Vector3(1,0,0),Vector3(0,-1,0),Vector3(0,0,-1))
				var center: Vector3=right*Vector3(0,.09,-.048)
				var old_spout:=center+old_basis*Vector3(-.435,-.155,0)
				var new_spout:=center+new_basis*Vector3(-.435,-.155,0)
				report.watering.append({"frame":frame+1,"hand":vec(center),"old_spout":vec(old_spout),"new_spout":vec(new_spout),"old_mouth_direction":vec(old_basis*Vector3(-1,1,0).normalized()),"new_mouth_direction":vec(new_basis*Vector3(-1,1,0).normalized()),"new_can_forward":vec(-new_basis.x)})
	var f:=FileAccess.open(FOLDER+"tool_direction_probe.json",FileAccess.WRITE);f.store_string(JSON.stringify(report,"\t"))
	character.free();quit()
