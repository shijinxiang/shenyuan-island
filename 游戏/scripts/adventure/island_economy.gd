extends RefCounted

const CATALOG := [
	{"id":"skinning_knife","name":"剥皮小刀","count":1,"category":"狩猎装备","costs":[{"fish":6,"wood":3},{"crop_turnip":8,"wood":3}]},
	{"id":"bow","name":"木弓","count":1,"category":"狩猎装备","costs":[{"fish":12,"wood":6},{"crop_turnip":12,"wood":8}]},
	{"id":"wooden_arrow","name":"木箭","count":6,"category":"狩猎装备","costs":[{"fish":3},{"crop_turnip":4}]},
	{"id":"rifle_ammo","name":"猎枪弹","count":5,"category":"狩猎装备","costs":[{"fish":6},{"crop_tomato":8,"crop_turnip":4}]},
	{"id":"seed_turnip","name":"萝卜种子","count":3,"category":"种子","costs":[{"fish":1},{"crop_turnip":2}]},
	{"id":"seed_tomato","name":"番茄种子","count":3,"category":"种子","costs":[{"fish":2},{"crop_turnip":3}]},
	{"id":"seed_pumpkin","name":"南瓜种子","count":2,"category":"种子","costs":[{"fish":3},{"crop_tomato":2}]},
	{"id":"axe","name":"斧头","count":1,"category":"农具","costs":[{"fish":8},{"crop_turnip":10}]},
	{"id":"hoe","name":"锄头","count":1,"category":"农具","costs":[{"fish":6},{"crop_turnip":8}]},
	{"id":"watering_can","name":"浇水壶","count":1,"category":"农具","costs":[{"fish":4},{"crop_tomato":6}]},
	{"id":"axe_steel","name":"钢制斧头","count":1,"category":"农具","costs":[{"fish":20,"wood":12,"crop_tomato":6}]},
	{"id":"hoe_steel","name":"钢制锄头","count":1,"category":"农具","costs":[{"fish":16,"wood":10,"crop_turnip":8}]},
	{"id":"watering_can_large","name":"大号浇水壶","count":1,"category":"农具","costs":[{"fish":14,"wood":6,"crop_tomato":8}]},
	{"id":"rod_improved","name":"加强鱼竿","count":1,"category":"钓具与船","costs":[{"fish":24,"wood":6,"crop_turnip":12}]},
	{"id":"rod_master","name":"精工鱼竿","count":1,"category":"钓具与船","costs":[{"fish":45,"wood":20,"crop_pumpkin":12,"crop_tomato":18}]},
	{"id":"harpoon","name":"三齿鱼叉","count":1,"category":"钓具与船","costs":[{"fish":25,"crop_turnip":10}]},
	{"id":"harpoon_steel","name":"钢制鱼叉","count":1,"category":"钓具与船","costs":[{"fish":32,"wood":12,"crop_pumpkin":8}]},
	{"id":"voyager","name":"远航木船","count":1,"category":"钓具与船","costs":[{"fish":60,"wood":25,"crop_pumpkin":12}]},
	{"id":"meal","name":"旅行干粮","count":2,"category":"生活补给","costs":[{"fish":3},{"crop_turnip":3,"crop_tomato":1},{"crocodile_meat":1}]},
	{"id":"medical_kit","name":"急救包","count":1,"category":"生活补给","costs":[{"fish":6,"crop_tomato":3},{"crop_pumpkin":3,"crop_tomato":5}]},
	{"id":"boots","name":"耐用行走靴","count":1,"category":"生活补给","costs":[{"fish":14,"crop_turnip":6}]},
	{"id":"life_jacket","name":"轻便救生衣","count":1,"category":"生活补给","costs":[{"fish":18,"crop_pumpkin":4}]},
	{"id":"lantern","name":"便携暖灯","count":1,"category":"生活补给","costs":[{"fish":10,"wood":6},{"crop_pumpkin":5,"wood":6}]}
]
const RESOURCE_NAMES := {"fish":"鱼获","wood":"木材","crop_turnip":"萝卜","crop_tomato":"番茄","crop_pumpkin":"南瓜","crocodile_meat":"鳄鱼肉"}
const CONSUMABLES := ["meal", "medical_kit"]
const DESCRIPTIONS := {
	"skinning_knife":"随身携带后，靠近倒下的猎物按 E 处理尸体，可切出烹饪用的肉。处理时会自动取出小刀。",
	"axe_steel":"更锋利的斧刃，砍倒树木所需次数减少一次。与伐木等级的效果叠加。",
	"hoe_steel":"能开垦稍陡的地面，锄地动作间隔缩短。耕地仍需要留出安全空间。",
	"watering_can_large":"一次浇水会润湿目标及附近2.6米内的耕地。",
	"rod_improved":"鱼更容易咬钩，收线更快，张力增长更慢。购买后钓鱼时自动使用。",
	"rod_master":"比加强鱼竿进一步提高咬钩概率、收线效率和稳定性。购买后自动使用。",
	"harpoon_steel":"更强的鱼叉，可捕捉小型猎物、抵御鲨鱼和鳄鱼，攻击伤害提高。",
	"meal":"恢复24点饱食度，并恢复一处伤势。",
	"medical_kit":"恢复全部伤势，并提供短暂的受伤保护。",
	"boots":"在陆地上步行和奔跑的速度提高10%，购买后自动穿戴。",
	"life_jacket":"游泳速度提高20%，购买后自动穿戴。",
	"lantern":"夜间照明。可在背包里开启或关闭，睡觉前也要关掉。"
}
var game: Node3D

func _init(parent: Node3D) -> void:
	game = parent

func unique(id: String) -> bool:
	return not id.begins_with("seed_") and not id.begins_with("dish_") and not id.begins_with("delicious_dish_") and id not in CONSUMABLES and id not in ["wooden_arrow","rifle_ammo","wild_berry","wild_mushroom","animal_meat","fish_meat","shark_meat","crocodile_meat"]

func quantity(id: String) -> int:
	if id == "fish":
		return game.fishing.catches.size()
	var total := 0
	for item: Dictionary in game.progress.goods:
		if item.id == id:
			total += maxi(0, int(item.count))
	return total

func can_pay(cost: Dictionary) -> bool:
	for id: String in cost:
		if quantity(id) < int(cost[id]):
			return false
	return true

func cost_text(cost: Dictionary) -> String:
	var parts: PackedStringArray = []
	for id: String in cost:
		parts.append(str(RESOURCE_NAMES.get(id, id)) + "×" + str(cost[id]))
	return " + ".join(parts)

func open_shop(category := "") -> void:
	if not game.merchant_available:
		return
	game._talk()
	var options: Array = []
	if category.is_empty():
		for title in ["种子", "农具", "钓具与船", "狩猎装备", "生活补给"]:
			var selected: String = title
			options.append({"text": selected, "action": func(): open_shop(selected)})
		options.append({"text":"返回交谈","action":game.open_merchant})
		game.ui.show_dialog("闻舟的船货", "鱼获、农产品和木材都能用来交换。高级工具和船需要几种物资一起准备。", options)
		return
	for product: Dictionary in CATALOG:
		if product.category != category:
			continue
		var selected: Dictionary = product
		var owned: bool = unique(str(product.id)) and game.has_good(str(product.id))
		options.append({"text": ("已拥有 · " if owned else "") + str(product.name) + " ×" + str(product.count), "action":func(): show_product(selected)})
	options.append({"text":"返回商品分类","action":func():open_shop()})
	game.ui.show_dialog("闻舟 · " + category, "选择商品查看效果和交换条件。", options)

func show_product(product: Dictionary) -> void:
	var owned: bool = unique(str(product.id)) and game.has_good(str(product.id))
	var options: Array = []
	for index in product.costs.size():
		var selected_index: int = index
		var cost: Dictionary = product.costs[index]
		options.append({"text": "交换 · " + cost_text(cost), "disabled": owned or not can_pay(cost), "action":func():trade(product, selected_index)})
	options.append({"text":"返回","action":func():open_shop(str(product.category))})
	var description: String = DESCRIPTIONS.get(product.id, game.item_description(product))
	game.ui.show_dialog(str(product.name) + (" · 已拥有" if owned else ""), description + "\n\n较轻的鱼获会优先用于交换。", options)

func _consume(id: String, count: int) -> void:
	if id == "fish":
		game.fishing.catches.sort_custom(func(a, b): return float(a.weight_kg) < float(b.weight_kg))
		for index in count:
			game.fishing.catches.pop_front()
		return
	for item: Dictionary in game.progress.goods:
		if item.id == id:
			var used := mini(count, int(item.count))
			item.count = int(item.count) - used
			count -= used
			if count == 0:
				break

func trade(product: Dictionary, option := 0) -> void:
	if not game.merchant_available or option < 0 or option >= product.costs.size():
		return
	if unique(str(product.id)) and game.has_good(str(product.id)):
		return
	var cost: Dictionary = product.costs[option]
	if not can_pay(cost):
		game.ui.notify("交换所需的物资还不够。")
		return
	var goods_before: Array = game.progress.goods.duplicate(true)
	var fish_before: Array = game.fishing.catches.duplicate(true)
	for id: String in cost:
		_consume(id, int(cost[id]))
	game._add_good(str(product.id), str(product.name), int(product.count))
	if not game.save():
		game.progress.goods = goods_before
		game.fishing.catches = fish_before
		game.ui.notify("这次交换没有保存，请稍后再试。")
		return
	if product.id == "voyager":
		game.player.rowing.apply_upgrade()
	game.ui.notify("换到了" + str(product.name))
	game.ui.refresh_bag()
	show_product(product)

func consume_item(id: String) -> void:
	if id not in CONSUMABLES or quantity(id) <= 0:
		return
	if game.injuries == 0:
		game.ui.notify("现在身体健康，先把补给留好。")
		return
	var old_goods: Array = game.progress.goods.duplicate(true)
	var old_injuries: int = game.injuries
	_consume(id, 1)
	game.injuries = 0 if id == "medical_kit" else maxi(0, game.injuries - 1)
	if not game.save():
		game.progress.goods = old_goods
		game.injuries = old_injuries
		game.ui.notify("这次使用没有保存，请稍后再试。")
		return
	game.hit_cooldown = 6.0
	game.ui.notify("使用了补给，伤势有所恢复。")
