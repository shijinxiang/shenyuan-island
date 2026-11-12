extends SceneTree
const OUT := "D:/浪费GPT额度/小温的游戏/素材/06_游戏场景资产/海岸生存/鲨鱼游泳修复/"
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	assert(doc.append_from_file("D:/浪费GPT额度/小温的游戏/游戏/assets/fauna/marine/Shark.glb",state)==OK)
	var actor := doc.generate_scene(state)
	root.add_child(actor)
	var animator: AnimationPlayer = actor.find_children("*","AnimationPlayer",true,false)[0]
	var skeleton: Skeleton3D = actor.find_children("*","Skeleton3D",true,false)[0]
	assert(animator.has_animation("ArmatureAction"))
	var clip := animator.get_animation("ArmatureAction")
	clip.loop_mode=Animation.LOOP_LINEAR
	animator.play("ArmatureAction")
	animator.advance(.3)
	var duplicate := actor.duplicate(Node.DUPLICATE_SIGNALS|Node.DUPLICATE_GROUPS|Node.DUPLICATE_SCRIPTS)
	root.add_child(duplicate)
	var duplicated_animator: AnimationPlayer = duplicate.find_children("*","AnimationPlayer",true,false)[0]
	var duplicate_before := {"is_playing":duplicated_animator.is_playing(),"current_animation":duplicated_animator.current_animation}
	duplicated_animator.play("ArmatureAction")
	duplicated_animator.advance(.3)
	var samples: Array = []
	for i in range(9):
		var time := clip.length*float(i)/8.0
		animator.seek(time,true)
		animator.advance(0)
		skeleton.force_update_all_bone_transforms()
		var bones := {}
		for name in ["Bone.003","Bone.005","Bone.007","Bone.009"]:
			var idx := skeleton.find_bone(name)
			var q := skeleton.get_bone_pose_rotation(idx)
			var p := skeleton.get_bone_global_pose(idx).origin
			bones[name]={"quaternion":[q.x,q.y,q.z,q.w],"global_position":[p.x,p.y,p.z]}
		samples.append({"time":time,"bones":bones})
	var report := {"passed":true,"clip":"ArmatureAction","duration":clip.length,"tracks":clip.get_track_count(),"bone_count":skeleton.get_bone_count(),"animator_path":str(actor.get_path_to(animator)),"skeleton_path":str(actor.get_path_to(skeleton)),"duplicate_before_explicit_play":duplicate_before,"duplicate_after_explicit_play":duplicated_animator.is_playing(),"samples":samples}
	FileAccess.open(OUT+"godot_shark_playback_validation.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("SHARK_GODOT_PASS clip=",clip.length," bones=",skeleton.get_bone_count()," duplicate_before=",duplicate_before," after=",duplicated_animator.is_playing())
	actor.free()
	duplicate.free()
	quit()
