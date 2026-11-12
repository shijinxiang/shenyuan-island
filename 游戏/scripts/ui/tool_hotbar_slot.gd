extends PanelContainer
var bar: Control
var index := 0
var pressed_here := false
var press_position := Vector2.ZERO

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	mouse_force_pass_scroll_events = true

func _get_drag_data(_position: Vector2) -> Variant:
	var data: Dictionary = bar.drag_data(index)
	if data.is_empty():
		return null
	pressed_here = false
	var label := Label.new()
	label.theme = theme
	label.text = bar.title(data.id)
	set_drag_preview(label)
	return data

func _can_drop_data(_position: Vector2, data: Variant) -> bool:
	var allowed: bool = bar.can_assign_drag(data)
	modulate = Color(1.15, 1.12, .94) if allowed else Color.WHITE
	return allowed

func _drop_data(_position: Vector2, data: Variant) -> void:
	pressed_here = false
	modulate = Color.WHITE
	if bar.can_assign_drag(data) and bar.assign(index, str(data.id), int(data.get("slot", -1))):
		bar.game.ui.notify("已放入第%d格，按%d快捷装备。" % [index + 1, index + 1])

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				pressed_here = true
				press_position = event.position
			else:
				if pressed_here and event.position.distance_to(press_position) < 4 and Rect2(Vector2.ZERO, size).has_point(event.position):
					bar.activate(index)
				pressed_here = false
			accept_event()
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			bar.assign(index, "")
			accept_event()

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		pressed_here = false
		modulate = Color.WHITE
	elif what == NOTIFICATION_MOUSE_EXIT:
		modulate = Color.WHITE
