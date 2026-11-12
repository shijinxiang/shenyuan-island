extends SceneTree

const FOLDER := "D:/浪费GPT额度/小温的游戏/素材/06_游戏场景资产/农耕与伐木/动作/"

func _initialize() -> void:
	call_deferred("_verify")

func _verify() -> void:
	var reports: Array = []
	for slug in ["harvest", "watering"]:
		var metadata: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FOLDER + slug + "_metadata.json"))
		var clip: Animation = load("res://assets/characters/C01_" + slug + ".res")
		assert(clip != null and clip.resource_name == metadata.clip)
		assert(clip.loop_mode == Animation.LOOP_NONE)
		assert(absf(clip.length - float(metadata.duration_seconds)) < 0.0001)
		var character: Node3D = load("res://assets/characters/C01_locomotion.glb").instantiate()
		get_root().add_child(character)
		var player: AnimationPlayer = character.find_children("*", "AnimationPlayer", true, false)[0]
		var skeleton: Skeleton3D = character.find_children("*", "Skeleton3D", true, false)[0]
		var library := AnimationLibrary.new()
		library.add_animation(metadata.clip, clip)
		player.add_animation_library("farm_validation", library)
		for i in clip.get_track_count():
			var path := clip.track_get_path(i)
			assert(String(path).begins_with("GeneralSkeleton/Skeleton3D:"))
			assert(skeleton.find_bone(path.get_subname(0)) >= 0)
			assert(clip.track_get_key_count(i) > 0)
		player.play("farm_validation/" + String(metadata.clip))
		var min_hips := 1000.0
		var max_hips := -1000.0
		var left_hand_first := Quaternion.IDENTITY
		var max_left_hand_angle := 0.0
		var sample_count := int(round(clip.length * float(metadata.fps))) + 1
		for i in sample_count:
			player.seek(float(i) / float(metadata.fps), true)
			player.advance(0)
			skeleton.force_update_all_bone_transforms()
			for b in skeleton.get_bone_count():
				assert(skeleton.get_bone_global_pose(b).origin.is_finite())
			var hips := skeleton.get_bone_global_pose(skeleton.find_bone("Hips")).origin.y
			min_hips = minf(hips, min_hips)
			max_hips = maxf(hips, max_hips)
			var left_hand := skeleton.get_bone_global_pose(skeleton.find_bone("LeftHand")).basis.get_rotation_quaternion().normalized()
			if i == 0:
				left_hand_first = left_hand
			max_left_hand_angle = maxf(max_left_hand_angle, left_hand.angle_to(left_hand_first))
		if slug == "harvest":
			assert(max_left_hand_angle < 0.45, "Relaxed arm should remain down, with at most 25-degree knee clearance")
		var report := {"clip": clip.resource_name, "duration": clip.length, "tracks": clip.get_track_count(), "bones": skeleton.get_bone_count(), "sampled_frames": sample_count, "loop": clip.loop_mode, "hips_height_range": [min_hips, max_hips], "track_example": String(clip.track_get_path(0)), "max_left_hand_angle_radians": max_left_hand_angle}
		print("FARM_VERIFIED ", JSON.stringify(report))
		reports.append(report)
		character.free()
	var file := FileAccess.open(FOLDER + "godot_farming_validation.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(reports, "\t"))
	quit()
