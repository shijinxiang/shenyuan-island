extends Node3D
## The pack's skies one at a time over the demo meadow: left and right (or the buttons) change the
## sky, 1 to 6 jump to a kind, the mouse dragged looks round, P opens the props' gallery. In a
## scene of your own a sky is its `skies/<name>.tscn` dropped in (its WorldEnvironment and its sun
## or moon), or its `skies/<name>.tres` on a WorldEnvironment you have.

const EYE := 1.7
const KINDS := ["day", "dusk", "night", "overcast", "storm", "seasonal"]

var dir: String
var skies: Array
var index := 0
var sky: Node
var cam := Camera3D.new()
var yaw := 0.0
var pitch := 0.14
var idle := 0.0
var level_fog := 0.012
var title := Label.new()
var info := Label.new()


func _ready() -> void:
	dir = (get_script() as Script).resource_path.get_base_dir().get_base_dir()
	skies = JSON.parse_string(FileAccess.get_file_as_string(dir + "/skies.json"))["skies"]
	var start: Array = _meadow(JSON.parse_string(FileAccess.get_file_as_string(dir + "/props.json")))
	cam.position = Vector3(start[0], EYE, -start[1])
	cam.fov = 70
	add_child(cam)
	cam.current = true
	_ui()
	show_sky(0)


## The layout's pieces, their loops playing; returns where it starts the eye.
func _meadow(data: Dictionary) -> Array:
	var level: Dictionary = data.get("layout", {})
	var named := {}
	for p in data["props"]:
		named[p["name"]] = p
	var pieces: Array = level.get("pieces", [])
	if pieces.is_empty() and named.has("ground_meadow"):  # the sampler's: no layout, its meadow laid as the pack's
		for i in 12:
			for j in 12:
				pieces.append(["ground_meadow", [(i - 5.5) * 8.0, (j - 5.5) * 8.0, 0.0], 90 * ((i * 7 + j * 3) % 4)])
	for it in pieces:
		if not named.has(it[0]):
			continue
		var n: Node3D = load("%s/props/%s.tscn" % [dir, it[0]]).instantiate()
		n.position = Vector3(it[1][0], it[1][2], -it[1][1])
		n.rotation_degrees.y = it[2]
		add_child(n)
		if it[0] in level.get("running", []):
			var a: Dictionary = named[it[0]]["anims"].filter(func(x): return x["loop"])[0]
			var player := n.find_child("AnimationPlayer", true, false) as AnimationPlayer
			player.play(a["name"])
			player.seek(fposmod(n.position.x * 0.37 + n.position.z * 0.61, 1.0) * a["seconds"], true)
	level_fog = level.get("fog", level_fog)
	return level.get("start", [0, -14, 0, 180])


func show_sky(i: int) -> void:
	index = posmod(i, skies.size())
	var s: Dictionary = skies[index]
	if sky:
		sky.queue_free()
	sky = load("%s/skies/%s.tscn" % [dir, s["name"]]).instantiate()
	sky.get_node("WorldEnvironment").environment.fog_density = level_fog  # the meadow's edge gone into the sky
	add_child(sky)
	title.text = s["title"]
	info.text = "%s  -  %d / %d  -  skies/%s.tscn" % [s["kind"].capitalize(), index + 1, skies.size(), s["name"]]


func _ui() -> void:
	var ui := CanvasLayer.new()
	add_child(ui)
	var top := VBoxContainer.new()
	top.position = Vector2(20, 16)
	ui.add_child(top)
	for l in [title, info]:
		l.add_theme_color_override("font_shadow_color", Color.BLACK)
		l.add_theme_constant_override("shadow_offset_x", 2)
		l.add_theme_constant_override("shadow_offset_y", 2)
		top.add_child(l)
	title.add_theme_font_size_override("font_size", 28)
	info.add_theme_font_size_override("font_size", 15)
	info.modulate = Color(0.9, 0.9, 0.9)
	var bar := HBoxContainer.new()
	bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bar.position.y -= 16
	ui.add_child(bar)
	_button(bar, "<", func() -> void: show_sky(index - 1))
	_button(bar, ">", func() -> void: show_sky(index + 1))
	var have := skies.map(func(s): return s["kind"])
	for k in KINDS.size():
		if KINDS[k] in have:  # the sampler's four kinds only
			_button(bar, KINDS[k].capitalize(), _kind.bind(k))
	_button(bar, "Props", props)
	var hint := Label.new()
	hint.text = "left / right to change the sky, drag to look round"
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_shadow_color", Color.BLACK)
	hint.add_theme_constant_override("shadow_offset_x", 1)
	hint.add_theme_constant_override("shadow_offset_y", 1)
	hint.modulate = Color(1, 1, 1, 0.7)
	hint.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	hint.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	hint.position += Vector2(-16, 16)
	ui.add_child(hint)


func _button(box: Container, text: String, pressed: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size.x = 44
	b.pressed.connect(pressed)
	box.add_child(b)


func _kind(k: int) -> void:
	var i := skies.map(func(s): return s["kind"]).find(KINDS[k])
	if i >= 0:
		show_sky(i)


func props() -> void:
	get_tree().change_scene_to_file(dir + "/demo/props.tscn")


func _process(delta: float) -> void:
	idle += delta
	if idle > 4.0:  # left alone, it looks round on its own
		yaw += delta * 0.06
	cam.rotation = Vector3(pitch, yaw, 0)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		yaw -= event.relative.x * 0.005
		pitch = clampf(pitch - event.relative.y * 0.005, -0.5, 1.4)
		idle = 0.0
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_LEFT, KEY_A:
				show_sky(index - 1)
			KEY_RIGHT, KEY_D:
				show_sky(index + 1)
			KEY_P:
				props()
			_:
				if event.keycode >= KEY_1 and event.keycode <= KEY_6:
					_kind(event.keycode - KEY_1)
