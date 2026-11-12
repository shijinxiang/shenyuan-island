extends Node3D

const Utility=preload("res://scripts/core/island_static_setup.gd")
const HARPOON_ONLY:=["Shark","ReefShark","Hammerhead","Squid","Octopus","StingRay"]
const SHARKS:=["Shark","ReefShark","Hammerhead"]
const HARPOON_GRIP := Vector3(0.0, 0.55, 0.0)
const EXTRA_NAMES:={"Shark":"灰鲨","ReefShark":"礁鲨","Hammerhead":"双髻鲨","Squid":"鱿鱼","Octopus":"章鱼","StingRay":"鳐鱼"}
const CATALOG = preload("res://scripts/adventure/island_economy.gd").CATALOG
const LETTER:="给来到这里的人：\n\n如果你读到了这封信，说明海把你送到了岸上。这里叫深渊岛，名字来自北面那条看不见底的海沟。\n\n屋子虽旧，仍能遮风。窗边的鱼竿留给你，内湖的小鱼能帮你熬过最初几天。外海的银鳍偶尔会绕进浅滩，遇见它们，先回到岸上。\n\n清晨留意码头。闻舟会带来种子和工具，拿鱼获就能换。他在日落前离开，也许知道外面的消息。\n\n别急着决定往后的一生。先吃饱，种下一颗种子，再修好一条船。深渊是这座岛的名字，却不必成为你人生的结局。愿这里，成为你人生新的开端。\n\n——岑安"
var world:Node3D
var player:CharacterBody3D
var fishing:Node3D
var weather:Node3D
var wildlife:Node3D
var progress:Dictionary
var ui:CanvasLayer
var opening:Node
var cinematic_active:=false
var dead:=false
var day_count:=1
var time_scale:=1
var context_text:=""
var context_kind:=""
var context_animal:Dictionary={}
var farming: Node3D
var skills: Node
var economy: RefCounted
var survival: Node3D
var crocodiles: Node3D
var vehicle: CharacterBody3D
var voyage: Node3D
var hunting: Node3D
var nutrition: Node3D
var hotbar: Control
var interaction: Node3D
var merchant:Node3D
var merchant_animation:AnimationPlayer
var merchant_collision:CollisionShape3D
var merchant_available:=false
var talk_index:=0
var rod_pickup:Node3D
var letter_table:Node3D
var harpoon:Node3D
var harpoon_equipped:=false
var capture_cooldown:=0.0
var injuries:=0
var hit_cooldown:=0.0
var recovery_time:=0.0
var autosave:=30.0
var context_timer:=0.0
var predators:Array[Dictionary]=[]
var selected_seed:=""

func _ready() -> void:
	world=get_parent();player=world.get_node("Player");fishing=world.get_node("Fishing");weather=world.get_node("IslandWeather");wildlife=world.get_node("IslandWildlife")
	player.adventure=self
	progress=fishing.progress_data
	var defaults:={"goods":[],"crops":[],"creative":false,"intro_seen":false,"rod_found":false,"letter_read":false,"merchant_intro":false,"day":1,"hour":11.0,"time_scale":1}
	for key in defaults:if not progress.has(key):progress[key]=defaults[key]
	day_count=int(progress.day);time_scale=int(progress.time_scale);weather.hour=float(progress.hour)
	injuries = clampi(int(progress.get("injuries", 0)), 0, 3)
	economy = preload("res://scripts/adventure/island_economy.gd").new(self)
	skills = preload("res://scripts/adventure/island_skills.gd").new()
	skills.name = "IslandSkills"
	add_child(skills)
	_setup_merchant()
	_setup_cabin()
	harpoon=load("res://assets/adventure/harpoon.glb").instantiate();world.add_child(harpoon);harpoon.hide()
	fishing.skeleton.skeleton_updated.connect(_update_harpoon)
	for animal:Dictionary in wildlife.fish:
		if animal.species in SHARKS:
			animal.adventure_control=true
			animal.behavior="patrol"
			animal.visit_timer=randf_range(15,50)
			animal.retreat_timer=0.0
			animal.destination=animal.curve.sample_baked(float(animal.distance),true)
			animal.node.position = animal.destination + Vector3.UP * float(animal.offset)
			predators.append(animal)
	ui=preload("res://scripts/ui/island_game_ui.gd").new();add_child(ui)
	world.get_node("HUD").hide()
	weather.get_node("WeatherControls").hide()
	opening=preload("res://scripts/adventure/island_opening.gd").new();add_child(opening)
	if has_good("voyager"):player.rowing.apply_upgrade()
	farming = preload("res://scripts/farming/island_farming.gd").new()
	farming.name = "IslandFarming"
	add_child(farming)
	survival = preload("res://scripts/adventure/island_survival.gd").new()
	survival.name = "IslandSurvival"
	add_child(survival)
	crocodiles = preload("res://scripts/wildlife/island_crocodiles.gd").new()
	crocodiles.name = "IslandCrocodiles"
	add_child(crocodiles)
	vehicle = preload("res://scripts/boating/beach_buggy.gd").new()
	vehicle.name = "BeachBuggy"
	add_child(vehicle)
	voyage = preload("res://scripts/adventure/merchant_voyage.gd").new()
	voyage.name = "MerchantVoyage"
	add_child(voyage)
	nutrition = preload("res://scripts/adventure/island_nutrition.gd").new()
	nutrition.name = "IslandNutrition"
	add_child(nutrition)
	hunting = preload("res://scripts/adventure/island_hunting.gd").new()
	hunting.name = "IslandHunting"
	add_child(hunting)
	hotbar = preload("res://scripts/ui/tool_hotbar.gd").new()
	hotbar.game = self
	ui.add_child(hotbar)
	interaction = preload("res://scripts/adventure/island_interaction.gd").new()
	interaction.name = "ObjectInteraction"
	add_child(interaction)
	call_deferred("_start_if_new")
	print("ISLAND_ADVENTURE_READY merchant/tides/backpack/predators")

func _start_if_new() -> void:
	if not progress.intro_seen:opening.present()

func creative() -> bool:return bool(progress.get("creative",false))
func save() -> bool:
	progress.day=day_count;progress.hour=weather.hour;progress.time_scale=time_scale
	progress.injuries = injuries
	fishing.progress_data=progress
	return fishing._save_catches()

func restore_progress(before: Dictionary) -> void:
	progress.clear()
	progress.merge(before, true)
	if is_instance_valid(crocodiles):
		for actor: Dictionary in crocodiles.actors:
			for record: Dictionary in progress.crocodiles:
				if record.id == actor.record.id:
					actor.record = record
					break

func set_time_scale(value:int) -> void:
	time_scale=value;save();ui.notify("时间流速  ×"+str(value))

func _setup_merchant() -> void:
	merchant=Node3D.new();merchant.name="WenzhouMerchant";world.add_child(merchant)
	merchant.hide()
	merchant.position=Vector3(143.58,.87,124.04)
	var model:Node3D=load("res://assets/characters/C03_talking.glb").instantiate();merchant.add_child(model)
	merchant_animation=model.find_children("*","AnimationPlayer",true,false)[0]
	for clip in merchant_animation.get_animation_list():merchant_animation.get_animation(clip).loop_mode=Animation.LOOP_LINEAR
	merchant_animation.play("Idle")
	var body:=StaticBody3D.new();merchant.add_child(body)
	merchant_collision=CollisionShape3D.new();var shape:=CapsuleShape3D.new();shape.radius=.30;shape.height=1.72;merchant_collision.shape=shape;merchant_collision.position.y=.86;body.add_child(merchant_collision)
	merchant_collision.disabled=true

func _setup_cabin() -> void:
	var cabin:=world.get_node("Island").find_child("B01*",true,false) as Node3D
	var bounds:=Utility.bounds(cabin)
	var center:=bounds.get_center()
	letter_table=load("res://assets/adventure/letter_table.glb").instantiate();world.add_child(letter_table)
	letter_table.position=cabin.to_global(Vector3(1.65,.65,-.55))
	letter_table.rotation.y=cabin.global_rotation.y
	var body:=StaticBody3D.new();letter_table.add_child(body)
	var collider:=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=Vector3(.8,.70,.55);collider.shape=shape;collider.position.y=.35;body.add_child(collider)
	rod_pickup=load("res://assets/fishing/fishing_rod_rigged.glb").instantiate();world.add_child(rod_pickup)
	for animation:AnimationPlayer in rod_pickup.find_children("*","AnimationPlayer",true,false):animation.stop()
	rod_pickup.position=cabin.to_global(Vector3(1.05,.72,-.55))
	rod_pickup.rotation.z=-.20
	rod_pickup.visible=not progress.rod_found
	_settle_cabin_props.call_deferred(body)

func _settle_cabin_props(table_body:StaticBody3D) -> void:
	await get_tree().physics_frame
	var point:=letter_table.position
	var query:=PhysicsRayQueryParameters3D.create(point+Vector3.UP*1.5,point-Vector3.UP*1.0,1,[table_body.get_rid(),player.get_rid()])
	var hit:=get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		letter_table.position.y=hit.position.y+.015
		rod_pickup.position.y=hit.position.y+.10

func has_good(id:String) -> bool:
	if id == "harpoon" and has_good("harpoon_steel"):
		return true
	for item:Dictionary in progress.goods:
		if item.id==id and int(item.get("count",0))>0:return true
	return false

func item_model(item:Dictionary) -> Node3D:
	if item.id == "fishing_rod":
		return load("res://assets/fishing/fishing_rod_rigged.glb").instantiate()
	if item.id in ["hunting_rifle", "bow", "wooden_arrow", "rifle_ammo", "skinning_knife"]:
		return load("res://assets/hunting/" + str(item.id) + ".glb").instantiate()
	if str(item.id).begins_with("dish_") or str(item.id).begins_with("delicious_dish_") or item.id in ["wild_berry", "wild_mushroom", "animal_meat", "fish_meat", "shark_meat", "crocodile_meat"]:
		if is_instance_valid(nutrition):
			return nutrition.item_model(str(item.id))
		return load("res://assets/cooking/meal_bowl.glb").instantiate()
	if item.id=="harpoon":return load("res://assets/adventure/harpoon.glb").instantiate()
	if item.id=="voyager":return load("res://assets/adventure/voyager_boat.glb").instantiate()
	if item.id in farming.TOOLS or item.id == "wood":return farming.item_model(str(item.id))
	if item.id == "harpoon_steel":return load("res://assets/adventure/harpoon.glb").instantiate()
	if item.id in ["rod_improved", "rod_master"]:return load("res://assets/fishing/fishing_rod_rigged.glb").instantiate()
	if item.id == "medical_kit":return load("res://assets/survival/medical_kit.glb").instantiate()
	if item.id in ["meal", "boots", "life_jacket", "crocodile_meat"]:return load("res://assets/survival/food_bundle.glb").instantiate()
	if item.id == "lantern":return load("res://assets/survival/cabin_lamp.glb").instantiate()
	if item.id == "beach_buggy":return load("res://assets/vehicle/beach_buggy.glb").instantiate()
	if item.id == "quest_treasure":return load("res://assets/survival/chest.glb").instantiate()
	if str(item.id).begins_with("crop_"):return farming.crop_model(str(item.id).replace("crop_",""),3)
	return load("res://assets/adventure/seed_bag.glb").instantiate()

func item_description(item:Dictionary) -> String:
	if item.id == "skinning_knife":
		return "随身带上即可使用。猎物倒下会留下完整尸体，靠近后按 E 用小刀切割取肉，处理需要约2秒。"
	if item.id == "fishing_rod":
		return "可拖入下方五格工具栏。选择此格后进入钓鱼状态，F 收竿。"
	if item.id in ["hunting_rifle", "bow", "wooden_arrow", "rifle_ammo", "wood"]:
		return {"hunting_rifle":"单发猎枪。装备后自动瞄准，点击左键射击，R装填。熟练度使装填从3秒缩至1.5秒，子弹只能向闻舟购买。", "bow":"木弓。装备后自动瞄准，点击左键射箭。木箭可用1份木材制作3支，C快捷制作。", "wooden_arrow":"木弓使用的箭，可向商人购买或用木材制作。", "rifle_ammo":"猎枪弹，仅能向商人购买。每次装填一发。", "wood":"砍树得到的木材。可交换物资，或制作3支木箭。"}[item.id]
	if is_instance_valid(nutrition) and (nutrition.is_food(item.id) or item.id in nutrition.FOOD_NAMES):
		return nutrition.description(item.id)
	if economy.DESCRIPTIONS.has(item.id):
		return str(economy.DESCRIPTIONS[item.id])
	match item.id:
		"harpoon":return "在水里停下后按 E 捕捉小型猎物，或多次攻击鲨鱼。鲨鱼受伤会逃离，击败后获得肉类。"
		"voyager":return "更宽的船身和更快的航速。已经替换码头的旧船。"
		"axe":return "装备后靠近树木按 E 砍伐，三次砍倒后会掉落几段木头。树桩也可以清理。X 轮换工具。"
		"hoe":return "装备后站在平缓草地按 E 开垦有厚度的耕地，选好种子后按 G 播种。X 轮换工具。"
		"watering_can":return "装备后靠近耕地按 E 浇水。每天都要浇水，下雨会自动浇水；干涸会暂停生长。X 轮换工具。"
		"wood":return "砍树和清理树桩获得的木材，已经收入行囊。"
		"beach_buggy":return "完成闻舟的东海委托获得的沙滩车。靠近车按 E 上下车，WASD 驾驶，Shift 加速。"
		"quest_treasure":return "东部沉船的宝藏。清理鲨群并将它带给闻舟，可以交换沙滩车。"
		"crocodile_meat":return "抵御鳄鱼后获得的食材，可向闻舟换取旅行干粮。"
		_:return "选择后在空耕地旁按 G 播种。每天浇水，萝卜3天、番茄4天、南瓜5天成熟；下雨无需手动浇水。" if str(item.id).begins_with("seed_") else "在岛上种出的收获，已经收进行囊。"

func is_equipped(id: String) -> bool:
	if id == "fishing_rod":
		return player.fishing_active
	if id in ["hunting_rifle", "bow"]:
		return hunting.equipped == id
	if id in ["harpoon", "harpoon_steel"]:
		return harpoon_equipped
	return id in farming.TOOLS and farming.selected_tool == id

func use_item(id:String) -> void:
	if id == "fishing_rod":
		if player.fishing_active:
			fishing.set_active(false)
			return
		hunting.equip("")
		farming.equip_tool("")
		harpoon_equipped = false
		if not player.fishing_active:
			fishing.set_active(true)
	elif id in ["hunting_rifle", "bow"]:hunting.equip("" if hunting.equipped == id else id)
	elif id == "wood":hunting.craft_arrows()
	elif nutrition.is_food(id):nutrition.eat(id)
	elif id=="harpoon":toggle_harpoon()
	elif id == "harpoon_steel":toggle_harpoon()
	elif id in economy.CONSUMABLES:economy.consume_item(id)
	elif id == "lantern":survival.toggle_lamp(true)
	elif id in farming.TOOLS:
		hunting.equip("")
		farming.equip_tool("" if farming.selected_tool == id else id)
	elif id.begins_with("seed_"):
		selected_seed=id;ui.notify("种子已选好，靠近空耕地按 G 播种。")

func toggle_harpoon() -> void:
	if not has_good("harpoon"):return
	if is_instance_valid(hunting):
		hunting.equip("")
	if player.fishing_active:fishing.set_active(false)
	harpoon_equipped=not harpoon_equipped
	if harpoon_equipped and not farming.selected_tool.is_empty():farming.equip_tool("")
	ui.notify("鱼叉已装备，游动时自动收起，停下后按 E 捕捉或抵御鲨鱼。" if harpoon_equipped else "鱼叉已收起。",2.0)

func _update_harpoon() -> void:
	harpoon.visible = harpoon_equipped and not cinematic_active and not dead and not player.fishing_active and not player.swim_moving and not player.in_vehicle() and player.current_motion != "Harvest" and not (is_instance_valid(hunting) and hunting.processing_corpse)
	if not harpoon.visible:
		return
	var skeleton: Skeleton3D = fishing.skeleton
	var hand_pose := skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone("RightHand"))
	var hand: Vector3 = hand_pose * Vector3(0.0, 0.09, -0.048)
	var axis := -hand_pose.basis.x.normalized()
	var side := hand_pose.basis.y.normalized()
	var orientation := Basis(side, axis, side.cross(axis).normalized())
	harpoon.global_transform = Transform3D(orientation, hand - orientation * HARPOON_GRIP)
func handle_key(event:InputEvent) -> bool:
	if not event is InputEventKey or not event.pressed or event.echo:return false
	if cinematic_active or dead:return true
	if event.keycode == KEY_M:
		survival.toggle_map()
		return true
	if event.keycode == KEY_P:
		ui.toggle_character()
		return true
	if ui.modal_open():return true
	if hunting.handle_key(event):return true
	if event.keycode==KEY_E:return interact()
	if event.keycode==KEY_Q:toggle_harpoon();return true
	if event.keycode==KEY_G:plant_seed();return true
	if event.keycode==KEY_X:
		hunting.equip("")
		farming.cycle_tool()
		return true
	if event.keycode==KEY_F and not progress.rod_found:
		ui.notify("木屋窗边有一支鱼竿。去看看吧。");return true
	return false

func can_offer_fishing() -> bool:
	if not progress.rod_found or player.swimming or player.in_vehicle():return false
	if player.fishing_active or player.rowing.boarded:return true
	for index in 8:
		var angle:=float(index)*TAU/8.0
		var point:=player.global_position+Vector3(sin(angle),0,cos(angle))*8.0
		if wildlife.schools.column(point).x<-.5:return true
	return false

func _update_context() -> void:
	context_text="";context_kind="";context_animal={}
	if cinematic_active or dead:return
	if is_instance_valid(interaction):
		var targeted: Dictionary = interaction.context()
		if not targeted.is_empty():
			context_kind = "targeted"
			context_text = targeted.text
			return
	var point:=player.global_position
	if player.in_vehicle():
		var vehicle_context: Dictionary = vehicle.context()
		if not vehicle_context.is_empty():
			context_kind = "vehicle"
			context_text = vehicle_context.text
		return
	var nearby_car: Dictionary = vehicle.context()
	if not nearby_car.is_empty() and point.distance_to(vehicle.global_position) < 1.8:
		context_kind = "vehicle"
		context_text = nearby_car.text
		return
	if merchant_available and point.distance_to(merchant.position)<3.0:
		context_kind="merchant";context_text="E  与闻舟交谈";return
	if not progress.rod_found and point.distance_to(rod_pickup.position)<2.3:
		context_kind="rod";context_text="E  拿起鱼竿";return
	var home_context: Dictionary = survival.context()
	if not home_context.is_empty():
		context_kind = "home"
		context_text = home_context.text
		return
	if point.distance_to(letter_table.position)<2.5:
		context_kind="letter";context_text="E  阅读留下的信";return
	var nutrition_context: Dictionary = nutrition.context()
	if not nutrition_context.is_empty():
		context_kind = "nutrition"
		context_text = nutrition_context.text
		return
	if is_instance_valid(fishing.pickup_candidate):
		context_kind="pickup";context_text=hunting.pickup_text(fishing.pickup_candidate);return
	var crocodile_context: Dictionary = crocodiles.context()
	if not crocodile_context.is_empty():
		context_kind = "crocodile"
		context_text = crocodile_context.text
		return
	var salvage_context: Dictionary = voyage.context()
	if not salvage_context.is_empty():
		context_kind = "salvage"
		context_text = salvage_context.text
		return
	var farm_context: Dictionary = farming.context()
	if not farm_context.is_empty():
		context_kind = "farming"
		context_text = farm_context.text
		return
	var car_context: Dictionary = vehicle.context()
	if not car_context.is_empty():
		context_kind = "vehicle"
		context_text = car_context.text
		return
	if player.swimming:
		var using_harpoon: bool = harpoon_equipped and not player.swim_moving
		var nearest:=4.5 if using_harpoon else 1.8
		for animal:Dictionary in wildlife.fish:
			if animal.get("caught",false):continue
			var spear_only:bool=animal.species in HARPOON_ONLY
			if spear_only and not using_harpoon:continue
			if not spear_only and (not fishing.FISH_NAMES.has(animal.species) or float(animal.fish_length)>.85):continue
			var distance:float=animal.node.position.distance_to(point)
			if distance<nearest:nearest=distance;context_animal=animal
		if not context_animal.is_empty():
			context_kind="catch"
			context_text = "E  用鱼叉击退鲨鱼" if context_animal.species in SHARKS else "E  " + ("鱼叉捕捉" if using_harpoon else "徒手捉鱼")
			return
	if player.rowing.boarded or point.distance_to(player.rowing.global_position)<6.0:
		context_kind="boat";context_text="E  下船" if player.rowing.boarded else "E  上船"

func interact() -> bool:
	if cinematic_active or dead or ui.modal_open():return false
	if hunting.processing_corpse:return true
	if is_instance_valid(interaction):
		interaction.refresh()
		if interaction.interact():
			return true
	_update_context()
	match context_kind:
		"merchant":open_merchant()
		"rod":progress.rod_found=true;rod_pickup.hide();save();ui.notify("拿到了鱼竿。靠近水边，按 F 开始钓鱼。")
		"letter":read_letter()
		"pickup":fishing.try_pickup()
		"catch":capture_swimming_fish()
		"boat":player.rowing.interact()
		"farming":farming.interact()
		"home":survival.interact()
		"crocodile":crocodiles.strike()
		"vehicle":vehicle.interact()
		"salvage":voyage.salvage()
		"nutrition":nutrition.interact()
		_:return false
	return true

func read_letter() -> void:
	progress.letter_read=true;save()
	ui.show_letter(LETTER)

func _talk() -> void:
	talk_index=(talk_index%3)+1
	merchant_animation.play("Talk"+str(talk_index),.25)

func stop_talking() -> void:
	if merchant_animation:merchant_animation.play("Idle",.25)

func open_merchant() -> void:
	if not merchant_available:return
	if not progress.merchant_intro:_first_story(0);return
	_talk()
	ui.show_dialog("闻舟 · 随潮而来的商人","早上好，小爱。今天的潮水不错。想换些东西，还是听听外面的消息？",[
		{"text":"看看你带来的东西","action":open_shop},
		{"text":"聊聊外面的世界","action":open_news},
		{"text":"东海委托与沙滩车","action":func():voyage.offer()},
		{"text":"猎枪的系列委托","action":func():hunting.quest.offer()},
		{"text":"晚些时候再见","action":func():ui.close_dialog()}])

func _first_story(page:int) -> void:
	var pages:=["你就是那条废船上的姑娘吧？我叫闻舟，沿着这片海的旧航线做些小买卖。别怕，这里有人来，也有人离开。", "这座岛的名字，是老渔民照着北边的深海沟取的。以前岑安住在那间木屋，他总说，走到路尽头的人，最需要一盏亮着的灯。", "后来他去北岸找人，把屋子和鱼竿留了下来。我答应他，每个天亮都来码头看看。没想到，这回等到了你。", "你可以用鱼获换我的种子、鱼叉和船。先把肚子填饱，再慢慢想回去的路。小爱，深渊岛也可以是一个新的开头。"]
	_talk()
	ui.show_dialog("闻舟",pages[page],[{"text":"继续" if page<pages.size()-1 else "我想先看看物资","action":func():
		if page<pages.size()-1:_first_story(page+1)
		else:progress.merchant_intro=true;save();open_shop()}])

func open_news() -> void:
	_talk()
	ui.show_dialog("闻舟 · 海那边的消息","你想听哪一段航路上的事？",[
		{"text":"灯港最近怎么样？","action":func():news("灯港的集市重新开张了。面包铺的烟囱又开始冒烟，码头上也有人等着失散的家人。外面的世界还在往前走。")},
		{"text":"北面的航路安全吗？","action":func():news("北风正把鱼群往浅滩推，鲨鱼也会跟着来。出海时留意水面的背鳍。等你有了更结实的船，我会把绕开暗礁的路告诉你。")},
		{"text":"岑安去了哪里？","action":func():news("最后一封信从白沙湾寄来。他说要找到一位很多年没见的朋友。如果下次有新的信，我会带给你。有人愿意等，远方就还有意义。")},
		{"text":"返回","action":open_merchant}])

func news(text:String) -> void:
	_talk();ui.show_dialog("闻舟",text,[{"text":"再听一件事","action":open_news},{"text":"谢谢你","action":open_merchant}])

func open_shop() -> void:
	economy.open_shop()

func trade(product:Dictionary) -> void:
	economy.trade(product)

func _add_good(id:String,title:String,count:int) -> void:
	for item:Dictionary in progress.goods:
		if item.id==id:item.count=int(item.count)+count;return
	progress.goods.append({"id":id,"name":title,"count":count})

func capture_swimming_fish() -> void:
	if capture_cooldown>0 or context_animal.is_empty():return
	var animal:Dictionary=context_animal
	if animal.get("caught",false):return
	if animal.species in HARPOON_ONLY and (not harpoon_equipped or player.swim_moving):return
	var query:=PhysicsRayQueryParameters3D.create(player.global_position+Vector3.UP*.2,animal.node.global_position,1,[player.get_rid()])
	var obstruction:=get_world_3d().direct_space_state.intersect_ray(query)
	if not obstruction.is_empty():ui.notify("猎物躲在遮挡物后面，换个方向靠近。",2.0);return
	capture_cooldown=1.0
	if animal.species in SHARKS:
		if damage_shark(animal, 2 if has_good("harpoon_steel") else 1):
			_spear_flash(animal.node.global_position)
		return
	var length:float=animal.fish_length
	var title:String=EXTRA_NAMES.get(animal.species,fishing.FISH_NAMES.get(animal.species,animal.species))
	var item:={"id":str(Time.get_unix_time_from_system())+"_"+str(randi()),"species":animal.species,"name":title,"length_m":length,"weight_kg":snappedf((.12+pow(length,3)*2)*randf_range(.8,1.2),.01),"habitat":animal.habitat,"time":Time.get_datetime_string_from_system()}
	fishing.catches.append(item)
	var cleared_before: Array = progress.buggy_quest.cleared.duplicate()
	voyage.mark_shark(animal)
	if not save():
		fishing.catches.pop_back()
		progress.buggy_quest.cleared = cleared_before
		return
	if harpoon_equipped and not player.swim_moving:_spear_flash(animal.node.global_position)
	animal.caught=true;animal.node.hide();animal.erase("fishing_target")
	player.interaction_time=.55;player.interaction_clip="Treading Water";player.interaction_rate=1.0
	player.get_node("MovementVFX")._spawn_water(Vector3(animal.node.position.x,player.water_level+.03,animal.node.position.z),.65)
	ui.notify(("捕捉到 " if harpoon_equipped else "抓住了 ")+title+"，已收入背包。")
	context_animal={}

func damage_shark(animal: Dictionary, damage: float) -> bool:
	if animal.get("caught", false) or damage <= 0:
		return false
	var before := progress.duplicate(true)
	var previous_hp := float(animal.get("hp", 4))
	var hp := maxf(0, previous_hp - damage)
	var dropped: Node3D
	if not progress.has("animal_health"):
		progress.animal_health = {}
	progress.animal_health[String(animal.node.name)] = hp
	if hp == 0:
		dropped = hunting.create_corpse("marine", animal)
		voyage.mark_shark(animal)
		progress.hunting_stats.kills = int(progress.hunting_stats.get("kills", 0)) + 1
		skills.add_xp("hunting", 12)
	if not save():
		hunting.discard_drop(dropped)
		restore_progress(before)
		return false
	animal.hp = hp
	if hp == 0:
		animal.caught = true
		animal.node.hide()
		if animal.animator:
			animal.animator.active = false
		ui.notify("鲨鱼已经倒下，随身带上剥皮小刀，靠近尸体按 E 处理。")
	else:
		animal.retreat_timer = 12.0
		animal.destination = animal.node.global_position + (animal.node.global_position - player.global_position).normalized() * 24.0
		var pain := create_tween()
		pain.tween_property(animal.node, "rotation:z", .16, .08)
		pain.tween_property(animal.node, "rotation:z", 0.0, .22)
		ui.notify("鲨鱼吃痛逃开了，留意它再次游回。", 2.0)
	return true

func _spear_flash(target:Vector3) -> void:
	var projectile:Node3D=load("res://assets/adventure/harpoon.glb").instantiate();world.add_child(projectile)
	projectile.global_transform=harpoon.global_transform
	var tween:=create_tween();tween.tween_property(projectile,"global_position",target,.16);tween.tween_callback(projectile.queue_free)

func _safe_predator(point:Vector3) -> bool:
	var bed:Vector2=wildlife.schools.column(point)
	return bed.x<-.95 and bed.y<.4 and point.y>bed.x+.32 and point.y<-.35

func _update_predators(delta:float) -> void:
	for animal in predators:
		if animal.get("caught",false):continue
		var actor:Node3D=animal.node
		animal.visit_timer=float(animal.visit_timer)-delta
		animal.retreat_timer=maxf(0,float(animal.retreat_timer)-delta)
		var distance:=actor.position.distance_to(player.global_position)
		var hungry: bool = animal.get("quest_shark", false)
		var attack:bool=player.swimming and not dead and not cinematic_active and distance<(24.0 if hungry else 13.0) and animal.retreat_timer<=0.0
		var target:Vector3=animal.destination
		var speed:=1.1
		if animal.retreat_timer > 0.0:
			speed = 4.4
			if distance < 18.0:
				target = actor.position + (actor.position - player.global_position).normalized() * 24.0
				animal.destination = target
		elif attack:
			target=player.global_position+Vector3.DOWN*.7;speed=3.25 if hungry else 2.9
		elif animal.retreat_timer<=0.0:
			if animal.visit_timer<=0.0:
				animal.visit_timer=randf_range(45,80)
				animal.destination=animal.home+Vector3(randf_range(-12,12),1.2,randf_range(-12,12)) if hungry else Vector3(randf_range(158,180),-1.5,randf_range(145,168))
			elif actor.position.distance_to(target)<2.0:
				animal.distance=fposmod(float(animal.distance)+randf_range(10,25),animal.curve.get_baked_length())
				animal.destination=animal.curve.sample_baked(animal.distance,true)
		var steering:Vector3=(target-actor.position).normalized()+wildlife.schools.rock_avoidance(actor.position)*1.1
		var velocity:=steering.normalized()*speed
		var candidate:=actor.position+velocity*delta
		var bed:Vector2=wildlife.schools.column(candidate)
		candidate.y=clampf(candidate.y,bed.x+.4,-.65)
		if _safe_predator(candidate):actor.position=candidate
		else:
			if animal.retreat_timer > 0:
				var away := actor.position - player.global_position
				away.y = 0
				for angle in [.5, -.5, 1.0, -1.0, 1.45, -1.45]:
					var escape := away.normalized().rotated(Vector3.UP, angle) * speed
					var alternate := actor.position + escape * delta
					var column: Vector2 = wildlife.schools.column(alternate)
					alternate.y = clampf(alternate.y, column.x + .4, -.65)
					if _safe_predator(alternate):
						actor.position = alternate
						velocity = escape
						break
			else:
				animal.distance=fposmod(float(animal.distance)+2.0,animal.curve.get_baked_length())
				animal.destination=animal.curve.sample_baked(animal.distance,true)
		if velocity.length_squared()>.01:actor.rotation.y=lerp_angle(actor.rotation.y,atan2(-velocity.x,-velocity.z),1-exp(-delta*2.5))
		actor.visible=actor.position.distance_to(player.global_position)<220
		if animal.animator:animal.animator.active=actor.visible;animal.animator.speed_scale=2.1 if animal.retreat_timer > 0 else 1.5 if attack else .85
		if attack and distance<1.65 and hit_cooldown<=0.0:
			take_hit(actor.position)
			animal.retreat_timer=5.0
			animal.destination=actor.position+(actor.position-player.global_position).normalized()*9.0

func take_hit(source:Vector3, attacker := "鲨鱼") -> void:
	if dead or cinematic_active or hit_cooldown > 0:return
	hit_cooldown=3.5;injuries+=1
	ui.flash.color.a=.24
	ui.bag.hide();ui.settings.hide()
	survival.hide_map()
	player.velocity+=(player.global_position-source).normalized()*2.0
	if injuries>=4:
		dead=true
		if player.fishing_active:fishing.set_active(false)
		player.hide()
		ui.show_dialog("旅程暂歇","小爱没能躲开这次袭击。\n\n休息片刻，再从小屋附近重新出发。",[{"text":"重新出发","action":revive}])
	else:ui.notify(attacker + "咬到了你，快拉开距离！" if injuries<3 else "已经撑不住了，尽快脱离危险！",3.0)
	save()

func revive() -> void:
	dead=false;injuries=0;hit_cooldown=8.0
	ui.close_dialog();player.show();player.call_deferred("_place_on_ground")
	save()

func plant_seed() -> void:
	if is_instance_valid(interaction) and interaction.plant_selected():
		return
	farming.plant_seed()

func start_opening() -> void:opening.present()

func _process(delta:float) -> void:
	capture_cooldown=maxf(0,capture_cooldown-delta);hit_cooldown=maxf(0,hit_cooldown-delta)
	if not player.swimming and injuries>0:
		recovery_time+=delta
		if recovery_time>20:injuries-=1;recovery_time=0
	else:recovery_time=0
	var available:bool=weather.hour>=6.0 and weather.hour<19.0 and not cinematic_active
	if available!=merchant_available:
		merchant_available=available;merchant.visible=available;merchant_collision.set_deferred("disabled",not available)
		if not available and ui.dialog.visible and ui.speaker.text.begins_with("闻舟"):ui.close_dialog();ui.notify("闻舟随晚潮离开了，明早再来码头吧。")
	if merchant_available and player.global_position.distance_to(merchant.position)<8.0:merchant.rotation.y=lerp_angle(merchant.rotation.y,atan2(player.global_position.x-merchant.position.x,player.global_position.z-merchant.position.z),delta*2)
	_update_harpoon()
	context_timer-=delta
	if context_timer<=0.0:context_timer=.12;_update_context()
	if not cinematic_active:_update_predators(delta)
	autosave-=delta
	if autosave<=0 and not cinematic_active:autosave=30;save()



