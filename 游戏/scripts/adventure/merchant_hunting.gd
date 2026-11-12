extends Node
var game: Node3D

func _ready() -> void:
	game = get_parent().game
	if not game.progress.has("hunting_quest"):
		game.progress.hunting_quest = {"started":false,"stage":0,"kills_start":0}

func offer() -> void:
	var record: Dictionary = game.progress.hunting_quest
	var stage := int(record.stage)
	if stage >= 3:
		game.ui.show_dialog("闻舟 · 猎枪与弹药", "猎枪已经交给你了。每次只装一发，熟练后装填会更快。子弹只能从我的船货中购买，木箭可以用木材制作。", [{"text":"购买狩猎物资","action":func():game.economy.open_shop("狩猎装备")},{"text":"返回","action":game.open_merchant}])
		return
	var titles := ["营地的第一锅饭", "守岸的练习", "可靠的猎人"]
	var texts := ["带来8份木材和3份亲手做的菜，证明你能照料营地。", "使用弓箭或鱼叉击败3只野生动物，学会观察距离和追踪受伤猎物。", "带来2份鳄鱼肉、6份任意蔬菜和12份木材，为西岸的巡守备好物资。完成后，单发猎枪就归你。"]
	var options: Array = []
	if not record.started:
		options.append({"text":"接下这一系列委托","action":accept})
	else:
		var text: String = texts[stage]
		text += "\n\n当前进度  " + progress_text(stage)
		texts[stage] = text
		options.append({"text":"交付这一阶段","disabled":not stage_ready(stage),"action":complete_stage})
	options.append({"text":"购买弓箭和弹药","action":func():game.economy.open_shop("狩猎装备")})
	options.append({"text":"返回交谈","action":game.open_merchant})
	game.ui.show_dialog("闻舟 · " + titles[stage], texts[stage], options)

func cooked_count() -> int:
	var count := 0
	for item: Dictionary in game.progress.goods:
		if str(item.id).begins_with("dish_") or str(item.id).begins_with("delicious_dish_"):
			count += maxi(0, int(item.count))
	return count

func stage_ready(stage: int) -> bool:
	match stage:
		0:return game.economy.quantity("wood") >= 8 and cooked_count() >= 3
		1:return int(game.progress.hunting_stats.get("kills", 0)) - int(game.progress.hunting_quest.kills_start) >= 3
		2:return game.economy.quantity("wood") >= 12 and game.economy.quantity("crocodile_meat") >= 2 and game.nutrition.ingredient_count("vegetable") >= 6
	return false

func progress_text(stage: int) -> String:
	match stage:
		0:return "木材 %d/8，菜肴 %d/3" % [game.economy.quantity("wood"),cooked_count()]
		1:return "野生动物 %d/3" % maxi(0, int(game.progress.hunting_stats.get("kills",0)) - int(game.progress.hunting_quest.kills_start))
		2:return "鳄鱼肉 %d/2，蔬菜 %d/6，木材 %d/12" % [game.economy.quantity("crocodile_meat"),game.nutrition.ingredient_count("vegetable"),game.economy.quantity("wood")]
	return ""

func accept() -> void:
	var before: Dictionary = game.progress.duplicate(true)
	game.progress.hunting_quest.started = true
	game.progress.hunting_quest.kills_start = int(game.progress.hunting_stats.get("kills",0))
	if not game.save():
		game.restore_progress(before)
		return
	offer()

func complete_stage() -> void:
	var record: Dictionary = game.progress.hunting_quest
	var stage := int(record.stage)
	if not game.merchant_available or not record.started or stage >= 3 or not stage_ready(stage):
		return
	var before: Dictionary = game.progress.duplicate(true)
	if stage == 0:
		game.economy._consume("wood",8)
		var remaining := 3
		for item: Dictionary in game.progress.goods:
			if str(item.id).begins_with("dish_") or str(item.id).begins_with("delicious_dish_"):
				var used := mini(remaining, maxi(0, int(item.count)))
				item.count = int(item.count) - used
				remaining -= used
	elif stage == 2:
		game.economy._consume("wood",12)
		game.economy._consume("crocodile_meat",2)
		var remaining := 6
		for id in ["crop_turnip","crop_tomato","crop_pumpkin"]:
			var used := mini(remaining,game.economy.quantity(id))
			game.economy._consume(id,used)
			remaining -= used
		if not game.has_good("hunting_rifle"):
			game._add_good("hunting_rifle","单发猎枪",1)
	record.stage = stage + 1
	if not game.save():
		game.restore_progress(before)
		return
	game.ui.notify("猎枪已获得。向闻舟购买子弹后可装备使用。" if stage == 2 else "这一阶段已完成。")
	offer()
