extends SceneTree

func _initialize() -> void:
	call_deferred("_verify")

func _verify() -> void:
	var clip: Animation = load("res://assets/characters/C01_chop.res")
	assert(clip != null and clip.resource_name == "Chop")
	assert(clip.loop_mode == Animation.LOOP_NONE)
	assert(absf(clip.length - 35.0 / 30.0) < 0.0001)
	var character: Node3D = load("res://assets/characters/C01_locomotion.glb").instantiate()
	get_root().add_child(character)
	var player: AnimationPlayer = character.find_children("*", "AnimationPlayer", true, false)[0]
	var skeleton: Skeleton3D = character.find_children("*", "Skeleton3D", true, false)[0]
	var library := AnimationLibrary.new()
	library.add_animation("Chop", clip)
	player.add_animation_library("chop_validation", library)
	for i in clip.get_track_count():
		var path := clip.track_get_path(i)
		assert(String(path).begins_with("GeneralSkeleton/Skeleton3D:"))
		assert(skeleton.find_bone(path.get_subname(0)) >= 0)
	player.play("chop_validation/Chop")
	var hips_index := skeleton.find_bone("Hips")
	var min_hips := 1000.0
	var max_hips := -1000.0
	for i in 36:
		player.seek(float(i) / 30.0, true)
		player.advance(0)
		skeleton.force_update_all_bone_transforms()
		for b in skeleton.get_bone_count():
			assert(skeleton.get_bone_global_pose(b).origin.is_finite())
		var hips := skeleton.get_bone_global_pose(hips_index).origin.y
		min_hips = minf(hips, min_hips)
		max_hips = maxf(hips, max_hips)
	print("CHOP_VERIFIED ", JSON.stringify({"name": clip.resource_name, "duration": clip.length, "tracks": clip.get_track_count(), "bones": skeleton.get_bone_count(), "loop": clip.loop_mode, "hips_height_range": [min_hips, max_hips], "track_example": String(clip.track_get_path(0))}))
	character.queue_free()
	quit()
