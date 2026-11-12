extends Control

const OCEAN_COLOR := Color("3d7b88")
const DRAG_THRESHOLD := 4.0
var survival: Node3D
var expanded := false
var zoom := 1.0
var pan := Vector2.ZERO
var redraw_timer := 0.0
var fitted_bounds := Rect2()
var left_pressed := false
var dragged := false
var press_position := Vector2.ZERO
var press_pan := Vector2.ZERO

func setup(controller: Node3D, large: bool) -> void:
	survival = controller
	expanded = large
	theme = survival.game.ui.theme_pack
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_force_pass_scroll_events = false
	queue_redraw()

func _point(coordinate: Vector2) -> Vector2:
	var content := _content_rect()
	var bounds := fitted_bounds if fitted_bounds.has_area() else _fit_bounds()
	var scale := minf(content.size.x / bounds.size.x, content.size.y / bounds.size.y)
	return content.get_center() + pan + (coordinate - bounds.get_center()) * scale * zoom

func _content_rect() -> Rect2:
	return Rect2(Vector2(12, 28), Vector2(maxf(1, size.x - 24), maxf(1, size.y - (66 if expanded else 40))))

func _fit_bounds() -> Rect2:
	var bounds: Rect2 = survival.map_data.bounds
	if not expanded:
		bounds = survival.map_data.get("island_bounds", bounds)
	for building: Dictionary in survival.map_data.buildings:
		bounds = bounds.expand(survival.map_coordinate(building.position))
	bounds = bounds.expand(survival.map_coordinate(survival.game.player.global_position))
	if is_instance_valid(survival.game.vehicle) and survival.game.vehicle.visible:
		bounds = bounds.expand(survival.map_coordinate(survival.game.vehicle.global_position))
	for plot: Dictionary in survival.game.progress.plots:
		bounds = bounds.expand(survival.map_coordinate(Vector3(plot.position[0], plot.position[1], plot.position[2])))
	return bounds.grow(maxf(bounds.size.x, bounds.size.y) * .025)

func _world_point(point: Vector3) -> Vector2:
	return _point(survival.map_coordinate(point))

func change_zoom(factor: float) -> void:
	zoom = clampf(zoom * factor, 1.0, 5.0 if expanded else 16.0)
	if is_equal_approx(zoom, 1.0):
		zoom = 1.0
		pan = Vector2.ZERO
	queue_redraw()

func _draw() -> void:
	if survival == null or survival.map_data.is_empty():
		return
	draw_rect(Rect2(Vector2.ZERO, size), OCEAN_COLOR)
	var cell: Vector2 = survival.map_data.cell_size
	for entry: Dictionary in survival.map_data.cells:
		var top := _point(entry.point)
		var end := _point(entry.point + cell)
		draw_rect(Rect2(top, end - top), entry.color)
	for building: Dictionary in survival.map_data.buildings:
		var point := _world_point(building.position)
		draw_rect(Rect2(point - Vector2.ONE * 3, Vector2.ONE * 6), Color("e3c18a"))
		if expanded:
			var width := get_theme_default_font().get_string_size(building.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
			var label_position := Vector2(clampf(point.x + 6, 12, size.x - width - 12), clampf(point.y - 4, 32, size.y - 44))
			draw_string(get_theme_default_font(), label_position, building.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("f8ecd1"))
	for plot: Dictionary in survival.game.progress.plots:
		var point := _world_point(Vector3(plot.position[0], plot.position[1], plot.position[2]))
		draw_circle(point, 2.5, Color("e3a85d"))
	if survival.game.vehicle != null and survival.game.vehicle.visible:
		var car_position := _world_point(survival.game.vehicle.global_position)
		draw_rect(Rect2(car_position-Vector2(4,3),Vector2(8,6)),Color("f3c670"))
		if expanded:
			draw_string(get_theme_default_font(),car_position+Vector2(7,0),"沙滩车",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("fff0c9"))
	if survival.game.crocodiles != null:
		for animal: CharacterBody3D in survival.game.crocodiles.animals:
			if animal.visible and animal.global_position.distance_to(survival.game.player.global_position) < 40:
				draw_circle(_world_point(animal.global_position), 2.5, Color("c96d53"))
	var player: CharacterBody3D = survival.game.player
	var position := _world_point(player.global_position)
	var facing: Vector3 = player.visual.global_basis.z
	var direction := Vector2(facing.dot(survival.east), facing.dot(survival.south)).normalized()
	var side := Vector2(-direction.y, direction.x)
	draw_circle(position, 6 if expanded else 4, Color("244b52"))
	draw_colored_polygon(PackedVector2Array([position + direction * 8, position - direction * 5 + side * 4, position - direction * 5 - side * 4]), Color("ffe7a0"))
	draw_rect(Rect2(Vector2.ONE, size - Vector2.ONE * 2), Color("c8b682"), false, 2)
	draw_string(get_theme_default_font(), Vector2(size.x * .5 - 6, 18), "北", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("f8ecd1"))
	if expanded:
		draw_string(get_theme_default_font(), Vector2(12, size.y - 12), "蓝色 海水    浅黄 沙滩    绿色 林地    橙色 耕地    鼠标滚轮缩放 · 拖动地图", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("f8ecd1"))

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			var factor := 1.2 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.2
			var center := _content_rect().get_center()
			var point: Vector2 = (event.position - center - pan) / zoom
			change_zoom(factor)
			if zoom > 1.0:
				pan = event.position - center - point * zoom
			if left_pressed:
				dragged = true
				press_position = event.position
				press_pan = pan
			accept_event()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				left_pressed = true
				dragged = false
				press_position = event.position
				press_pan = pan
			else:
				var clicked: bool = left_pressed and not dragged and event.position.distance_to(press_position) < DRAG_THRESHOLD
				left_pressed = false
				if clicked and not expanded and Rect2(Vector2.ZERO, size).has_point(event.position):
					survival.toggle_map()
				dragged = false
			accept_event()
	elif event is InputEventMouseMotion and left_pressed and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		var distance: Vector2 = event.position - press_position
		dragged = dragged or distance.length() >= DRAG_THRESHOLD
		if dragged:
			pan = press_pan + distance
			queue_redraw()
		accept_event()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT or (what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree()):
		left_pressed = false
		dragged = false

func _process(delta: float) -> void:
	redraw_timer -= delta
	if redraw_timer <= 0:
		redraw_timer = .1
		if survival != null and not survival.map_data.is_empty():
			fitted_bounds = _fit_bounds()
		queue_redraw()
