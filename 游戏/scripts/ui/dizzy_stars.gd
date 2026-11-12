extends Control

var nutrition: Node3D
var phase := 0.0
var intensity := 0.0
var screen_points := PackedVector2Array()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_priority = 80

func _process(delta: float) -> void:
	phase += delta * 1.7
	screen_points.clear()
	var game: Node3D = nutrition.game
	var camera := get_viewport().get_camera_3d()
	var player: CharacterBody3D = game.player
	var target := clampf((15.0 - nutrition.hunger) / 10.0, 0, 1)
	if game.dead or game.cinematic_active or not player.is_visible_in_tree():
		target = 0
	intensity = move_toward(intensity, target, delta * 3)
	if intensity > .01 and camera:
		var skeleton: Skeleton3D = game.fishing.skeleton
		var head := skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone("Head")).origin + Vector3.UP * .43
		for index in 4:
			var angle := phase + index * TAU / 4
			var point := head + Vector3(cos(angle) * .5, sin(angle * 2) * .035, sin(angle) * .5)
			if camera.is_position_in_frustum(point):
				screen_points.append(camera.unproject_position(point))
	queue_redraw()

func _draw() -> void:
	for index in screen_points.size():
		var point := screen_points[index]
		var polygon := PackedVector2Array()
		for corner in 8:
			var angle := corner * TAU / 8 + phase * .25
			var radius := 6.0 if corner % 2 == 0 else 2.0
			polygon.append(point + Vector2(cos(angle), sin(angle)) * radius)
		draw_circle(point, 10, Color(1, .72, .15, .08 * intensity))
		draw_colored_polygon(polygon, Color(1, .8, .18, intensity))
		polygon.append(polygon[0])
		draw_polyline(polygon, Color(.55, .32, .05, intensity * .8), 1, true)
