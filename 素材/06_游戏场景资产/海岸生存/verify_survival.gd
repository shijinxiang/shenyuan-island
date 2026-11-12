extends SceneTree
var report: Dictionary = {}
var failures: Array[String] = []
func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	for asset in ["bed", "chest", "cabin_lamp", "saltwater_crocodile", "food_bundle", "medical_kit"]:
		var packed := load("res://assets/survival/%s.glb" % asset) as PackedScene
		if packed == null:
			failures.append(asset + " failed to load")
			continue
		var instance := packed.instantiate()
		root.add_child(instance)
		var meshes := instance.find_children("*", "MeshInstance3D", true, false)
		var nodes: Array[String] = []
		var box := AABB()
		var first := true
		for mesh: MeshInstance3D in meshes:
			var mb: AABB = mesh.global_transform * mesh.get_aabb()
			box = mb if first else box.merge(mb)
			first = false
			nodes.append(str(instance.get_path_to(mesh)))
			for surface in range(mesh.mesh.get_surface_count()):
				var arrays := mesh.mesh.surface_get_arrays(surface)
				if arrays[Mesh.ARRAY_TEX_UV] == null or mesh.mesh.surface_get_material(surface) == null:
					failures.append(asset + " missing UV/material")
		report[asset] = {"mesh_paths": nodes, "aabb_min": [box.position.x,box.position.y,box.position.z], "aabb_size": [box.size.x,box.size.y,box.size.z]}
		if asset == "chest":
			var lid := instance.find_child("LidPivot", true, false) as Node3D
			if lid == null:
				failures.append("chest hinge absent")
			else:
				report[asset]["lid_path"] = str(instance.get_path_to(lid))
				report[asset]["closed_transform"] = str(lid.transform)
				lid.rotation.x = -1.3
				report[asset]["opened_transform"] = str(lid.transform)
		if asset == "saltwater_crocodile":
			var skeleton := instance.find_child("Skeleton3D", true, false) as Skeleton3D
			var animator := instance.find_child("AnimationPlayer", true, false) as AnimationPlayer
			if skeleton == null or animator == null:
				failures.append("crocodile missing rig or animation player")
			else:
				report[asset]["skeleton_path"] = str(instance.get_path_to(skeleton))
				report[asset]["animator_path"] = str(instance.get_path_to(animator))
				report[asset]["bone_count"] = skeleton.get_bone_count()
				var animations := {}
				for animation_name in ["Idle", "Crawl", "Swim", "Attack", "Eat", "Death"]:
					if not animator.has_animation(animation_name):
						failures.append("missing animation " + animation_name)
						continue
					var animation := animator.get_animation(animation_name)
					animations[animation_name] = {"length": animation.length, "tracks": animation.get_track_count()}
					animator.play(animation_name)
					animator.seek(animation.length * 0.25, true)
					animator.advance(0)
					var root_idx := skeleton.find_bone("Root")
					if root_idx < 0 or skeleton.get_bone_pose_position(root_idx).length() > 0.001:
						failures.append(animation_name + " root drift")
					var jaw_idx := skeleton.find_bone("Jaw")
					if animation_name == "Attack":
						animations[animation_name]["jaw_rotation_at_quarter"] = str(skeleton.get_bone_pose_rotation(jaw_idx))
						if skeleton.get_bone_pose_rotation(jaw_idx).is_equal_approx(Quaternion.IDENTITY): failures.append("Attack jaw has no motion")
				report[asset]["animations"] = animations
		instance.free()
	report["failures"] = failures
	report["passed"] = failures.is_empty()
	var f := FileAccess.open("res://../../海岸生存/godot_validation.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(report, "  "))
	print("SURVIVAL_VALIDATION ", "PASS" if failures.is_empty() else "FAIL", " ", failures)
	quit(0 if failures.is_empty() else 1)
