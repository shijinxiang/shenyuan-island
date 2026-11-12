extends Node

const NAMES := {"fishing": "钓鱼", "farming": "耕作", "sailing": "航海", "woodcutting": "伐木", "hunting":"狩猎", "cooking":"烹饪"}
const MAX_LEVEL := 8
var game: Node3D
var last_boat_position := Vector3.ZERO
var sailing_distance := 0.0

func _ready() -> void:
	game = get_parent()
	if not game.progress.has("skills"):
		game.progress.skills = {}
	for id: String in NAMES:
		if not game.progress.skills.has(id):
			game.progress.skills[id] = {"level": 1, "xp": 0}
	last_boat_position = game.player.rowing.global_position

func level(id: String) -> int:
	return clampi(int(game.progress.skills[id].level), 1, MAX_LEVEL)

func needed(id: String) -> int:
	return 18 + (level(id) - 1) * 12

func add_xp(id: String, amount: int) -> void:
	var record: Dictionary = game.progress.skills[id]
	if level(id) >= MAX_LEVEL:
		return
	var previous := level(id)
	record.xp = int(record.xp) + amount
	while level(id) < MAX_LEVEL and int(record.xp) >= needed(id):
		record.xp = int(record.xp) - needed(id)
		record.level = level(id) + 1
	if level(id) == MAX_LEVEL:
		record.xp = 0
	if level(id) > previous:
		game.ui.notify("%s技艺有所提升，可在人物面板查看。" % NAMES[id], 3.0)

func rod_tier() -> int:
	if game.has_good("rod_master"):
		return 2
	return 1 if game.has_good("rod_improved") else 0

func bite_chance() -> float:
	return minf(.96, .58 + (level("fishing") - 1) * .045 + rod_tier() * .10)

func tension_factor() -> float:
	return maxf(.48, 1.18 - (level("fishing") - 1) * .065 - rod_tier() * .13)

func reel_speed() -> float:
	return .17 + (level("fishing") - 1) * .014 + rod_tier() * .035

func bite_window() -> float:
	return 2.3 + (level("fishing") - 1) * .17 + rod_tier() * .25

func axe_hits() -> int:
	var reduction := 1 if level("woodcutting") >= 4 else 0
	if game.has_good("axe_steel"):
		reduction += 1
	return maxi(1, 3 - reduction)

func boat_multiplier() -> float:
	return 1.0 + (level("sailing") - 1) * .045

func harvest_count() -> int:
	return 2 if randf() < (level("farming") - 1) * .055 else 1

func reload_seconds() -> float:
	return lerpf(3.0, 1.5, float(level("hunting") - 1) / (MAX_LEVEL - 1))

func delicious_chance() -> float:
	return .08 + (level("cooking") - 1) * .085

func summary() -> String:
	var text := "[font_size=24]小爱[/font_size]\n伤势  %d / 4\n\n" % game.injuries
	for id: String in NAMES:
		var record: Dictionary = game.progress.skills[id]
		text += "%s  %d级  %s\n" % [NAMES[id], level(id), "已满级" if level(id) == MAX_LEVEL else "%d / %d经验" % [record.xp, needed(id)]]
	text += "\n钓鱼经验来自成功钓起鱼，升级后更容易咬钩、收线更快、脱钩风险更低。耕作经验来自播种、浇水与收获，有机会多收获一份。伐木升级减少砍倒树木的次数。航海经验来自实际驾船航行，升级提高航速。"
	text += "\n\n当前钓鱼咬钩率  %d%%\n航海速度加成  %d%%" % [roundi(bite_chance()*100),roundi((boat_multiplier()-1)*100)]
	text += "\n猎枪单发装填  %.2f秒\n烹饪美味概率  %d%%" % [reload_seconds(), roundi(delicious_chance() * 100)]
	if is_instance_valid(game.nutrition):
		text += "\n饱食度  %d / 100" % roundi(game.nutrition.hunger)
	return text

func show_skills() -> void:
	game.ui.open_character("skills")

func _physics_process(delta: float) -> void:
	var boat: Node3D = game.player.rowing
	var distance := boat.global_position.distance_to(last_boat_position)
	last_boat_position = boat.global_position
	if not boat.boarded or game.cinematic_active or game.player.controls_locked:
		return
	if distance > 15.0 * delta * 3.0 + 1.0:
		return
	sailing_distance += distance
	if sailing_distance >= 60.0:
		sailing_distance -= 60.0
		add_xp("sailing", 8)
