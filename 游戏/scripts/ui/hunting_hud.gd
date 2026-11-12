extends Control
var hunting: Node3D

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _draw() -> void:
	if not is_instance_valid(hunting) or not hunting.aiming:
		return
	var point: Vector2 = hunting.aim_cursor
	var color := Color("ffe8ab")
	for direction in [Vector2.UP,Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT]:
		draw_line(point + direction * 5, point + direction * 12, Color("244b52"), 4, true)
		draw_line(point + direction * 5, point + direction * 12, color, 2, true)
	draw_circle(point, 1.5, color)
	var game: Node3D = hunting.game
	var text := "木弓  ·  木箭 %d  ·  C 制箭" % game.economy.quantity("wooden_arrow")
	if hunting.equipped == "hunting_rifle":
		var chamber := "空膛"
		if hunting.reloading:
			chamber = "装填 %.1fs" % hunting.reload_remaining
		elif game.progress.get("rifle_loaded", false):
			chamber = "已上膛"
		text = "猎枪  ·  %s  ·  备弹 %d  ·  R 装填" % [chamber, game.economy.quantity("rifle_ammo")]
	var box := Rect2(Vector2(size.x * .5 - 235, size.y - 196), Vector2(470, 38))
	draw_style_box(game.ui.box(Color("31665e"), 10), box)
	draw_string(game.ui.theme_pack.default_font, box.position + Vector2(16, 25), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("fff0ce"))

func _process(_delta: float) -> void:
	queue_redraw()
