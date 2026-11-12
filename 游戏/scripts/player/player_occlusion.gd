extends Node

const OCCLUDER_MASK := 1 | 128
const MAX_OPACITY := .30
const SAMPLE_BONES := ["Head", "Spine2", "Hips", "LeftArm", "RightArm"]

var player: CharacterBody3D
var source_skeleton: Skeleton3D
var silhouette_skeleton: Skeleton3D
var silhouette: Node3D
var mask_viewport: SubViewport
var mask_camera: Camera3D
var overlay: TextureRect
var blur_material: ShaderMaterial
var sample_indices: Array[int] = []
var opacity := 0.0
var blocked_fraction := 0.0
var interaction_mask_needed := false
var source_meshes: Array[MeshInstance3D] = []
var silhouette_meshes: Array[MeshInstance3D] = []

func _ready() -> void:
	player = get_parent()
	process_priority = 50
	source_skeleton = player.visual.find_children("*", "Skeleton3D", true, false)[0]
	for bone: String in SAMPLE_BONES:
		var index := source_skeleton.find_bone(bone)
		if index >= 0:
			sample_indices.append(index)
	mask_viewport = SubViewport.new()
	mask_viewport.name = "SilhouetteMask"
	mask_viewport.own_world_3d = true
	mask_viewport.transparent_bg = true
	mask_viewport.gui_disable_input = true
	mask_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(mask_viewport)
	silhouette = player.visual.duplicate(0)
	for mesh: MeshInstance3D in player.visual.find_children("*", "MeshInstance3D", true, false):
		source_meshes.append(mesh)
	silhouette.name = "Silhouette"
	for animator: AnimationPlayer in silhouette.find_children("*", "AnimationPlayer", true, false):
		animator.free()
	var mask_material := ShaderMaterial.new()
	mask_material.shader = preload("res://shaders/player_silhouette.gdshader")
	for mesh: MeshInstance3D in silhouette.find_children("*", "MeshInstance3D", true, false):
		silhouette_meshes.append(mesh)
		mesh.material_override = mask_material
		mesh.material_overlay = null
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mask_viewport.add_child(silhouette)
	silhouette_skeleton = silhouette.find_children("*", "Skeleton3D", true, false)[0]
	mask_camera = Camera3D.new()
	mask_viewport.add_child(mask_camera)
	mask_camera.make_current()
	var canvas := CanvasLayer.new()
	canvas.name = "SoftOcclusion"
	canvas.layer = 20
	add_child(canvas)
	overlay = TextureRect.new()
	overlay.name = "BlurredSilhouette"
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	overlay.texture = mask_viewport.get_texture()
	blur_material = ShaderMaterial.new()
	blur_material.shader = preload("res://shaders/player_occlusion_blur.gdshader")
	overlay.material = blur_material
	canvas.add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.hide()
	get_viewport().size_changed.connect(_resize_mask)
	source_skeleton.skeleton_updated.connect(_sync_pose)
	_resize_mask()
	_sync_pose()

func _resize_mask() -> void:
	var size := get_viewport().get_visible_rect().size
	mask_viewport.size = Vector2i(maxi(2, ceili(size.x * .5)), maxi(2, ceili(size.y * .5)))

func _sync_pose() -> void:
	if not overlay.visible and not interaction_mask_needed:
		return
	for index in mini(source_meshes.size(), silhouette_meshes.size()):
		if silhouette_meshes[index].mesh != source_meshes[index].mesh:
			silhouette_meshes[index].mesh = source_meshes[index].mesh
			silhouette_meshes[index].skin = source_meshes[index].skin
	for index in source_skeleton.get_bone_count():
		silhouette_skeleton.set_bone_pose(index, source_skeleton.get_bone_pose(index))

func _occluded_fraction(camera: Camera3D) -> float:
	var excluded: Array[RID] = [player.get_rid()]
	var ridden: Node3D
	var helper: Node3D
	if is_instance_valid(player.rowing) and player.rowing.boarded:
		excluded.append(player.rowing.get_rid())
		ridden = player.rowing.boat_visual
	if player.in_vehicle():
		excluded.append(player.vehicle.get_rid())
		ridden = player.vehicle.model
	if is_instance_valid(player.adventure):
		helper = player.adventure.interaction
	var blocked := 0
	var tested := 0
	var space := player.get_world_3d().direct_space_state
	for index: int in sample_indices:
		var target := source_skeleton.global_transform * source_skeleton.get_bone_global_pose(index).origin
		if not camera.is_position_in_frustum(target):
			continue
		var screen_point := camera.unproject_position(target)
		var origin := camera.project_ray_origin(screen_point)
		var direction := camera.project_ray_normal(screen_point)
		var query := PhysicsRayQueryParameters3D.create(origin, target - direction * .08, OCCLUDER_MASK, excluded)
		query.hit_from_inside = true
		var obstructed := not space.intersect_ray(query).is_empty()
		if not obstructed and is_instance_valid(ridden) and is_instance_valid(helper):
			obstructed = helper._mesh_hit(ridden, origin, direction) < origin.distance_to(target) - .08
		if obstructed:
			blocked += 1
		tested += 1
	return float(blocked) / tested if tested > 0 else 0.0

func _process(delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	var allowed := player.is_visible_in_tree() and is_instance_valid(camera)
	if is_instance_valid(player.adventure):
		allowed = allowed and not player.adventure.dead and not player.adventure.cinematic_active
	blocked_fraction = _occluded_fraction(camera) if allowed else 0.0
	var target_opacity := MAX_OPACITY * sqrt(blocked_fraction)
	opacity = move_toward(opacity, target_opacity, delta * 1.8) if allowed else 0.0
	overlay.visible = opacity > .001
	mask_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if overlay.visible or interaction_mask_needed else SubViewport.UPDATE_DISABLED
	if not overlay.visible and not interaction_mask_needed:
		return
	silhouette.global_transform = player.visual.global_transform
	mask_camera.global_transform = camera.global_transform
	mask_camera.projection = camera.projection
	mask_camera.keep_aspect = camera.keep_aspect
	mask_camera.fov = camera.fov
	mask_camera.size = camera.size
	mask_camera.near = camera.near
	mask_camera.far = camera.far
	mask_camera.frustum_offset = camera.frustum_offset
	mask_camera.h_offset = camera.h_offset
	mask_camera.v_offset = camera.v_offset
	blur_material.set_shader_parameter("opacity", opacity)
	_sync_pose()
