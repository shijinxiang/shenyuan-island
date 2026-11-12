extends Node3D

const Utility = preload("res://scripts/core/island_static_setup.gd")
const MapView = preload("res://scripts/ui/island_map.gd")
var game: Node3D
var cabin: Node3D
var cabin_center := Vector3.ZERO
var south := Vector3.FORWARD
var east := Vector3.RIGHT
var map_data: Dictionary = {}
var bed: Node3D
var chest: Node3D
var lamp: Node3D
var lid: Node3D
var cabin_light: OmniLight3D
var portable_light: OmniLight3D
var chest_open := false
var lid_tween: Tween
var mini_map: Control
var map_panel: PanelContainer
var full_map: Control
var sleep_fade: ColorRect
var lamp_materials: Array[Dictionary] = []
var last_lamp_state := -1

func _ready() -> void:
	game = get_parent()
	for field in ["chest_goods", "chest_fish"]:
		if not game.progress.has(field):
			game.progress[field] = []
	if not game.progress.has("cabin_light"):
		game.progress.cabin_light = true
	cabin = game.world.get_node("Island").find_child("B01*", true, false)
	cabin_center = Utility.bounds(cabin).get_center()
	_setup_furniture()
	_build_map_data()
	_build_map_ui()
	sleep_fade = ColorRect.new()
	sleep_fade.color = Color(0, 0, 0, 0)
	sleep_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sleep_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	sleep_fade.hide()
	game.ui.add_child(sleep_fade)

func _place(path: String, point: Vector3, box_size := Vector3.ZERO) -> Node3D:
	var model: Node3D = load("res://assets/survival/" + path + ".glb").instantiate()
	add_child(model)
	model.global_position = cabin.to_global(point)
	model.rotation.y = cabin.global_rotation.y
	if box_size != Vector3.ZERO:
		var body := StaticBody3D.new()
		model.add_child(body)
		var collision := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = box_size
		collision.shape = box
		collision.position.y = box_size.y * .5
		body.add_child(collision)
		model.set_meta("interaction_body", body.get_rid())
	return model

func _setup_furniture() -> void:
	bed = _place("bed", Vector3(-2.4, .65, -1.55), Vector3(1.2, .5, 1.9))
	chest = _place("chest", Vector3(.1, .65, -2.25), Vector3(1.15, .55, .60))
	_place("bedside_table", Vector3(-1.4, .65, -2.15), Vector3(.55, .60, .55))
	lamp = _place("cabin_lamp", Vector3(-1.4, 1.25, -2.15))
	for mesh: MeshInstance3D in Utility.meshes(lamp):
		for surface in mesh.mesh.get_surface_count():
			var material := mesh.get_active_material(surface) as StandardMaterial3D
			if material != null and material.emission_enabled:
				var local := material.duplicate() as StandardMaterial3D
				mesh.set_surface_override_material(surface, local)
				lamp_materials.append({"material":local,"color":local.albedo_color})
	lid = chest.find_child("LidPivot", true, false)
	cabin_light = OmniLight3D.new()
	cabin_light.light_color = Color("ffd39a")
	cabin_light.light_energy = 2.0
	cabin_light.omni_range = 7.0
	cabin_light.shadow_enabled = true
	lamp.add_child(cabin_light)
	cabin_light.position = Vector3(0, .35, 0)
	portable_light = OmniLight3D.new()
	portable_light.light_color = Color("ffdca0")
	portable_light.omni_range = 6.0
	portable_light.light_energy = 1.4
	game.player.add_child(portable_light)
	portable_light.position.y = 1.1
	_update_lights()

func _update_lights() -> void:
	cabin_light.visible = bool(game.progress.cabin_light)
	var state := int(cabin_light.visible)
	if state != last_lamp_state:
		last_lamp_state = state
		for entry: Dictionary in lamp_materials:
			entry.material.emission_enabled = bool(state)
			entry.material.albedo_color = entry.color if state else Color("4f4639")
	portable_light.visible = game.has_good("lantern") and bool(game.progress.get("lantern_on", true))

func toggle_lamp(portable := false) -> void:
	var key := "lantern_on" if portable else "cabin_light"
	var previous: bool = bool(game.progress.get(key, true))
	game.progress[key] = not previous
	if not game.save():
		game.progress[key] = previous
		_update_lights()
		game.ui.notify("灯光状态没有保存，请再试一次。")
		return
	_update_lights()
	game.ui.notify("灯已经熄灭。" if bool(game.progress[key]) == false else "灯已经点亮。")

func context() -> Dictionary:
	if game.player.swimming or game.player.rowing.boarded or game.player.fishing_active or game.player.in_vehicle():
		return {}
	var point: Vector3 = game.player.global_position
	var local_point := cabin.to_local(point)
	if absf(local_point.x) > 3.1 or absf(local_point.z) > 2.6 or local_point.y < .25 or local_point.y > 1.7:
		return {}
	var choices := [{"kind":"bed","node":bed,"range":1.75,"text":"E  上床休息"}, {"kind":"chest","node":chest,"range":1.8,"text":"E  打开储物箱"}, {"kind":"lamp","node":lamp,"range":1.1,"text":"E  关掉屋内灯" if game.progress.cabin_light else "E  点亮屋内灯"}]
	var nearest := INF
	var result: Dictionary = {}
	for choice: Dictionary in choices:
		var offset: Vector3 = choice.node.global_position - point
		var distance := Vector2(offset.x, offset.z).length()
		if distance < float(choice.range) and distance < nearest and absf(offset.y) < 2.0:
			var excluded: Array[RID] = [game.player.get_rid()]
			if choice.node.has_meta("interaction_body"):
				excluded.append(choice.node.get_meta("interaction_body"))
			var query := PhysicsRayQueryParameters3D.create(point+Vector3.UP*1.2,choice.node.global_position+Vector3.UP*.3,1,excluded)
			if not get_world_3d().direct_space_state.intersect_ray(query).is_empty():
				continue
			nearest = distance
			result = choice
	return result

func interact(kind := "") -> void:
	var action: String = context().get("kind", "") if kind.is_empty() else kind
	match action:
		"bed": offer_sleep()
		"chest": open_chest()
		"lamp": toggle_lamp()

func offer_sleep() -> void:
	if game.weather.hour >= 6.0 and game.weather.hour < 19.0:
		game.ui.notify("天还亮着，等晚上再来休息。")
		return
	if game.progress.cabin_light or (game.has_good("lantern") and game.progress.get("lantern_on", true)):
		game.ui.notify("先关掉屋内灯和随身灯，再安心睡觉。")
		return
	game.ui.show_dialog("小屋的床", "睡到清晨，恢复伤势。屋外的作物会按每日浇水情况继续生长。", [{"text":"睡到早上七点","action":sleep_until_morning},{"text":"再待一会儿","action":game.ui.close_dialog}])

func sleep_until_morning() -> void:
	if game.cinematic_active or game.dead:
		return
	if game.weather.hour >= 6.0 and game.weather.hour < 19.0:
		game.ui.notify("现在已经是白天了。")
		return
	if game.progress.cabin_light or (game.has_good("lantern") and game.progress.get("lantern_on", true)):
		game.ui.notify("先把灯关掉。")
		return
	game.ui.close_dialog()
	game.player.interaction_time = 0
	game.cinematic_active = true
	sleep_fade.show()
	var fade := create_tween()
	fade.tween_property(sleep_fade, "color:a", 1.0, .35)
	await fade.finished
	if game.weather.hour >= 19.0:
		game.day_count += 1
	game.weather.hour = 7.0
	if is_instance_valid(game.nutrition):
		game.nutrition.account_sleep()
	game.weather.daylight = 1.0
	game.weather._update_environment(0.0)
	game.injuries = 0
	game.farming.update_days()
	game.save()
	await get_tree().create_timer(.35).timeout
	fade = create_tween()
	fade.tween_property(sleep_fade, "color:a", 0.0, .45)
	await fade.finished
	sleep_fade.hide()
	game.cinematic_active = false
	game.ui.notify("天亮了，记得照料耕地。")

func _set_chest_open(open: bool) -> void:
	chest_open = open
	if lid_tween and lid_tween.is_valid():
		lid_tween.kill()
	lid_tween = create_tween()
	lid_tween.tween_property(lid, "rotation:x", -1.3 if open else 0.0, .35)

func open_chest() -> void:
	game.ui.open_storage()
	_set_chest_open(true)

func close_chest() -> void:
	if chest_open:
		_set_chest_open(false)

func transfer(id: String, count: int, deposit: bool, fish: bool) -> bool:
	if not chest_open or count <= 0:
		return false
	if not fish and id in ["voyager", "beach_buggy"]:
		return false
	var before: Dictionary = game.progress.duplicate(true)
	var fish_before: Array = game.fishing.catches.duplicate(true)
	var source: Array
	var target: Array
	if fish:
		source = game.fishing.catches if deposit else game.progress.chest_fish
		target = game.progress.chest_fish if deposit else game.fishing.catches
	else:
		source = game.progress.goods if deposit else game.progress.chest_goods
		target = game.progress.chest_goods if deposit else game.progress.goods
	for item: Dictionary in source:
		if str(item.id) != id:
			continue
		if fish:
			source.erase(item)
			target.append(item)
		else:
			count = mini(count, int(item.count))
			if count <= 0:
				return false
			item.count = int(item.count) - count
			var found := false
			for stored: Dictionary in target:
				if stored.id == id:
					stored.count = int(stored.count) + count
					found = true
					break
			if not found:
				var copy := item.duplicate(true)
				copy.count = count
				target.append(copy)
		if not game.has_good(game.farming.selected_tool):
			game.progress.selected_tool = ""
		if not game.save():
			game.progress.clear()
			game.progress.merge(before, true)
			game.fishing.catches = fish_before
			game.ui.notify("这次移动没有保存，请再试一次。")
			return false
		if not game.has_good(game.farming.selected_tool):
			game.farming.selected_tool = ""
		if not game.has_good("harpoon"):
			game.harpoon_equipped = false
		return true
	return false

func map_coordinate(point: Vector3) -> Vector2:
	return Vector2(point.dot(east), point.dot(south))

func _build_map_data() -> void:
	var coast: Array = JSON.parse_string(FileAccess.get_file_as_string("res://assets/generated/outer_coast.json"))
	var lighthouse: Node3D = game.world.get_node("Island").find_child("B03*", true, false)
	var lighthouse_position := Utility.bounds(lighthouse).get_center()
	south = Vector3(lighthouse_position.x, 0, lighthouse_position.z).normalized()
	east = Vector3(south.z, 0, -south.x)
	var minimum := Vector2(INF, INF)
	var maximum := Vector2(-INF, -INF)
	for point: Array in coast:
		var coordinate := map_coordinate(Vector3(point[0], 0, point[1]))
		minimum = minimum.min(coordinate)
		maximum = maximum.max(coordinate)
	var bounds := Rect2(minimum - Vector2.ONE * 20, maximum - minimum + Vector2.ONE * 40)
	var cell := bounds.size / 40.0
	var density: Dictionary = {}
	for tree: Dictionary in game.farming.trees.values():
		var coordinate := map_coordinate(tree.position) - bounds.position
		var bin := Vector2i(floori(coordinate.x / cell.x), floori(coordinate.y / cell.y))
		density[bin] = int(density.get(bin, 0)) + 1
	var cells: Array = []
	for x in 40:
		for y in 40:
			var point := bounds.position + Vector2(x, y) * cell
			var center := point + cell * .5
			var world_point := east * center.x + south * center.y
			var height: float = game.wildlife.ground.height(world_point.x, world_point.z)
			var color := Color("3d7b88")
			if height > -.2:
				color = Color("d4c28e") if height < 1.5 else Color("8b9b60")
				if int(density.get(Vector2i(x, y), 0)) > 1:
					color = Color("476e4d")
				elif height > 10:
					color = Color("9a9a7b")
			cells.append({"point":point,"color":color})
	var ocean: MeshInstance3D = game.world.find_child("W02*", true, false)
	var ocean_bounds: AABB = ocean.global_transform * ocean.get_aabb()
	var world_minimum := Vector2(INF, INF)
	var world_maximum := Vector2(-INF, -INF)
	for x in [ocean_bounds.position.x, ocean_bounds.end.x]:
		for z in [ocean_bounds.position.z, ocean_bounds.end.z]:
			var coordinate := map_coordinate(Vector3(x, 0, z))
			world_minimum = world_minimum.min(coordinate)
			world_maximum = world_maximum.max(coordinate)
	var world_bounds := Rect2(world_minimum, world_maximum-world_minimum)
	map_data = {"bounds":world_bounds,"island_bounds":bounds,"cell_size":cell,"cells":cells,"buildings":[{"name":"小屋","position":cabin_center},{"name":"灯塔 · 南","position":lighthouse_position},{"name":"码头","position":game.merchant.global_position}]}

func _build_map_ui() -> void:
	mini_map = MapView.new()
	game.ui.add_child(mini_map)
	mini_map.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	mini_map.offset_left = -220
	mini_map.offset_right = -20
	mini_map.offset_top = 80
	mini_map.offset_bottom = 270
	mini_map.setup(self, false)
	mini_map.tooltip_text = "滚轮缩放 · 左键拖动 · 单击或按 M 打开大地图"
	map_panel = game.ui.centered_panel(Vector2(1080, 640))
	var column := VBoxContainer.new()
	map_panel.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	var title := Label.new()
	title.text = "深渊岛 · 航行图"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	header.add_child(game.ui.button("－", func(): full_map.change_zoom(1.0 / 1.2)))
	header.add_child(game.ui.button("＋", func(): full_map.change_zoom(1.2)))
	header.add_child(game.ui.button("收起地图  M", toggle_map))
	full_map = MapView.new()
	full_map.custom_minimum_size = Vector2(900, 480)
	full_map.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(full_map)
	full_map.setup(self, true)

func map_open() -> bool:
	return map_panel != null and map_panel.visible

func hide_map() -> void:
	if map_panel:
		map_panel.hide()

func toggle_map() -> void:
	if game.cinematic_active or game.dead:
		return
	if is_instance_valid(game.nutrition):
		game.nutrition.close_cooking()
	if map_panel.visible:
		map_panel.hide()
	else:
		game.fishing.set_active(false)
		game.ui.close_storage()
		game.ui.bag.hide()
		game.ui.settings.hide()
		game.ui.close_dialog()
		map_panel.show()
	game.player.controls_locked = game.ui.modal_open()

func _process(_delta: float) -> void:
	_update_lights()
	mini_map.visible = not game.cinematic_active and not game.dead and not map_open() and not game.ui.modal_open()
