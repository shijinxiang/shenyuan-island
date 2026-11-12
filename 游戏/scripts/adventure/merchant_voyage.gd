extends Node3D

const SHARK_COUNT := 16
var game: Node3D
var sharks: Array[Dictionary] = []
var treasure: Node3D
var wreck: Node3D
var site := Vector3.ZERO

func _ready() -> void:
	game = get_parent()
	if not game.progress.has("buggy_quest"):
		game.progress.buggy_quest = {"status":"not_started","cleared":[],"site":[]}
	call_deferred("_restore_site")

func remaining() -> int:
	return maxi(0, SHARK_COUNT - game.progress.buggy_quest.cleared.size())

func offer() -> void:
	var status: String = game.progress.buggy_quest.status
	if status == "complete":
		game.ui.show_dialog("闻舟 · 沙滩车", "沙滩车已经归你了。W 前进，S 刹车并倒车，A/D 转向，Shift 加速。地图上能找到车辆；卡住或陷入水中时，我可以帮你送回小屋外。", [{"text":"把车送回小屋外","action":func():game.vehicle.return_to_home();game.ui.notify("车辆已送回小屋外。")},{"text":"返回交谈","action":game.open_merchant}])
		return
	if status == "not_started":
		game.ui.show_dialog("闻舟 · 东海沉船", "东边海域的旧沉船旁聚了16只饥肠辘辘的鲨鱼。清理鲨群，再下潜打捞沉船宝藏，我就用一辆沙滩车和你交换。\n\n准备鱼叉、船和补给再出发。灯塔方向为南，航行图右边是东。", [{"text":"接下这次委托","action":accept},{"text":"先准备装备","action":game.open_merchant}])
		return
	var ready: bool = remaining() == 0 and game.has_good("quest_treasure")
	var text := "东部鲨群已清理 %d / %d 只。\n沉船宝藏  %s\n\n带回宝藏后，就能换取沙滩车。" % [SHARK_COUNT-remaining(),SHARK_COUNT,"已打捞" if game.has_good("quest_treasure") else "尚未打捞"]
	game.ui.show_dialog("闻舟 · 东海沉船", text, [{"text":"交付宝藏，换取沙滩车","disabled":not ready,"action":complete},{"text":"在航行图查看位置","action":game.survival.toggle_map},{"text":"返回交谈","action":game.open_merchant}])

func _find_site() -> Vector3:
	var coast: Array = JSON.parse_string(FileAccess.get_file_as_string("res://assets/generated/outer_coast.json"))
	for point: Array in coast:
		var shore := Vector3(point[0],0,point[1])
		if shore.normalized().dot(game.survival.east) < .8:
			continue
		for distance in [48.0,56.0,64.0,72.0]:
			var candidate: Vector3 = shore + shore.normalized() * distance
			var column: Vector2 = game.wildlife.schools.column(candidate)
			if column.x > -3.0 or column.x < -9.0 or column.y > .4:
				continue
			var query := PhysicsRayQueryParameters3D.create(candidate+Vector3.UP*5,candidate+Vector3.DOWN*15,1,[game.player.get_rid()])
			var hit := get_world_3d().direct_space_state.intersect_ray(query)
			if not hit.is_empty() and hit.position.y < -2.5 and hit.position.y > -9:
				candidate.y = hit.position.y
				return candidate
	return Vector3.ZERO

func accept() -> void:
	if game.progress.buggy_quest.status != "not_started":
		offer()
		return
	var point := _find_site()
	if point == Vector3.ZERO:
		game.ui.notify("暂时没有找到安全的打捞点，请稍后再来。")
		return
	game.progress.buggy_quest = {"status":"active","cleared":[],"site":[point.x,point.y,point.z]}
	if not game.save():
		game.progress.buggy_quest.status = "not_started"
		return
	_spawn_site(point)
	game.ui.notify("委托已接下。东部沉船已经标在地图上。",4.0)
	offer()

func _restore_site() -> void:
	await get_tree().physics_frame
	if game.progress.buggy_quest.status == "active":
		var point: Array = game.progress.buggy_quest.site
		if point.size() == 3:
			_spawn_site(Vector3(point[0],point[1],point[2]))

func _spawn_site(point: Vector3) -> void:
	if treasure != null:
		return
	site = point
	wreck = load("res://assets/optimized/P02.glb").instantiate()
	add_child(wreck)
	wreck.position = site + Vector3.UP*.25
	wreck.scale = Vector3.ONE*1.8
	wreck.rotation = Vector3(.1,.7,.24)
	treasure = load("res://assets/survival/chest.glb").instantiate()
	add_child(treasure)
	treasure.position = site + game.survival.east*2.4 + Vector3.UP*.05
	var query := PhysicsRayQueryParameters3D.create(treasure.global_position+Vector3.UP*8,treasure.global_position+Vector3.DOWN*12,1,[game.player.get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		treasure.global_position.y = hit.position.y + .05
	if game.has_good("quest_treasure"):
		treasure.find_child("LidPivot",true,false).rotation.x = -1.3
	game.survival.map_data.buildings.append({"name":"东部沉船","position":site})
	var bounds: Rect2 = game.survival.map_data.bounds
	var coordinate: Vector2 = game.survival.map_coordinate(site)
	game.survival.map_data.bounds = bounds.expand(coordinate+Vector2.ONE*20).expand(coordinate-Vector2.ONE*20)
	var template: Dictionary = {}
	for animal: Dictionary in game.wildlife.fish:
		if animal.species == "Shark":
			template = animal
			break
	assert(not template.is_empty(), "Shark template missing")
	for index in SHARK_COUNT:
		if index in game.progress.buggy_quest.cleared:
			continue
		var animal := template.duplicate(true)
		var actor: Node3D = template.node.duplicate(Node.DUPLICATE_SIGNALS|Node.DUPLICATE_GROUPS|Node.DUPLICATE_SCRIPTS)
		game.world.add_child(actor)
		actor.name = "EastHungryShark_" + str(index)
		actor.show()
		animal.caught = false
		animal.hp = 4
		animal.erase("fishing_target")
		var curve := Curve3D.new()
		for step in 13:
			var angle := float(step)*TAU/12
			var position := site + Vector3(sin(angle),0,cos(angle))*(9.0+index*.45)
			position.y = -1.3 - float(index%4)*.4
			curve.add_point(position)
		animal.node = actor
		animal.animator = actor.find_children("*","AnimationPlayer",true,false)[0]
		# Duplicating a playing AnimationPlayer does not copy its playback state.
		animal.animator.active = true
		game.wildlife._play(animal.animator, "ArmatureAction", float(index) / SHARK_COUNT)
		animal.animator.advance(0.0)
		animal.curve = curve
		animal.distance = float(index)/SHARK_COUNT*curve.get_baked_length()
		animal.destination = curve.sample_baked(animal.distance,true)
		actor.position = animal.destination
		animal.caught = false
		animal.adventure_control = true
		animal.quest_shark = true
		animal.quest_index = index
		animal.home = site
		animal.visit_timer = randf_range(12,30)
		animal.retreat_timer = 0.0
		sharks.append(animal)
		game.wildlife.fish.append(animal)
		game.predators.append(animal)
		if is_instance_valid(game.hunting):
			game.hunting.restore_animal(animal)

func mark_shark(animal: Dictionary) -> void:
	if animal.get("quest_shark", false) and not animal.quest_index in game.progress.buggy_quest.cleared:
		game.progress.buggy_quest.cleared.append(int(animal.quest_index))

func context() -> Dictionary:
	if treasure == null or game.has_good("quest_treasure") or game.progress.buggy_quest.status != "active":
		return {}
	if game.player.global_position.distance_to(treasure.global_position) < 2.3:
		return {"text":"E  打捞沉船宝藏" if remaining() == 0 else "E  查看被鲨群守住的宝藏"}
	return {}

func salvage() -> void:
	if context().is_empty():
		return
	if remaining() > 0:
		game.ui.notify("附近仍有%d只饥饿鲨鱼，先清理鲨群。" % remaining())
		return
	var before: Array = game.progress.goods.duplicate(true)
	game._add_good("quest_treasure","沉船宝藏",1)
	if not game.save():
		game.progress.goods = before
		return
	var tween := create_tween()
	tween.tween_property(treasure.find_child("LidPivot",true,false),"rotation:x",-1.3,.4)
	game.ui.notify("宝藏已经打捞，带回码头交给闻舟。",4.0)

func complete() -> void:
	if game.progress.buggy_quest.status != "active" or remaining() > 0 or not game.has_good("quest_treasure"):
		return
	var before: Dictionary = game.progress.duplicate(true)
	game.economy._consume("quest_treasure",1)
	game._add_good("beach_buggy","沙滩车",1)
	game.progress.buggy_quest.status = "complete"
	game.vehicle.unlock()
	if not game.save():
		game.progress.clear()
		game.progress.merge(before,true)
		return
	game.ui.notify("委托完成！沙滩车已经停在小屋外。",4.0)
	offer()
