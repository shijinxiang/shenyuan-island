extends Node

const Utility = preload("res://scripts/core/island_static_setup.gd")
var states: Array[Dictionary] = []
var player_mask: Node

func _ready() -> void:
	process_priority = 75
	player_mask = get_parent().game.player.get_node("PlayerOcclusion")
	var canvas := CanvasLayer.new()
	canvas.layer = 10
	add_child(canvas)
	for index in 2:
		var viewport := SubViewport.new()
		viewport.own_world_3d = true
		viewport.transparent_bg = true
		viewport.gui_disable_input = true
		viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		add_child(viewport)
		var camera := Camera3D.new()
		viewport.add_child(camera)
		camera.make_current()
		var texture := TextureRect.new()
		texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		texture.texture = viewport.get_texture()
		var material := ShaderMaterial.new()
		material.shader = preload("res://shaders/interaction_outline.gdshader")
		material.set_shader_parameter("player_mask", player_mask.mask_viewport.get_texture())
		material.set_shader_parameter("edge_pixels", 4.0 if index == 1 else 2.0)
		material.set_shader_parameter("edge_opacity", 1.0 if index == 1 else .65)
		texture.material = material
		canvas.add_child(texture)
		texture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		texture.hide()
		states.append({"source":null,"clone":null,"signature":"","viewport":viewport,"camera":camera,"texture":texture,"material":material,"transforms":[],"skeletons":[]})
	get_viewport().size_changed.connect(_resize)
	_resize()

func _resize() -> void:
	var size := get_viewport().get_visible_rect().size
	for state: Dictionary in states:
		state.viewport.size = Vector2i(maxi(2, ceili(size.x)), maxi(2, ceili(size.y)))

func set_targets(hovered: Dictionary, selected: Dictionary) -> void:
	var targets: Array[Dictionary] = [hovered, selected]
	if not hovered.is_empty() and not selected.is_empty() and hovered.node == selected.node:
		targets[0] = {}
	for index in 2:
		var state: Dictionary = states[index]
		var entry: Dictionary = targets[index]
		var source: Node3D = entry.get("node") if entry.get("kind", "") != "ground" else null
		var valid := is_instance_valid(source) and source.is_visible_in_tree() and not source.is_queued_for_deletion()
		state.texture.visible = valid
		state.viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if valid else SubViewport.UPDATE_DISABLED
		if not valid:
			state.source = null
			continue
		var ids: PackedStringArray = []
		for mesh: MeshInstance3D in Utility.meshes(source):
			ids.append(str(mesh.get_instance_id()) + ":" + str(mesh.mesh.get_instance_id()))
		var signature := "/".join(ids)
		if state.source != source or state.signature != signature or not is_instance_valid(state.clone):
			_build(state, source, signature)
	player_mask.interaction_mask_needed = states.any(func(state): return state.texture.visible)

func _build(state: Dictionary, source: Node3D, signature: String) -> void:
	if is_instance_valid(state.clone):
		state.viewport.remove_child(state.clone)
		state.clone.queue_free()
	var clone := source.duplicate(0) as Node3D
	for animator: AnimationPlayer in clone.find_children("*", "AnimationPlayer", true, false):
		animator.free()
	for body: CollisionObject3D in clone.find_children("*", "CollisionObject3D", true, false):
		body.free()
	var mask := ShaderMaterial.new()
	mask.shader = preload("res://shaders/player_silhouette.gdshader")
	for mesh: MeshInstance3D in Utility.meshes(clone):
		mesh.material_override = mask
		mesh.material_overlay = null
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	state.viewport.add_child(clone)
	state.source = source
	state.clone = clone
	state.signature = signature
	state.transforms = []
	state.skeletons = []
	for original: Node3D in source.find_children("*", "Node3D", true, false):
		var copy := clone.get_node_or_null(source.get_path_to(original)) as Node3D
		if copy:
			state.transforms.append({"source":original,"copy":copy})
			if original is Skeleton3D:
				state.skeletons.append({"source":original,"copy":copy})

func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	for state: Dictionary in states:
		if not state.texture.visible:
			continue
		if not is_instance_valid(state.source) or not state.source.is_visible_in_tree():
			state.texture.hide()
			state.viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
			continue
		state.clone.global_transform = state.source.global_transform
		for pair: Dictionary in state.transforms:
			if is_instance_valid(pair.source) and is_instance_valid(pair.copy):
				pair.copy.transform = pair.source.transform
				pair.copy.visible = pair.source.visible
		for pair: Dictionary in state.skeletons:
			for index in pair.source.get_bone_count():
				pair.copy.set_bone_pose(index, pair.source.get_bone_pose(index))
		var proxy: Camera3D = state.camera
		proxy.global_transform = camera.global_transform
		proxy.projection = camera.projection
		proxy.keep_aspect = camera.keep_aspect
		proxy.fov = camera.fov
		proxy.size = camera.size
		proxy.near = camera.near
		proxy.far = camera.far
		proxy.frustum_offset = camera.frustum_offset
		proxy.h_offset = camera.h_offset
		proxy.v_offset = camera.v_offset

func _exit_tree() -> void:
	if is_instance_valid(player_mask):
		player_mask.interaction_mask_needed = false
