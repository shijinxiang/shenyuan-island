extends SceneTree

func _initialize() -> void:
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var error := document.append_from_file("D:/浪费GPT额度/小温的游戏/素材/06_游戏场景资产/农耕与伐木/动作/C01_chop_source.glb", state)
	assert(error == OK, "Cannot import chop animation")
	var source := document.generate_scene(state)
	var source_player: AnimationPlayer = source.find_children("*", "AnimationPlayer", true, false)[0]
	print("NEW_CLIPS ", source_player.get_animation_list())
	var clip: Animation = source_player.get_animation(source_player.get_animation_list()[0]).duplicate()
	var existing: Node3D = load("res://assets/characters/C01_locomotion.glb").instantiate()
	var existing_player: AnimationPlayer = existing.find_children("*", "AnimationPlayer", true, false)[0]
	var skeleton: Skeleton3D = existing.find_children("*", "Skeleton3D", true, false)[0]
	var skeleton_path := existing_player.get_node(existing_player.root_node).get_path_to(skeleton)
	for index in clip.get_track_count():
		var path := clip.track_get_path(index)
		assert(path.get_subname_count() == 1, "Unexpected animation track")
		var bone := path.get_subname(0)
		assert(skeleton.find_bone(bone) >= 0, "Missing animation bone " + bone)
		clip.track_set_path(index, NodePath(String(skeleton_path) + ":" + bone))
		# glTF stores Blender frame 1 at 1/30 second. Align its first key
		# with gameplay t=0 instead of keeping a padded opening frame.
		var keys: Array = []
		for key_index in clip.track_get_key_count(index):
			var key_time := clip.track_get_key_time(index, key_index)
			if key_time >= 1.0 / 30.0 - 0.00001:
				keys.append([maxf(0.0, key_time - 1.0 / 30.0), clip.track_get_key_value(index, key_index), clip.track_get_key_transition(index, key_index)])
		for key_index in range(clip.track_get_key_count(index) - 1, -1, -1):
			clip.track_remove_key(index, key_index)
		for key in keys:
			clip.track_insert_key(index, key[0], key[1], key[2])
	clip.length = 35.0 / 30.0
	clip.resource_name = "Chop"
	clip.loop_mode = Animation.LOOP_NONE
	error = ResourceSaver.save(clip, "res://assets/characters/C01_chop.res")
	assert(error == OK, "Cannot save chop animation")
	print("CHOP_SAVED tracks=", clip.get_track_count(), " length=", clip.length, " skeleton=", skeleton_path)
	source.free()
	existing.free()
	quit()
