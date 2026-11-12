extends Node
## The props' gallery (gallery.tscn), opened on the first prop, with a way back to the skies.


func _ready() -> void:
	var here := (get_script() as Script).resource_path.get_base_dir()
	var gallery: Node = load(here + "/gallery.tscn").instantiate()
	add_child(gallery)
	gallery.show_prop(0)
	var ui := CanvasLayer.new()
	ui.layer = 2
	add_child(ui)
	var b := Button.new()
	b.text = "Skies"
	b.focus_mode = Control.FOCUS_NONE
	b.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	b.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	b.position += Vector2(-16, 44)
	b.pressed.connect(func() -> void: get_tree().change_scene_to_file(here + "/skies.tscn"))
	ui.add_child(b)
