extends PanelContainer
var game: Node3D
var item: Dictionary

func _get_cursor_shape(_position: Vector2) -> int:
	return Control.CURSOR_DRAG if not item.is_empty() and game.hotbar.supports(str(item.id)) else Control.CURSOR_POINTING_HAND

func _get_drag_data(_position: Vector2) -> Variant:
	if item.is_empty():
		return null
	if not game.hotbar.supports(str(item.id)) or not game.hotbar.owns(str(item.id)):
		return null
	var label := Label.new()
	label.theme = game.ui.theme_pack
	label.text = str(item.name)
	set_drag_preview(label)
	return {"kind":game.hotbar.DRAG_KIND,"id":str(item.id)}

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and not item.is_empty():
		game.ui._select_item(item)
		accept_event()
