extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var character = load("res://assets/characters/C01_locomotion.glb").instantiate()
	root.add_child(character)
	var player = character.find_children("*", "AnimationPlayer", true, false)[0]
	var skel = character.find_children("*", "Skeleton3D", true, false)[0]
	var lib = AnimationLibrary.new()
	lib.add_animation("Watering", load("res://assets/characters/C01_watering.res"))
	player.add_animation_library("probe", lib)
	player.play("probe/Watering")
	for t in [0.0, 67.0/30.0, 5.6]:
		player.seek(t, true); player.advance(0);skel.force_update_all_bone_transforms()
		var pose = skel.get_bone_global_pose(skel.find_bone("RightHand"))
		var mid = skel.get_bone_global_pose(skel.find_bone("RightHandMiddle1"))
		print("HAND_BASIS ",t," ",pose," MIDDLE_LOCAL ",pose.affine_inverse()*mid.origin)
	character.free()
	quit()
