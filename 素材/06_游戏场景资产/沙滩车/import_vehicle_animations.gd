extends SceneTree
const PROJECT := "D:/浪费GPT额度/小温的游戏"
const SOURCE := PROJECT + "/素材/06_游戏场景资产/沙滩车/"
var results: Dictionary = {}
func _initialize() -> void:
	_run.call_deferred()
func _scene_from_glb(path: String) -> Node3D:
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	assert(doc.append_from_file(path, state) == OK)
	return doc.generate_scene(state)
func _run() -> void:
	var existing := _scene_from_glb(PROJECT + "/游戏/assets/characters/C01_locomotion.glb")
	root.add_child(existing)
	var player: AnimationPlayer = existing.find_children("*", "AnimationPlayer", true, false)[0]
	var skeleton: Skeleton3D = existing.find_children("*", "Skeleton3D", true, false)[0]
	var skeleton_path := player.get_node(player.root_node).get_path_to(skeleton)
	for specification in [["Entering Car", "entering_car", false], ["Driving", "driving", true]]:
		var source := _scene_from_glb(SOURCE + specification[1] + ".glb")
		var source_player: AnimationPlayer = source.find_children("*", "AnimationPlayer", true, false)[0]
		var clip: Animation = source_player.get_animation(source_player.get_animation_list()[0]).duplicate()
		for index in range(clip.get_track_count()):
			var path := clip.track_get_path(index)
			assert(path.get_subname_count() == 1)
			var bone := path.get_subname(0)
			assert(skeleton.find_bone(bone) >= 0)
			clip.track_set_path(index, NodePath(String(skeleton_path) + ":" + bone))
		clip.resource_name = specification[0]
		clip.loop_mode = Animation.LOOP_LINEAR if specification[2] else Animation.LOOP_NONE
		var output: String = PROJECT + "/游戏/assets/characters/C01_" + specification[1] + ".res"
		assert(ResourceSaver.save(clip, output) == OK)
		var lib := AnimationLibrary.new()
		lib.add_animation(specification[0], clip)
		player.add_animation_library(specification[1], lib)
		var hips := skeleton.find_bone("Hips")
		var root_bone := skeleton.find_bone("Root")
		var samples: Array = []
		player.play(specification[1] + "/" + specification[0])
		for time in [0.0, clip.length * 0.5, clip.length - 0.001]:
			player.seek(time, true)
			player.advance(0)
			skeleton.force_update_all_bone_transforms()
			var h := skeleton.get_bone_global_pose(hips).origin
			var r := skeleton.get_bone_pose_position(root_bone)
			assert(absf(h.x) < 0.0001 and absf(h.z) < 0.0001, "Horizontal hips drift")
			assert(r.length() < 0.0001, "Root drift")
			samples.append({"time": time, "hips": [h.x,h.y,h.z], "root": [r.x,r.y,r.z]})
		results[specification[0]] = {"resource": output, "duration": clip.length, "tracks": clip.get_track_count(), "loop": specification[2], "skeleton_path": str(skeleton_path), "samples": samples}
		source.free()
	var f := FileAccess.open(SOURCE + "godot_animation_validation.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(results,"  "))
	print("VEHICLE_ANIMATIONS_SAVED ", JSON.stringify(results))
	existing.free()
	quit()
