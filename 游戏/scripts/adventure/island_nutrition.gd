extends Node3D

const FOOD_NAMES := {"wild_berry":"野果", "wild_mushroom":"可食蘑菇", "animal_meat":"野味肉", "fish_meat":"鱼肉", "shark_meat":"鲨鱼肉", "crocodile_meat":"鳄鱼肉"}
const RECIPES := {
	"fish":{"name":"香煎鱼", "cost":{"fish":1}, "hunger":28},
	"vegetables":{"name":"田园炖菜", "cost":{"vegetable":2}, "hunger":25},
	"fish_stew":{"name":"鱼蔬鲜汤", "cost":{"fish":1,"vegetable":2}, "hunger":48},
	"mushroom":{"name":"蘑菇汤", "cost":{"wild_mushroom":2}, "hunger":26},
	"fruit":{"name":"野果甜煮", "cost":{"wild_berry":3}, "hunger":24},
	"forest":{"name":"林间杂烩", "cost":{"wild_berry":2,"wild_mushroom":1,"vegetable":1}, "hunger":38},
	"meat":{"name":"猎人炖肉", "cost":{"meat":1,"wild_mushroom":1,"vegetable":1}, "hunger":52}
}
var game: Node3D
var hunger := 100.0
var pot: Node3D
var fire: Node3D
var forage: Array[Dictionary] = []
var cooking := false
var ui_panel: PanelContainer
var recipe_list: VBoxContainer
var result_text: RichTextLabel
var hunger_label: Label
var hunger_bar: ProgressBar
var overlay: ColorRect
var stars: Control
var clock_stamp := 0.0
var forage_timer := 0.0
var cooking_generation := 0

func _ready() -> void:
	game = get_parent()
	hunger = clampf(float(game.progress.get("hunger", 100.0)), 0, 100)
	game.progress.hunger = hunger
	if not game.progress.has("forage_days"):
		game.progress.forage_days = {}
	clock_stamp = game.day_count * 24.0 + game.weather.hour
	_setup_pot()
	_setup_forage()
	_setup_ui()

func is_food(id: String) -> bool:
	return id.begins_with("dish_") or id.begins_with("delicious_dish_") or id in ["wild_berry", "meal"]

func recipe_key(id: String) -> String:
	return id.trim_prefix("delicious_").trim_prefix("dish_")

func food_value(id: String) -> int:
	if id == "wild_berry":
		return 7
	if id == "meal":
		return 24
	var recipe: Dictionary = RECIPES.get(recipe_key(id), {})
	return roundi(float(recipe.get("hunger", 0)) * (1.5 if id.begins_with("delicious_") else 1.0))

func item_model(id: String) -> Node3D:
	var model := "meal_bowl"
	if id == "wild_berry":
		model = "berry"
	elif id == "wild_mushroom":
		model = "mushroom"
	elif id in ["animal_meat", "fish_meat", "shark_meat", "crocodile_meat"]:
		model = "meat"
	return load("res://assets/cooking/" + model + ".glb").instantiate()

func description(id: String) -> String:
	if is_food(id):
		return "食用恢复%d点饱食度。%s" % [food_value(id), "烹饪技艺提升后更容易做出美味菜肴。" if id.begins_with("delicious_") else "可在背包中食用。"]
	return "在小屋门口的大锅中与鱼获或农产品一起处理烹饪。"

func speed_multiplier() -> float:
	return lerpf(.58, 1.0, clampf(hunger / 20.0, 0, 1))

func _setup_pot() -> void:
	pot = load("res://assets/cooking/cooking_pot.glb").instantiate()
	add_child(pot)
	var cabin: Node3D = game.survival.cabin
	for offset in [Vector3(-4.6,0,3.8),Vector3(4.6,0,3.8),Vector3(-4.6,0,-3.8)]:
		var point := cabin.to_global(offset)
		point.y = game.wildlife.ground.height(point.x, point.z)
		if is_instance_valid(game.vehicle) and game.vehicle.visible and point.distance_to(game.vehicle.global_position) < 1.8:
			continue
		if point.y > .3:
			pot.global_position = point
			break
	var body := StaticBody3D.new()
	pot.add_child(body)
	var collision := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = .48
	shape.height = 1.05
	collision.shape = shape
	collision.position.y = .525
	body.add_child(collision)
	pot.set_meta("interaction_body", body.get_rid())
	fire = pot.find_child("Flame", true, false)
	if fire:
		fire.hide()
	game.survival.map_data.buildings.append({"name":"烹饪锅","position":pot.global_position})

func _setup_forage() -> void:
	var index := 0
	for tree: Dictionary in game.farming.trees.values():
		index += 1
		if index % 27 != 0 or forage.size() >= 40:
			continue
		var point: Vector3 = tree.position + Vector3(sin(index), 0, cos(index)) * 1.9
		point.y = game.wildlife.ground.height(point.x, point.z)
		if point.y < 1.6 or point.distance_to(game.survival.cabin_center) < 8:
			continue
		if absf(game.wildlife.ground.height(point.x + .6, point.z) - point.y) > .4:
			continue
		var berries := forage.size() % 2 == 0
		var node: Node3D = load("res://assets/cooking/" + ("berry_bush" if berries else "mushrooms") + ".glb").instantiate()
		add_child(node)
		node.global_position = point
		node.rotation.y = index * 1.31
		var harvest := node.find_child("Berries" if berries else "Harvest", true, false) as Node3D
		forage.append({"id":"forage_" + str(index),"node":node,"harvest":harvest,"item":"wild_berry" if berries else "wild_mushroom","days":2 if berries else 1})
	_update_forage()

func _update_forage() -> void:
	for entry: Dictionary in forage:
		var available: bool = game.day_count - int(game.progress.forage_days.get(entry.id, -100)) >= int(entry.days)
		entry.harvest.visible = available

func _clear_path(point: Vector3, excluded: Array[RID]) -> bool:
	var origin: Vector3 = game.player.global_position + Vector3.UP
	var query := PhysicsRayQueryParameters3D.create(origin, point, 1, excluded)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func context() -> Dictionary:
	if game.player.swimming or game.player.in_vehicle() or game.player.rowing.boarded:
		return {}
	var point: Vector3 = game.player.global_position
	if point.distance_to(pot.global_position) < 2.1 and _clear_path(pot.global_position + Vector3.UP * .7, [game.player.get_rid(),pot.get_meta("interaction_body")]):
		return {"kind":"cook","text":"E  使用门口的大锅烹饪"}
	for entry: Dictionary in forage:
		if entry.harvest.visible and point.distance_to(entry.node.global_position) < 1.8 and _clear_path(entry.node.global_position + Vector3.UP * .5, [game.player.get_rid()]):
			return {"kind":"forage","entry":entry,"text":"E  采摘" + str(FOOD_NAMES[entry.item])}
	return {}

func interact(target: Dictionary = {}) -> void:
	if target.is_empty():
		target = context()
	if target.get("kind", "") == "cook":
		open_cooking()
	elif target.has("entry"):
		var entry: Dictionary = target.entry
		if not entry.harvest.visible:
			return
		var before: Dictionary = game.progress.duplicate(true)
		game._add_good(entry.item, FOOD_NAMES[entry.item], 2)
		game.progress.forage_days[entry.id] = game.day_count
		if not game.save():
			_restore_progress(before)
			return
		entry.harvest.hide()
		game.player.interaction_time = .8
		game.player.interaction_clip = "Harvest"
		game.player.interaction_rate = game.player.animation.get_animation("Harvest").length / .8
		game.ui.notify("采到了" + str(FOOD_NAMES[entry.item]) + "×2。")

func _ingredient_ids(id: String) -> Array:
	if id == "fish":
		return ["fish", "fish_meat"]
	if id == "vegetable":
		return ["crop_turnip", "crop_tomato", "crop_pumpkin"]
	if id == "meat":
		return ["animal_meat", "shark_meat", "crocodile_meat"]
	return [id]

func ingredient_count(id: String) -> int:
	var count := 0
	for candidate: String in _ingredient_ids(id):
		count += game.economy.quantity(candidate)
	return count

func can_cook(key: String) -> bool:
	if not RECIPES.has(key):
		return false
	for id: String in RECIPES[key].cost:
		if ingredient_count(id) < int(RECIPES[key].cost[id]):
			return false
	return true

func _restore_progress(before: Dictionary) -> void:
	game.restore_progress(before)

func cook(key: String) -> void:
	if cooking or not ui_panel.visible or not can_cook(key) or game.player.global_position.distance_to(pot.global_position) > 2.4:
		return
	cooking = true
	cooking_generation += 1
	var generation := cooking_generation
	_refresh_recipes()
	if fire:
		fire.show()
	result_text.text = "正在切配、煮制……"
	await get_tree().create_timer(2.2).timeout
	if generation != cooking_generation:
		return
	if not ui_panel.visible or game.dead or game.cinematic_active or game.player.global_position.distance_to(pot.global_position) > 2.4 or not can_cook(key):
		_finish_cooking()
		return
	var before: Dictionary = game.progress.duplicate(true)
	var fish_before: Array = game.fishing.catches.duplicate(true)
	for ingredient: String in RECIPES[key].cost:
		var needed := int(RECIPES[key].cost[ingredient])
		for id: String in _ingredient_ids(ingredient):
			var used := mini(needed, game.economy.quantity(id))
			game.economy._consume(id, used)
			needed -= used
	var delicious: bool = randf() < game.skills.delicious_chance()
	var id := ("delicious_" if delicious else "") + "dish_" + key
	var name := ("美味的" if delicious else "") + str(RECIPES[key].name)
	game._add_good(id, name, 1)
	game.skills.add_xp("cooking", 10)
	var saved: bool = game.save()
	if not saved:
		_restore_progress(before)
		game.fishing.catches = fish_before
	_finish_cooking()
	result_text.text = ("做出了 " + display_name(id, name) + "\n恢复%d点饱食度，已放入背包。" % food_value(id)) if saved else "本次烹饪未能保存，食材已恢复。"

static func display_name(id: String, name: String) -> String:
	return "[rainbow freq=0.5 sat=0.75 val=0.9]美味的[/rainbow]" + name.trim_prefix("美味的") if id.begins_with("delicious_") else name

func _finish_cooking() -> void:
	cooking = false
	if fire:
		fire.hide()
	_refresh_recipes()

func eat(id: String) -> void:
	if not is_food(id) or game.economy.quantity(id) < 1 or game.dead:
		return
	if hunger >= 99.5 and id == "meal" and game.injuries > 0:
		game.economy.consume_item(id)
		return
	if hunger >= 99.5:
		game.ui.notify("已经吃饱了。")
		return
	var before: Dictionary = game.progress.duplicate(true)
	var previous := hunger
	var old_injuries: int = game.injuries
	game.economy._consume(id, 1)
	if id == "meal":
		game.injuries = maxi(0, game.injuries - 1)
	hunger = minf(100, hunger + food_value(id))
	game.progress.hunger = hunger
	if not game.save():
		_restore_progress(before)
		hunger = previous
		game.injuries = old_injuries
		return
	game.ui.notify("吃过东西，恢复了%d点饱食度。" % roundi(hunger - previous))

func _setup_ui() -> void:
	ui_panel = game.ui.centered_panel(Vector2(880, 620))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	ui_panel.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	var title := Label.new()
	title.text = "小屋的大锅"
	title.add_theme_font_size_override("font_size", 26)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	header.add_child(game.ui.button("收起  Esc", close_cooking))
	var note := Label.new()
	note.text = "鱼、农产品和林间食材都可以入锅。美味菜肴额外恢复50%饱食度。"
	column.add_child(note)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	recipe_list = VBoxContainer.new()
	recipe_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(recipe_list)
	result_text = RichTextLabel.new()
	result_text.bbcode_enabled = true
	result_text.custom_minimum_size.y = 72
	column.add_child(result_text)
	var status := PanelContainer.new()
	status.theme = game.ui.theme_pack
	status.add_theme_stylebox_override("panel", game.ui.box(Color("31665e"), 12))
	status.position = Vector2(20, 104)
	status.custom_minimum_size = Vector2(192, 54)
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game.ui.add_child(status)
	var content := VBoxContainer.new()
	status.add_child(content)
	hunger_label = Label.new()
	hunger_label.add_theme_color_override("font_color", Color("fff0ce"))
	content.add_child(hunger_label)
	hunger_bar = ProgressBar.new()
	hunger_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hunger_bar.show_percentage = false
	hunger_bar.custom_minimum_size.y = 8
	content.add_child(hunger_bar)
	overlay = ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/hunger_effect.gdshader")
	overlay.material = material
	var canvas := CanvasLayer.new()
	canvas.layer = 15
	add_child(canvas)
	canvas.add_child(overlay)
	stars = preload("res://scripts/ui/dizzy_stars.gd").new()
	stars.nutrition = self
	canvas.add_child(stars)

func open_cooking() -> void:
	game.ui.close_storage()
	game.ui.close_dialog()
	game.ui.bag.hide()
	game.ui.settings.hide()
	game.survival.hide_map()
	if game.player.fishing_active:
		game.fishing.set_active(false)
	ui_panel.show()
	game.player.controls_locked = true
	result_text.text = "选择食谱，制作后在背包中食用。"
	_refresh_recipes()

func close_cooking() -> void:
	ui_panel.hide()
	cooking_generation += 1
	cooking = false
	if fire:
		fire.hide()

func account_sleep() -> void:
	var now: float = game.day_count * 24.0 + game.weather.hour
	hunger = maxf(0, hunger - maxf(0, now - clock_stamp) * 3.2)
	clock_stamp = now
	game.progress.hunger = hunger

func _refresh_recipes() -> void:
	for child in recipe_list.get_children():
		recipe_list.remove_child(child)
		child.queue_free()
	var names := {"fish":"鱼获", "vegetable":"任意蔬菜", "meat":"任意肉", "wild_berry":"野果", "wild_mushroom":"蘑菇"}
	for key: String in RECIPES:
		var recipe: Dictionary = RECIPES[key]
		var parts: PackedStringArray = []
		for id: String in recipe.cost:
			parts.append("%s%d/%d" % [names[id], ingredient_count(id), recipe.cost[id]])
		var chosen := key
		var button: Button = game.ui.button("%s  ·  %s  ·  恢复%d" % [recipe.name, " + ".join(parts), recipe.hunger], func():cook(chosen))
		button.disabled = cooking or not can_cook(key)
		recipe_list.add_child(button)

func _process(delta: float) -> void:
	var now: float = game.day_count * 24.0 + game.weather.hour
	var passed := maxf(0, now - clock_stamp)
	clock_stamp = now
	if not game.cinematic_active and not game.dead:
		hunger = maxf(0, hunger - minf(passed, 24) * 3.2 * (1.25 if game.player.planar_speed > 2.0 else 1.0))
		game.progress.hunger = hunger
	hunger_label.text = "饱食度  %d / 100" % roundi(hunger)
	hunger_bar.value = hunger
	hunger_label.get_parent().get_parent().visible = not game.cinematic_active and not game.dead and not game.ui.modal_open()
	overlay.material.set_shader_parameter("severity", clampf((20 - hunger) / 20, 0, 1) if not game.cinematic_active and not game.dead else 0.0)
	forage_timer -= delta
	if forage_timer <= 0:
		forage_timer = 1.0
		_update_forage()
	if ui_panel.visible and (game.dead or game.cinematic_active or game.player.global_position.distance_to(pot.global_position) > 2.6):
		close_cooking()
