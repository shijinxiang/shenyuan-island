extends "res://scripts/ui/nautical_panel.gd"

signal close_requested

const Slot = preload("res://scripts/ui/storage_slot.gd")
const Preview = preload("res://scripts/ui/live_item_preview.gd")
const PAGE_SIZE := 6
const DRAG_KIND := "abyss_storage_item"
var game: Node3D
var ui: CanvasLayer
var panels: Dictionary = {}
var pages := {"bag": 0, "chest": 0}
var session := 0
var details: Label

func setup(controller: Node3D, interface: CanvasLayer) -> void:
	game = controller
	ui = interface
	theme = ui.theme_pack
	custom_minimum_size = Vector2(1160, 570)
	set_anchors_preset(Control.PRESET_CENTER)
	offset_left = -580
	offset_right = 580
	offset_top = -330
	offset_bottom = 240
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	var title := Label.new()
	title.text = "小屋储物箱"
	title.add_theme_font_size_override("font_size", 24)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	header.add_child(ui.button("收好物品  Esc", func(): close_requested.emit()))
	var sides := HBoxContainer.new()
	sides.add_theme_constant_override("separation", 18)
	sides.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(sides)
	_build_side(sides, "bag", "人物背包")
	_build_side(sides, "chest", "储物箱")
	details = Label.new()
	details.custom_minimum_size.y = 44
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(details)
	hide()

func _build_side(parent: HBoxContainer, side: String, title: String) -> void:
	var panel := Slot.new()
	panel.inventory_view = self
	panel.inventory_side = side
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", ui.box(Color("eee2c7"), 12))
	parent.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)
	var heading := Label.new()
	heading.text = title
	heading.add_theme_font_size_override("font_size", 20)
	column.add_child(heading)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	column.add_child(grid)
	var footer := HBoxContainer.new()
	column.add_child(footer)
	footer.add_child(ui.button("上一页", func(): change_page(side, -1)))
	var page := Label.new()
	page.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(page)
	footer.add_child(ui.button("下一页", func(): change_page(side, 1)))
	panels[side] = {"grid": grid, "heading": heading, "page": page, "title": title}

func open() -> void:
	session += 1
	refresh()
	details.text = "物品可拖到另一侧存取，Shift拖动一个。人物背包中的工具也可拖入下方装备栏。交通工具保留在人物背包。"
	show()

func invalidate_drag() -> void:
	session += 1

func entries(side: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var goods: Array = game.progress.goods if side == "bag" else game.progress.chest_goods
	var fish: Array = game.fishing.catches if side == "bag" else game.progress.chest_fish
	for item: Dictionary in fish:
		result.append(item)
	for item: Dictionary in goods:
		if int(item.count) > 0 and item.id not in ["voyager", "beach_buggy"]:
			result.append(item)
	return result

func refresh() -> void:
	for side: String in panels:
		var items := entries(side)
		var panel: Dictionary = panels[side]
		pages[side] = clampi(int(pages[side]), 0, maxi(0, (items.size() - 1) / PAGE_SIZE))
		panel.heading.text = "%s · %d项" % [panel.title, items.size()]
		panel.page.text = "%d / %d" % [int(pages[side]) + 1, maxi(1, ceili(items.size() / float(PAGE_SIZE)))]
		for child: Node in panel.grid.get_children():
			panel.grid.remove_child(child)
			child.queue_free()
		for slot in PAGE_SIZE:
			var index: int = int(pages[side]) * PAGE_SIZE + slot
			var item: Dictionary = items[index] if index < items.size() else {}
			_make_slot(panel.grid, side, item)

func _make_slot(grid: GridContainer, side: String, item: Dictionary) -> void:
	var slot := Slot.new()
	slot.inventory_view = self
	slot.inventory_side = side
	slot.entry = item.duplicate(true)
	slot.custom_minimum_size = Vector2(145, 144)
	slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slot.add_theme_stylebox_override("panel", ui.box(Color("e4d6b9"), 10))
	grid.add_child(slot)
	var content := VBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(content)
	if item.is_empty():
		var empty := Label.new()
		empty.text = "空位"
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty.custom_minimum_size.y = 116
		empty.modulate.a = .45
		empty.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(empty)
		return
	var is_fish := item.has("species")
	var model: Node3D = game.fishing._fish_model(item) if is_fish else game.item_model(item)
	var preview := Preview.new()
	content.add_child(preview)
	preview.setup(model, is_fish, str(game.fishing.fish_definitions[item.species].clip) if is_fish else "")
	preview.custom_minimum_size = Vector2(126, 82)
	var name_label := RichTextLabel.new()
	name_label.bbcode_enabled = true
	name_label.fit_content = true
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.add_theme_font_size_override("normal_font_size", 14)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.text = "[center]" + game.nutrition.display_name(item.id, item.name) + ("\n%.2f kg" % float(item.weight_kg) if is_fish else " ×" + str(int(item.count))) + "[/center]"
	content.add_child(name_label)
	slot.tooltip_text = "拖动" + str(item.name) + "到另一侧存取；Shift 拖动一个。"

func change_page(side: String, delta: int) -> void:
	pages[side] = int(pages[side]) + delta
	refresh()

func select_item(item: Dictionary) -> void:
	if item.has("species"):
		details.text = "%s · %.2f kg · 拖动到另一侧保存完整鱼获记录。" % [item.name, item.weight_kg]
	else:
		details.text = str(item.name) + " · " + game.item_description(item)

func make_drag_data(side: String, item: Dictionary) -> Dictionary:
	if not visible or not game.survival.chest_open:
		return {}
	var count := 1 if item.has("species") or Input.is_key_pressed(KEY_SHIFT) else int(item.count)
	return {"kind": DRAG_KIND, "session": session, "source": side, "id": str(item.id), "fish": item.has("species"), "count": count}

func can_transfer(data: Variant, target: String) -> bool:
	if not visible or not game.survival.chest_open or not data is Dictionary:
		return false
	if data.get("kind", "") != DRAG_KIND or data.get("session", -1) != session:
		return false
	var source: String = str(data.get("source", ""))
	if source not in ["bag", "chest"] or target not in ["bag", "chest"] or source == target or int(data.get("count", 0)) <= 0:
		return false
	for item: Dictionary in entries(source):
		if str(item.id) == str(data.get("id", "")) and item.has("species") == bool(data.get("fish", false)):
			return item.has("species") or int(item.count) > 0
	return false

func drop_item(data: Variant, target: String) -> void:
	if not can_transfer(data, target):
		return
	var name := "物品"
	for item: Dictionary in entries(str(data.source)):
		if str(item.id) == str(data.id):
			name = str(item.name)
			break
	var moved: bool = game.survival.transfer(str(data.id), int(data.count), data.source == "bag", bool(data.fish))
	if moved:
		var target_items := entries(target)
		for index in target_items.size():
			if str(target_items[index].id) == str(data.id):
				pages[target] = index / PAGE_SIZE
				break
	refresh()
	details.text = ("已存入" if target == "chest" else "已取出") + name + "。" if moved else "这次移动没有保存，物品已恢复，请重试。"
