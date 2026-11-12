extends SceneTree
class Hunt extends Node3D:
	var game: Dictionary
	var processing_corpse := true
	var processing_progress := .3
	var processing_target := Vector3(-.15,.9,.55)
	var knife_model: Node3D
func _initialize() -> void:
	ProjectSettings.set_setting("application/config/use_custom_user_dir", true)
	ProjectSettings.set_setting("application/config/custom_user_dir_name", "AbyssIsland_Test_SkinningKnife")
	DirAccess.make_dir_recursive_absolute(OS.get_user_data_dir() + "/shader_cache")
	root.hide()
	call_deferred("run")
func run() -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(900,900)
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
	world.environment.ambient_light_energy = .7
	scene.add_child(world)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40,-30,0)
	light.light_energy = 1.3
	scene.add_child(light)
	var model: Node3D = load("res://assets/characters/C01_locomotion.glb").instantiate()
	scene.add_child(model)
	var sk: Skeleton3D = model.find_children("*", "Skeleton3D", true, false)[0]
	var clip: Animation = load("res://assets/characters/C01_harvest.res")
	for t in clip.get_track_count():
		var b := sk.find_bone(String(clip.track_get_path(t).get_subname(0)))
		if b >= 0 and clip.track_get_type(t) == Animation.TYPE_ROTATION_3D:
			sk.set_bone_pose_rotation(b,clip.rotation_track_interpolate(t, .5))
	var hunt := Hunt.new()
	hunt.game = {"player":{"visual":model,"swimming":false}}
	scene.add_child(hunt)
	hunt.knife_model = load("res://assets/hunting/skinning_knife.glb").instantiate()
	scene.add_child(hunt.knife_model)
	var mod = load("res://scripts/player/skinning_grip.gd").new()
	mod.hunting = hunt
	sk.add_child(mod)
	sk.skeleton_updated.connect(func():
		var pose := sk.global_transform * sk.get_bone_global_pose(sk.find_bone("RightHand"))
		var err: float = (pose * mod.PALM_ANCHOR).distance_to(hunt.knife_model.global_position)
		if err > .00001: push_error("GRIP ERROR: " + str(err))
	)
	var cam := Camera3D.new()
	scene.add_child(cam)
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 1.2
	var center := Vector3(0,.95,.23)
	for angle in ["front", "side", "back"]:
		cam.position = center + ({"front":Vector3(-1.4,.3,2), "side":Vector3(-2,.3,.3), "back":Vector3(-1.4,.3,-2)}[angle] as Vector3)
		cam.look_at(center)
		for i in 6: await process_frame
		await RenderingServer.frame_post_draw
		vp.get_texture().get_image().save_png("D:/浪费GPT额度/小温的游戏/素材/06_游戏场景资产/狩猎与烹饪/剥皮小刀/validation_"+angle+".png")
	var hand := sk.global_transform * sk.get_bone_global_pose(sk.find_bone("RightHand"))
	print("GRIP_CHECK=checked inside skeleton_updated after model sync; poses reset outside signal")
	print("KNIFE_VALIDATION_DONE")
	quit()



