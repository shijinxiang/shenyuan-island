extends PanelContainer

var inventory_view: Control
var inventory_side := ""
var entry: Dictionary = {}

func _get_drag_data(_position: Vector2) -> Variant:
	if not is_instance_valid(inventory_view) or entry.is_empty():
		return null
	var data: Dictionary = inventory_view.make_drag_data(inventory_side, entry)
	if data.is_empty():
		return null
	var preview := PanelContainer.new()
	preview.theme = inventory_view.theme
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label := Label.new()
	label.text = str(entry.name) + " ×" + str(data.count)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.add_child(label)
	set_drag_preview(preview)
	return data

func _can_drop_data(_position: Vector2, data: Variant) -> bool:
	var allowed: bool = is_instance_valid(inventory_view) and inventory_view.can_transfer(data, inventory_side)
	modulate = Color(1.12, 1.12, 1.06) if allowed else Color.WHITE
	return allowed

func _drop_data(_position: Vector2, data: Variant) -> void:
	modulate = Color.WHITE
	if is_instance_valid(inventory_view):
		inventory_view.drop_item(data, inventory_side)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if is_instance_valid(inventory_view) and not entry.is_empty():
			inventory_view.select_item(entry)
		accept_event()

func _notification(what: int) -> void:
	if what in [NOTIFICATION_MOUSE_EXIT, NOTIFICATION_DRAG_END]:
		modulate = Color.WHITE
