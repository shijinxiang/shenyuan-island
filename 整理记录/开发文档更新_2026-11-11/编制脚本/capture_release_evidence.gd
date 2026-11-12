extends SceneTree

const OUTPUT := "D:/浪费GPT额度/小温的游戏/整理记录/开发文档更新_2026-11-11/实机证据/"
var world: Node3D
var game: Node3D
var player: CharacterBody3D
var camera: Camera3D
var records: Array = []
var h: Node3D

func _initialize() -> void:
	ProjectSettings.set_setting("application/config/use_custom_user_dir",true)
	ProjectSettings.set_setting("application/config/custom_user_dir_name","CodexAbyssDocumentEvidence20261111")
	DirAccess.make_dir_recursive_absolute(OS.get_user_data_dir())
	var goods: Array = []
	var names := {"axe":"斧头","axe_steel":"钢制斧头","hoe":"锄头","hoe_steel":"钢制锄头","watering_can":"浇水壶","watering_can_large":"大号浇水壶","harpoon":"三齿鱼叉","harpoon_steel":"钢制鱼叉","bow":"木弓","hunting_rifle":"单发猎枪","rifle_ammo":"猎枪弹","wooden_arrow":"木箭","wood":"木材","crop_turnip":"萝卜","crop_tomato":"番茄","seed_turnip":"萝卜种子","wild_berry":"野果","wild_mushroom":"可食蘑菇"}
	for id in ["axe","axe_steel","hoe","hoe_steel","watering_can","watering_can_large","harpoon","harpoon_steel","bow","hunting_rifle","rifle_ammo","wooden_arrow","wood","crop_turnip","crop_tomato","seed_turnip","wild_berry","wild_mushroom"]:
		goods.append({"id":id,"name":names[id],"count":40 if id in ["wood","crop_turnip","crop_tomato","wooden_arrow","rifle_ammo"] else 3 if id in ["wild_berry","wild_mushroom","seed_turnip"] else 1})
	var file := FileAccess.open("user://fishing_catches.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"version":3,"items":[],"progress":{"intro_seen":true,"rod_found":true,"merchant_intro":true,"goods":goods}}))
	file.close()
	call_deferred("run")

func tick(frames := 3) -> void:
	for step in frames:
		await physics_frame
		await process_frame
	await RenderingServer.frame_post_draw

func shot(name: String, label: String, keep_notice := false) -> void:
	if not keep_notice:game.ui.toast_time=0
	await tick(2)
	var path := OUTPUT + name + ".png"
	if root.get_texture().get_image().save_png(path) != OK:
		push_error("Screenshot failed " + path)
		quit(2)
	var entry := {"id":name,"path":path,"caption":label,"game_version":ProjectSettings.get_setting("application/config/version"),"main_scene":world.scene_file_path,"day":game.day_count,"hour":game.weather.hour,"source":"Windows release PCK runtime with isolated fixture save"}
	records.append(entry)
	print("EVIDENCE ",name," ",label)

func view(point: Vector3, offset: Vector3, size := 4.0, perspective := false) -> void:
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE if perspective else Camera3D.PROJECTION_ORTHOGONAL
	camera.size = size
	camera.fov = 55
	camera.global_position = point + offset
	camera.look_at(point)
	camera.make_current()
	await tick(5)

func land(point: Vector3) -> void:
	player._set_swimming(false)
	player.global_position = point
	player.global_position.y = game.wildlife.ground.height(point.x,point.z)+.015
	player.interaction_time = 0
	player.velocity = Vector3.ZERO
	player._play_motion("Idle",1.0)
	game.ui.close_dialog()
	game.ui.bag.hide()
	await tick(3)

func run() -> void:
	world=load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	root.add_child(world)
	current_scene=world
	game=world.get_node("IslandAdventure")
	player=game.player
	h=game.hunting
	while not world.get_node("ShallowWaterSimulation").ready_for_render:
		await tick(1)
	await tick(20)
	game.set_process(false)
	game.wildlife.set_process(false)
	game.crocodiles.set_physics_process(false)
	game.weather.set_process(false)
	game.vehicle.set_physics_process(false)
	player.set_physics_process(false)
	game.hit_cooldown=999
	game.merchant_available=true
	game.weather.hour=11
	game.weather._update_environment(0)
	camera=Camera3D.new()
	world.add_child(camera)
	camera.near=.05
	camera.far=1800
	for i in 5:game.hotbar.assign(i,["bow","fishing_rod","harpoon","hoe","axe"][i])
	var home:Vector3=game.survival.cabin_center
	await land(home+Vector3(9,0,4))
	game.use_item("axe")
	await view(player.global_position+Vector3.UP,Vector3(4,2.5,5),6.2)
	await shot("N01_latest_island","0.2.0版本小屋与五格工具栏")
	var key:=InputEventKey.new()
	key.keycode=KEY_5
	key.physical_keycode=KEY_5
	key.pressed=true
	Input.parse_input_event(key)
	Input.flush_buffered_events()
	key=key.duplicate()
	key.pressed=false
	Input.parse_input_event(key)
	Input.flush_buffered_events()
	await tick(8)
	await shot("N35_repeat_key_stows","再次按数字5后斧头收起并清除格位高亮")
	game.use_item("axe")
	var axe:Node3D=game.farming.held_tools.axe
	await view(axe.global_transform*Vector3(game.farming.grips.axe),Vector3(-1,.15,.8),.85)
	await shot("N31_inward_palm","实机场景中的斧柄握点与向内掌心近景")
	game.use_item("axe")
	game.economy.open_shop("狩猎装备")
	await shot("N02_hunting_shop","商人狩猎装备分类含剥皮小刀与弓箭弹药")
	var knife:Dictionary={}
	for product:Dictionary in game.economy.CATALOG:
		if product.id=="skinning_knife":knife=product
	game.economy.show_product(knife)
	await shot("N03_knife_cost","剥皮小刀的鱼获或农产品兑换条件")
	game.economy.trade(knife,1)
	game.ui.close_dialog()
	h.quest.offer()
	await shot("N04_rifle_quest","单发猎枪第一阶段商人委托")
	game.ui.close_dialog()
	game.ui.open_character("skills")
	await shot("N05_character_skills","人物状态页集中查看六项技艺与饱食度")
	game.ui.bag.hide()
	await cabin_evidence()
	await crocodile_evidence()
	await hunting_evidence()
	await sea_evidence()
	await kitchen_evidence(home)
	game.ui.close_dialog()
	game.ui.bag.hide()
	player.planar_speed=0
	player._set_swimming(false)
	player._play_motion("Idle",1.0)
	await tick(120)
	var file:=FileAccess.open(OUTPUT+"最新实机截图索引.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(records,"  "))
	file.close()
	print("DOCUMENT_EVIDENCE_COMPLETE ",records.size())
	current_scene=null
	world.queue_free()
	await tick(5)
	quit()

func cabin_evidence() -> void:
	var survival:Node3D=game.survival
	player.global_position=survival.cabin.to_global(Vector3(-1.4,.68,-.6))
	player._play_motion("Idle",1)
	await tick(15)
	for child:Node in survival.cabin.find_children("*Roof*","Node3D",true,false):child.hide()
	game.weather.hour=22
	game.weather._update_environment(0)
	await view(survival.bed.global_position+Vector3.UP*.45,Vector3(2.8,4,3),4.4)
	await shot("N06_bedside_lamp_on","夜间床和床头灯的实机布局")
	survival.toggle_lamp()
	await tick(20)
	await shot("N07_bedside_lamp_off","关闭床头灯后的小屋照明")
	survival.offer_sleep()
	await shot("N08_sleep_prompt","夜间关灯后显示睡到早上七点的交互")
	await survival.sleep_until_morning()
	await shot("N09_morning_after_sleep","实际睡眠跳过夜晚并推进到次日七点")
	game.weather.hour=11
	game.weather._update_environment(0)
	await view(survival.chest.global_position+Vector3.UP*.3,Vector3(1.8,1.1,2.2),2.4)
	await shot("N10_chest_closed","储物箱关闭状态")
	survival._set_chest_open(true)
	await tick(30)
	await shot("N11_chest_open","储物箱盖打开状态")
	survival.open_chest()
	await shot("N12_storage_side_by_side","箱子与背包并排显示的存取界面")
	game.ui.close_storage()
	await tick(25)

func crocodile_evidence() -> void:
	var actor:Dictionary=game.crocodiles.actors[0]
	var body:CharacterBody3D=actor.body
	await land(body.global_position+Vector3(0,0,2.8))
	game.crocodiles._animate(actor,"Crawl",1)
	await view(body.global_position+Vector3.UP*.3,Vector3(2.5,1.6,3),4.2)
	await shot("N13_crocodile_crawl","西岸咸水鳄鱼与爬行动作")
	game.crocodiles._animate(actor,"Attack",1)
	await tick(12)
	await shot("N14_crocodile_attack","咸水鳄鱼张嘴攻击动作")
	var original:Vector3=body.global_position
	body.global_position=Vector3(600,-.2,600)
	game.crocodiles._animate(actor,"Swim",1)
	player._set_swimming(true)
	player.global_position=body.global_position+Vector3(0,0,2)
	player._play_motion("Treading Water",1)
	await view(body.global_position,Vector3(3,1.2,2.5),4.5)
	await shot("N15_crocodile_swim","咸水鳄鱼水中划动与摆尾动作")
	body.global_position=original

func hunting_evidence() -> void:
	var actor:Dictionary=game.crocodiles.actors[0]
	var point:Vector3=actor.body.global_position
	await land(point+Vector3(0,0,2))
	var target:Dictionary={"kind":"crocodile","actor":actor,"node":actor.body}
	h.damage_target(target,2)
	h.damage_target(target,2)
	await tick(5)
	var corpse:Node3D
	for drop:Node3D in game.fishing.dropped_fish.get_children():
		if drop.item.get("corpse_kind","")=="crocodile":corpse=drop
	var bounds:AABB=game.Utility.bounds(corpse.visual)
	for step in 30:
		await land(Vector3(bounds.position.x-.3+float(step)*.1,0,bounds.get_center().z))
		var surface:Vector3=h.corpse_point(corpse)
		if surface.distance_to(player.global_position)>.3 and surface.distance_to(player.global_position)<.8:break
	await view((player.global_position+corpse.global_position)*.5+Vector3.UP*.4,Vector3(-3,1.7,2.8),3.8)
	game.ui.notify("猎物留下完整尸体，需要剥皮小刀处理。",5)
	await shot("N16_whole_carcass","猎物死亡留下完整鳄鱼尸体",true)
	h.set_process(false)
	h.process_corpse(corpse)
	h._update_corpse_processing(1.1)
	await tick(6)
	await view(h.processing_target+Vector3.UP*.35,Vector3(1.8,1.5,2.4),2.8)
	await shot("N17_skinning_action","小刀贴近尸体表面的蹲姿切割动作")
	await view(h.processing_target+Vector3.UP*.12,Vector3(1,.8,1),1.4)
	await shot("N32_knife_surface","切割刀刃与尸体表面接触的实机近景")
	h._update_corpse_processing(1.2)
	await tick(4)
	game.ui.open_character("bag")
	game.ui._select_item({"id":"crocodile_meat","name":"鳄鱼肉","count":1})
	await shot("N18_processed_meat","处理尸体后获得用于烹饪的鳄鱼肉")
	game.ui.bag.hide()
	h.set_process(true)
	await land(game.survival.cabin_center+Vector3(9,0,4))
	game.progress.rifle_loaded=false
	game.use_item("hunting_rifle")
	await tick(10)
	await view(player.global_position+Vector3.UP,Vector3(-3,1.8,-3),3.5)
	await shot("N19_rifle_reload","猎枪装备后自动瞄准并进行单发装填")
	h.equip("")
	game.use_item("bow")
	await tick(65)
	await view(player.global_position+Vector3.UP,Vector3(-3,1.7,-3),3.5)
	await shot("N20_source_bow","左手持弓右手拉弦与缩窄帽檐")
	h.equip("")

func sea_evidence() -> void:
	game.voyage.offer()
	await shot("N21_eastern_quest","商人东海沉船与十六只鲨鱼委托")
	game.voyage.accept()
	game.ui.close_dialog()
	var site:Vector3=game.voyage.site
	player._set_swimming(true)
	player.global_position=site+Vector3.UP*2
	player._play_motion("Treading Water",1)
	await view(site+Vector3.UP*2,Vector3(7,1.5,8),15)
	await shot("N22_eastern_wreck","东部海域沉船宝藏与鲨群的运行场景")
	var shark:Dictionary=game.voyage.sharks[0]
	await view(shark.node.global_position,Vector3(3,1.4,3),4.4)
	await shot("N23_shark_swim_a","鲨鱼骨骼游动动作第一帧")
	await tick(18)
	await shot("N24_shark_swim_b","同一鲨鱼骨骼游动动作第二帧")
	game.damage_shark(shark,1)
	await shot("N25_shark_injury","鲨鱼受伤后进入十二秒退避状态",true)
	game.voyage.offer()
	await shot("N26_quest_progress","东海任务记录已清理数量与宝藏状态")
	game.ui.close_dialog()

func kitchen_evidence(home:Vector3) -> void:
	await land(home+Vector3(9,0,4))
	await view(player.global_position+Vector3.UP*1.1,Vector3(2.5,1.5,3),3.3)
	game.nutrition.hunger=0
	await tick(20)
	await shot("N27_head_stars","严重饥饿时人物头顶金星和画面边缘暗角")
	game.nutrition.hunger=70
	player.global_position=game.nutrition.pot.global_position+Vector3(1,0,0)
	await view(game.nutrition.pot.global_position+Vector3.UP*.4,Vector3(3,3,4),4.2)
	await shot("N28_cooking_pot","小屋门口的可交互大锅")
	game.nutrition.open_cooking()
	await shot("N29_cooking_recipes","鱼蔬菌果肉七种食谱的统一烹饪界面")
	game.nutrition.close_cooking()
	player.global_position=game.letter_table.global_position+Vector3(.6,0,.4)
	game.read_letter()
	await shot("N30_open_letter","阅读时在画面中央展开完整信件")
	game.ui.close_dialog()
