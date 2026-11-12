extends SceneTree

const FOLDER := "D:/浪费GPT额度/小温的游戏/素材/06_游戏场景资产/农耕与伐木/动作/"

func _initialize() -> void:
	var existing: Node3D = load("res://assets/characters/C01_locomotion.glb").instantiate()
	var existing_player: AnimationPlayer = existing.find_children("*", "AnimationPlayer", true, false)[0]
	var skeleton: Skeleton3D = existing.find_children("*", "Skeleton3D", true, false)[0]
	var skeleton_path := existing_player.get_node(existing_player.root_node).get_path_to(skeleton)
	var slugs = OS.get_cmdline_user_args()
	if slugs.is_empty():
		slugs = ["harvest", "watering"]
	for slug in slugs:
		var metadata: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FOLDER + slug + "_metadata.json"))
		var document := GLTFDocument.new()
		var state := GLTFState.new()
		assert(document.append_from_file(FOLDER + "C01_" + slug + "_source.glb", state) == OK)
		var source := document.generate_scene(state)
		var source_player: AnimationPlayer = source.find_children("*", "AnimationPlayer", true, false)[0]
		var clip: Animation = source_player.get_animation(source_player.get_animation_list()[0]).duplicate()
		for index in clip.get_track_count():
			var path := clip.track_get_path(index)
			assert(path.get_subname_count() == 1)
			var bone := path.get_subname(0)
			assert(skeleton.find_bone(bone) >= 0)
			clip.track_set_path(index, NodePath(String(skeleton_path) + ":" + bone))
			var keys: Array = []
			for key_index in clip.track_get_key_count(index):
				var key_time := clip.track_get_key_time(index, key_index)
				if key_time >= 1.0 / float(metadata.fps) - 0.00001:
					keys.append([maxf(0.0, key_time - 1.0 / float(metadata.fps)), clip.track_get_key_value(index, key_index), clip.track_get_key_transition(index, key_index)])
			for key_index in range(clip.track_get_key_count(index) - 1, -1, -1):
				clip.track_remove_key(index, key_index)
			for key in keys:
				clip.track_insert_key(index, key[0], key[1], key[2])
		clip.resource_name = metadata.clip
		clip.length = metadata.duration_seconds
		clip.loop_mode = Animation.LOOP_NONE
		assert(ResourceSaver.save(clip, "res://assets/characters/C01_" + slug + ".res") == OK)
		print("FARM_SAVED ", clip.resource_name, " tracks=", clip.get_track_count(), " length=", clip.length, " skeleton=", skeleton_path)
		source.free()
	existing.free()
	quit()
