extends "capture_release_evidence.gd"

func tick(frames := 3) -> void:
	for frame in frames:
		await physics_frame
		await process_frame
	RenderingServer.force_draw()

func run() -> void:
	root.mode=Window.MODE_WINDOWED
	root.show()
	world=load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	root.add_child(world)
	current_scene=world
	game=world.get_node("IslandAdventure")
	player=game.player
	h=game.hunting
	while not world.get_node("ShallowWaterSimulation").ready_for_render:await tick(1)
	await tick(15)
	game.set_process(false)
	game.wildlife.set_process(false)
	game.crocodiles.set_physics_process(false)
	game.weather.set_process(false)
	player.set_physics_process(false)
	camera=Camera3D.new()
	world.add_child(camera)
	game.ui.open_character("skills")
	await tick(50)
	await shot("N05_character_skills","最新发布包人物页中的六项技艺与效果")
	game.ui.bag.hide()
	player.global_position=game.letter_table.global_position+Vector3(.6,0,.4)
	game.read_letter()
	await tick(50)
	await shot("N30_open_letter","阅读时在画面中央展开完整信件")
	var index_path:=OUTPUT+"最新实机截图索引.json"
	var previous:Array=JSON.parse_string(FileAccess.get_file_as_string(index_path))
	for record:Dictionary in records:
		previous=previous.filter(func(old):return old.id!=record.id)
		previous.append(record)
	var file:=FileAccess.open(index_path,FileAccess.WRITE)
	file.store_string(JSON.stringify(previous,"  "))
	file.close()
	print("PANEL_RECAPTURE_COMPLETE")
	current_scene=null
	world.queue_free()
	await tick(5)
	quit()
