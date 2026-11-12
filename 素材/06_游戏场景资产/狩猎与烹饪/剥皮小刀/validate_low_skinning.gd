extends SceneTree
const OUT := "D:/浪费GPT额度/小温的游戏/素材/06_游戏场景资产/狩猎与烹饪/剥皮小刀/"
class Hunt extends Node3D:
	var game: Dictionary
	var processing_corpse := true
	var processing_progress := .5
	var processing_target := Vector3(-.15,.15,.55)
	var knife_model: Node3D
func _initialize() -> void:
	ProjectSettings.set_setting("application/config/use_custom_user_dir", true)
	ProjectSettings.set_setting("application/config/custom_user_dir_name", "AbyssIsland_Test_SkinningKnife")
	root.hide()
	call_deferred("run")
func run() -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(1000,1000)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var scene := Node3D.new()
	vp.add_child(scene)
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color(.19,.23,.25)
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color.WHITE
	world.environment.ambient_light_energy = .5
	scene.add_child(world)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40,-30,0)
	light.light_energy = .9
	scene.add_child(light)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(4,4)
	floor_mesh.mesh = plane
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(.26,.31,.24)
	floor_mesh.material_override = floor_mat
	scene.add_child(floor_mesh)
	var cam := Camera3D.new()
	scene.add_child(cam)
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	var results: Array = []
	for height in [.15,.45]:
		var model: Node3D = load("res://assets/characters/C01_locomotion.glb").instantiate()
		scene.add_child(model)
		var sk: Skeleton3D = model.find_children("*", "Skeleton3D", true, false)[0]
		var clip: Animation = load("res://assets/characters/C01_harvest.res")
		for t in clip.get_track_count():
			var b := sk.find_bone(String(clip.track_get_path(t).get_subname(0)))
			if b >= 0 and clip.track_get_type(t) == Animation.TYPE_ROTATION_3D:
				sk.set_bone_pose_rotation(b,clip.rotation_track_interpolate(t, .5))
		var feet := {}
		var lengths := {}
		var pairs := [["LeftUpLeg","LeftLeg"],["LeftLeg","LeftFoot"],["RightUpLeg","RightLeg"],["RightLeg","RightFoot"],["RightArm","RightForeArm"],["RightForeArm","RightHand"],["LeftArm","LeftForeArm"],["LeftForeArm","LeftHand"]]
		for side in ["Left","Right"]:
			feet[side] = sk.get_bone_global_pose(sk.find_bone(side+"Foot")).origin
		for pair in pairs:
			lengths[pair[0]] = sk.get_bone_global_pose(sk.find_bone(pair[0])).origin.distance_to(sk.get_bone_global_pose(sk.find_bone(pair[1])).origin)
		var hunt := Hunt.new()
		hunt.processing_target.y = height
		hunt.game = {"player":{"visual":model,"swimming":false}}
		scene.add_child(hunt)
		hunt.knife_model = load("res://assets/hunting/skinning_knife.glb").instantiate()
		scene.add_child(hunt.knife_model)
		var corpse: Node3D = load("res://assets/fauna/marine/BrownFish.glb").instantiate()
		scene.add_child(corpse)
		corpse.rotation.z = PI/2
		var box := AABB()
		var first := true
		for mesh: MeshInstance3D in corpse.find_children("*","MeshInstance3D",true,false):
			var bounds := mesh.global_transform * mesh.get_aabb()
			box = bounds if first else box.merge(bounds)
			first = false
		var ray_origin := Vector3(box.get_center().x,box.end.y+1.0,box.get_center().z)
		var top := box.position.y
		for mesh: MeshInstance3D in corpse.find_children("*","MeshInstance3D",true,false):
			var faces := mesh.mesh.get_faces()
			for k in range(0,faces.size(),3):
				var hit = Geometry3D.ray_intersects_triangle(ray_origin,Vector3.DOWN,mesh.global_transform*faces[k],mesh.global_transform*faces[k+1],mesh.global_transform*faces[k+2])
				if hit != null: top = maxf(top,hit.y)
		var factor: float = .15/(top-box.position.y)
		corpse.scale *= factor
		corpse.position = hunt.processing_target - Vector3(box.get_center().x,top,box.get_center().z)*factor
		var support_fixture := MeshInstance3D.new()
		if height > .3:
			var fixture_box := BoxMesh.new()
			fixture_box.size = Vector3(.85,.3,.5)
			support_fixture.mesh = fixture_box
			support_fixture.position = Vector3(hunt.processing_target.x,.15,hunt.processing_target.z)
			var fixture_mat := StandardMaterial3D.new()
			fixture_mat.albedo_color = Color(.24,.14,.07)
			support_fixture.material_override = fixture_mat
			scene.add_child(support_fixture)
		var mod = load("res://scripts/player/skinning_grip.gd").new()
		mod.hunting = hunt
		sk.add_child(mod)
		var metrics := {"height":height}
		sk.skeleton_updated.connect(func():
			var pose := sk.global_transform * sk.get_bone_global_pose(sk.find_bone("RightHand"))
			metrics["grip_error_m"] = (pose * mod.PALM_ANCHOR).distance_to(hunt.knife_model.global_position)
			metrics["blade_surface_error_m"] = (hunt.knife_model.global_transform * mod.BLADE_CONTACT).distance_to(hunt.processing_target)
			for side in ["Left","Right"]:
				metrics[side+"_foot_error_m"] = feet[side].distance_to(sk.get_bone_global_pose(sk.find_bone(side+"Foot")).origin)
			for pair in pairs:
				var length := sk.get_bone_global_pose(sk.find_bone(pair[0])).origin.distance_to(sk.get_bone_global_pose(sk.find_bone(pair[1])).origin)
				metrics[pair[0]+"_length_error_m"] = absf(length-lengths[pair[0]])
		)
		for angle in ["side","front","close"]:
			var center := Vector3(0,.6,.3)
			cam.size = 1.65
			cam.position = center + Vector3(-2,.2,.2)
			if angle == "front": cam.position = center + Vector3(-1.4,.1,2)
			if angle == "close":
				center = hunt.processing_target + Vector3(0,.1,-.04)
				cam.size = .7
				cam.position = center + Vector3(-2,.3,1)
			cam.look_at(center)
			for i in 6: await process_frame
			await RenderingServer.frame_post_draw
			vp.get_texture().get_image().save_png(OUT+"low_"+str(height)+"_"+angle+".png")
		results.append(metrics.duplicate())
		model.queue_free()
		hunt.knife_model.queue_free()
		hunt.queue_free()
		corpse.queue_free()
		support_fixture.queue_free()
		await process_frame
	var file := FileAccess.open(OUT+"low_pose_metrics.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(results,"  "))
	print(JSON.stringify(results))
	print("KNIFE_LOW_VALIDATION_DONE")
	quit()
