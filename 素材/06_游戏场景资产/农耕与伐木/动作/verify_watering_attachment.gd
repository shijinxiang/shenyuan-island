extends SceneTree
const FOLDER := "D:/浪费GPT额度/小温的游戏/素材/06_游戏场景资产/农耕与伐木/动作/"
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var character = load("res://assets/characters/C01_locomotion.glb").instantiate()
	root.add_child(character)
	var can = load("res://assets/farming/watering_can.glb").instantiate()
	root.add_child(can)
	var player = character.find_children("*", "AnimationPlayer", true, false)[0]
	var skeleton = character.find_children("*", "Skeleton3D", true, false)[0]
	var clip: Animation = load("res://assets/characters/C01_watering.res")
	var lib = AnimationLibrary.new()
	lib.add_animation("Watering", clip)
	player.add_animation_library("grip_verify", lib)
	player.play("grip_verify/Watering")
	var calibration := Basis(Vector3(1,0,0), Vector3(0,-1,0), Vector3(0,0,-1))
	var local_center := Vector3(0,.09,-.048)
	var can_grip := Vector3(0,.55,0)
	var max_anchor_error := 0.0
	var max_grip_delta := 0.0
	var first_fingers: Dictionary = {}
	var min_mouth_forward := 1.0
	var max_mouth_up := -1.0
	for frame in 169:
		player.seek(float(frame)/30.0, true)
		player.advance(0)
		skeleton.force_update_all_bone_transforms()
		var hand: Transform3D = skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone("RightHand"))
		var basis := hand.basis.orthonormalized() * calibration
		var center := hand * local_center
		can.global_transform = Transform3D(basis, center - basis * can_grip)
		if frame >= 30 and frame <= 138:
			var mouth_direction := basis * Vector3(-1,1,0).normalized()
			min_mouth_forward = minf(min_mouth_forward, mouth_direction.z)
			max_mouth_up = maxf(max_mouth_up, mouth_direction.y)
		max_anchor_error = maxf(max_anchor_error, (can.global_transform * can_grip).distance_to(center))
		for b in skeleton.get_bone_count():
			var name: String = skeleton.get_bone_name(b)
			if name.begins_with("RightHand") and name != "RightHand":
				var rotation: Quaternion = skeleton.get_bone_pose_rotation(b)
				if frame == 0:
					first_fingers[name] = rotation
				max_grip_delta = maxf(max_grip_delta, rotation.angle_to(first_fingers[name]))
	assert(first_fingers.size() == 15)
	assert(max_anchor_error < .00001)
	assert(max_grip_delta < .001)
	assert(min_mouth_forward > .69 and max_mouth_up < -.17)
	assert(clip.get_track_count() == 53 and clip.loop_mode == Animation.LOOP_NONE and absf(clip.length-5.6)<.00001)
	var report := {"frames":169,"duration":clip.length,"tracks":clip.get_track_count(),"finger_bones":first_fingers.size(),"max_anchor_error_m":max_anchor_error,"max_finger_rotation_delta_radians":max_grip_delta,"can":"res://assets/farming/watering_can.glb","hand":"RightHand","hand_local_center":[0,.09,-.048],"can_grip":[0,.55,0],"watering_window":[1.0,4.6],"min_nozzle_forward_dot":min_mouth_forward,"max_nozzle_up_dot":max_mouth_up}
	var file := FileAccess.open(FOLDER+"godot_watering_grip_validation.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	print("WATERING_ATTACHMENT_VERIFIED ", JSON.stringify(report))
	can.free();character.free()
	quit()
