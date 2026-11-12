extends Control

const SLOT_COUNT := 5
const DRAG_KIND := "abyss_tool_shortcut"
var game: Node3D
var slots: Array[String] = []
var selected := -1
var cells: Array[Control] = []
var captions: Array[Label] = []
var icon_holders: Array[Control] = []
var icon_ids: Array[String] = []
var last_active := ""

func _ready() -> void:
	theme = game.ui.theme_pack
	z_index = 5
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	offset_left = -246
	offset_right = 246
	offset_top = -90
	offset_bottom = -10
	var saved: Array = game.progress.get("tool_hotbar", [])
	for index in SLOT_COUNT:
		var id := str(saved[index]) if index < saved.size() else ""
		slots.append(id if supports(id) and not id in slots else "")
	game.progress.tool_hotbar = slots.duplicate()
	selected = clampi(int(game.progress.get("hotbar_selected", -1)), -1, SLOT_COUNT - 1)
	if selected >= 0 and not slots[selected].is_empty():
		selected = -1
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)
	for index in SLOT_COUNT:
		var cell = preload("res://scripts/ui/tool_hotbar_slot.gd").new()
		cell.bar = self
		cell.index = index
		cell.custom_minimum_size = Vector2(92, 80)
		row.add_child(cell)
		cells.append(cell)
		var content := VBoxContainer.new()
		content.add_theme_constant_override("separation", 2)
		content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(content)
		var holder := Control.new()
		holder.custom_minimum_size = Vector2(60, 40)
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(holder)
		icon_holders.append(holder)
		icon_ids.append("")
		var label := Label.new()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 12)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(label)
		captions.append(label)
	refresh()

func supports(id: String) -> bool:
	return id == "fishing_rod" or id == "lantern" or id in ["harpoon", "harpoon_steel", "hunting_rifle", "bow"] or id in game.farming.TOOLS

func owns(id: String) -> bool:
	return bool(game.progress.rod_found) if id == "fishing_rod" else game.has_good(id)

func title(id: String) -> String:
	if id == "fishing_rod":
		return "鱼竿"
	for item: Dictionary in game.progress.goods:
		if item.id == id:
			return str(item.name)
	return id

func active_id() -> String:
	if game.player.fishing_active:
		return "fishing_rod"
	if not game.hunting.equipped.is_empty():
		return game.hunting.equipped
	if game.harpoon_equipped:
		return "harpoon_steel" if game.has_good("harpoon_steel") else "harpoon"
	return game.farming.selected_tool

func refresh() -> void:
	for index in SLOT_COUNT:
		var id := slots[index]
		captions[index].text = "%d  %s" % [index + 1, "空手" if id.is_empty() else title(id)]
		var style: StyleBoxFlat = game.ui.box(Color("e7d9b9") if selected == index else Color("31665e"), 10)
		style.content_margin_left = 8
		style.content_margin_right = 8
		style.content_margin_top = 8
		style.content_margin_bottom = 8
		style.set_border_width_all(3 if selected == index else 1)
		style.border_color = Color("ffe4a3") if selected == index else Color("aeb88f")
		cells[index].add_theme_stylebox_override("panel", style)
		captions[index].add_theme_color_override("font_color", Color("244b45") if selected == index else Color("fff0ce"))
		captions[index].modulate.a = 1.0 if id.is_empty() or owns(id) else .38
		cells[index].tooltip_text = "格位%d · %s\n点击或数字键1–5装备，再次选择当前装备可收起。\n从背包拖入工具，右键移除快捷项，空槽收起工具。" % [index + 1, "空手" if id.is_empty() else title(id)]
		if icon_ids[index] != id:
			icon_ids[index] = id
			for child: Node in icon_holders[index].get_children():
				icon_holders[index].remove_child(child)
				child.queue_free()
			if not id.is_empty():
				var preview = preload("res://scripts/ui/live_item_preview.gd").new()
				icon_holders[index].add_child(preview)
				preview.setup(game.item_model({"id":id}), false)
				preview.custom_minimum_size = Vector2(60, 40)
				preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
				preview.set_process(false)
				preview.view.render_target_update_mode = SubViewport.UPDATE_ONCE

func assign(index: int, id: String, source := -1) -> bool:
	if index < 0 or index >= SLOT_COUNT or (not id.is_empty() and (not supports(id) or not owns(id))):
		return false
	var before := slots.duplicate()
	var old_selected := selected
	var previous := slots[index]
	var existing := slots.find(id) if not id.is_empty() else -1
	if source >= 0 and source < SLOT_COUNT:
		slots[source] = previous
	elif existing >= 0 and existing != index:
		slots[existing] = ""
	slots[index] = id
	var active := active_id()
	if not active.is_empty() and active in slots:
		selected = slots.find(active)
	game.progress.tool_hotbar = slots.duplicate()
	game.progress.hotbar_selected = selected
	if not game.save():
		slots.assign(before)
		selected = old_selected
		game.progress.tool_hotbar = before
		game.progress.hotbar_selected = old_selected
		return false
	refresh()
	return true

func activate(index: int) -> void:
	if index < 0 or index >= SLOT_COUNT or game.dead or game.cinematic_active or game.player.interaction_time > 0:
		return
	var id := slots[index]
	if not id.is_empty() and not owns(id):
		game.ui.notify("这件工具已不在背包中，取回后再装备。")
		return
	if game.ui.modal_open() and not inventory_open():
		return
	var before: Dictionary = game.progress.duplicate(true)
	var previous := {"selected":selected,"tool":game.farming.selected_tool,"weapon":game.hunting.equipped,"harpoon":game.harpoon_equipped,"fishing":game.player.fishing_active,"reload":game.hunting.reloading,"remaining":game.hunting.reload_remaining,"duration":game.hunting.reload_duration}
	var unequipping: bool = not id.is_empty() and game.is_equipped(id)
	game.ui.bag.hide()
	if game.ui.storage_view != null and game.ui.storage_view.visible:
		game.ui.close_storage()
	if id.is_empty() or unequipping:
		if game.player.fishing_active:
			game.fishing.set_active(false)
		game.hunting.equip("")
		game.farming.equip_tool("")
		game.harpoon_equipped = false
	else:
		game.use_item(id)
	selected = -1 if unequipping else index
	last_active = active_id()
	game.progress.hotbar_selected = selected
	if not game.save():
		game.restore_progress(before)
		selected = int(previous.selected)
		game.farming.selected_tool = previous.tool
		game.hunting.equipped = previous.weapon
		game.harpoon_equipped = previous.harpoon
		game.hunting.reloading = previous.reload
		game.hunting.reload_remaining = previous.remaining
		game.hunting.reload_duration = previous.duration
		if game.player.fishing_active != bool(previous.fishing):
			game.fishing.set_active(bool(previous.fishing))
		last_active = active_id()
		game.ui.notify("快捷装备未能保存，已恢复原来的工具。")
	refresh()

func inventory_open() -> bool:
	return game.ui.bag.visible or (game.ui.storage_view != null and game.ui.storage_view.visible)

func can_assign_drag(data: Variant) -> bool:
	if not data is Dictionary:
		return false
	var id := str(data.get("id", ""))
	if not supports(id) or not owns(id):
		return false
	if data.get("kind", "") == DRAG_KIND:
		return true
	var storage: Control = game.ui.storage_view
	return is_instance_valid(storage) and storage.visible and data.get("kind", "") == storage.DRAG_KIND and data.get("source", "") == "bag" and not bool(data.get("fish", false)) and int(data.get("session", -1)) == storage.session

func drag_data(index: int) -> Dictionary:
	if slots[index].is_empty() or not owns(slots[index]):
		return {}
	return {"kind":DRAG_KIND,"id":slots[index],"slot":index}

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode >= KEY_1 and event.keycode <= KEY_5:
		if visible and (not game.ui.modal_open() or inventory_open()):
			activate(int(event.keycode) - KEY_1)
			get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	visible = not game.dead and not game.cinematic_active and not game.ui.settings.visible and not game.ui.dialog.visible and not game.survival.map_open() and not game.nutrition.ui_panel.visible
	var current := active_id()
	if not current.is_empty() and not owns(current):
		if game.farming.selected_tool == current:
			game.farming.equip_tool("")
		elif game.hunting.equipped == current:
			game.hunting.equip("")
		elif game.harpoon_equipped:
			game.harpoon_equipped = false
			game.save()
		current = active_id()
	if current != last_active:
		last_active = current
		selected = slots.find(current) if not current.is_empty() else selected if selected >= 0 and slots[selected].is_empty() else -1
		refresh()
	for index in SLOT_COUNT:
		captions[index].modulate.a = 1.0 if slots[index].is_empty() or owns(slots[index]) else .38
