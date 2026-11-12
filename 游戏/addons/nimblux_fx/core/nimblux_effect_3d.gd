@tool
@icon("res://addons/nimblux_fx/icons/effect.svg")
class_name NimbluxEffect3D
extends Node3D
## Base class for NIMBLUX 3D weather effects (Lite). Handles strength and fading, timing and
## following the camera. Geometry lives in internal child nodes, so it is never saved into
## scenes and never shows up in the scene tree.
## The full version replaces this file and adds shared wind and shelters. Copying the full
## addons/nimblux_fx over this one keeps every value saved in your scenes.

## Emitted when stop() has fully faded the effect out.
signal faded_out

## Strength of the effect, 0 = off, 1 = full.
@export_range(0.0, 1.0, 0.01) var amount: float = _default(&"amount", 1.0)
## Playback speed.
@export_range(0.0, 4.0, 0.01) var time_scale: float = 1.0
## Start when the node enters the tree at runtime. When off, call play().
@export var autoplay: bool = true
## Seconds play() and stop() take to fade in and out.
@export_range(0.0, 30.0, 0.01, "or_greater") var fade_time: float = _default(&"fade_time", 1.5)
## Animate inside the editor viewport.
@export var preview_in_editor: bool = true
## Random seed. 0 picks a different seed for every instance.
@export var random_seed: int = 0

@export_group("Area")
## Centre the effect volume on the active camera (the editor camera while editing).
@export var follow_camera: bool = true
## Centre on this node instead of the camera.
@export var follow_target: Node3D
## Size of the volume around the camera, in metres before node scale.
@export var area_size: Vector3 = _default(&"area_size", Vector3(24.0, 14.0, 24.0))
## How far the volume is pushed ahead of the camera, as a fraction of its width.
@export_range(0.0, 0.5, 0.01) var look_ahead: float = _default(&"look_ahead", 0.2)

var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var seed_value: int = 1
var _time: float = 0.0
var _level: float = 0.0
var _running: bool = false
var _faded_emitted: bool = true
var _layers: Array[MeshInstance3D] = []
var _layer_materials: Array[ShaderMaterial] = []
var _center: Vector3 = Vector3.ZERO
var _pixel_angle: float = 0.002


func _ready() -> void:
	if random_seed != 0:
		rng.seed = random_seed
	else:
		rng.randomize()
	seed_value = rng.randi_range(1, 1 << 30)
	_build()
	if Engine.is_editor_hint():
		_running = preview_in_editor
		_level = 1.0 if _running else 0.0
	elif autoplay:
		_running = true
		_level = 1.0
	_faded_emitted = not _running
	_process(0.0)


func _process(delta: float) -> void:
	if Engine.is_editor_hint() and not preview_in_editor:
		_set_layers_visible(false)
		return
	var dt: float = delta * time_scale
	_time = fmod(_time + dt, 3600.0)
	var target: float = 1.0 if _running else 0.0
	_level = move_toward(_level, target, delta / maxf(fade_time, 0.001)) if fade_time > 0.0 else target
	if not _running and _level <= 0.0 and not _faded_emitted:
		_faded_emitted = true
		faded_out.emit()
	_set_layers_visible(effective_amount() > 0.0005)
	_update_center()
	_tick(dt)
	_update_common()


## Fades the effect in over fade_time seconds.
func play() -> void:
	_running = true
	_faded_emitted = false


## Fades the effect out over fade_time seconds, then emits faded_out.
func stop() -> void:
	_running = false


func is_playing() -> bool:
	return _running


## Changes amount smoothly over `seconds`.
func set_amount_smooth(value: float, seconds: float) -> void:
	var tw: Tween = create_tween()
	tw.tween_property(self, "amount", clampf(value, 0.0, 1.0), maxf(seconds, 0.0))


## amount multiplied by the play/stop fade.
func effective_amount() -> float:
	return clampf(amount, 0.0, 1.0) * _level


func world_scale() -> float:
	return global_basis.get_scale().x if is_inside_tree() else scale.x


## Centre of the effect volume in world space.
func get_area_center() -> Vector3:
	return _center


func get_camera() -> Camera3D:
	if not is_inside_tree():
		return null
	if Engine.is_editor_hint():
		if Engine.has_singleton(&"EditorInterface"):
			var ei: Object = Engine.get_singleton(&"EditorInterface")
			var obj: Object = ei.call(&"get_editor_viewport_3d", 0)
			var vp: SubViewport = obj as SubViewport
			if vp:
				return vp.get_camera_3d()
		return null
	return get_viewport().get_camera_3d()


## Per-class defaults for inherited exports. Subclasses extend this dictionary instead of
## assigning values in _init(). Properties initialised through _default() have no constant
## default, so Godot always stores them in the scene and a saved value never reverts.
func _class_defaults() -> Dictionary:
	return {}


func _default(property: StringName, fallback: Variant) -> Variant:
	return _class_defaults().get(property, fallback)


func _property_can_revert(property: StringName) -> bool:
	return _class_defaults().has(property)


func _property_get_revert(property: StringName) -> Variant:
	return _class_defaults().get(property)


## Virtual: create layers.
func _build() -> void:
	pass


## Virtual: advance by a scaled delta and update shader parameters.
func _tick(_delta: float) -> void:
	pass


## Creates an internal, top-level mesh layer driven by `shader`.
func make_layer(shader: Shader, mesh: Mesh, priority: int = 0) -> ShaderMaterial:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = mesh
	mi.top_level = true
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = shader
	mat.render_priority = priority
	mat.set_shader_parameter("seed", seed_value + _layers.size() * 7919)
	mi.material_override = mat
	add_child(mi, false, Node.INTERNAL_MODE_BACK)
	mi.global_transform = Transform3D.IDENTITY
	_layers.append(mi)
	_layer_materials.append(mat)
	return mat


func set_layer_mesh(mat: ShaderMaterial, mesh: Mesh) -> void:
	var i: int = _layer_materials.find(mat)
	if i >= 0:
		_layers[i].mesh = mesh


func set_layer_enabled(mat: ShaderMaterial, on: bool) -> void:
	var i: int = _layer_materials.find(mat)
	if i >= 0:
		_layers[i].set_meta(&"nimblux_off", not on)
		if not on:
			_layers[i].visible = false


## Bounding box used for culling of every layer.
func _layer_bounds() -> AABB:
	var s: Vector3 = area_size * world_scale()
	return AABB(_center - s * 0.5 - Vector3.ONE * 4.0, s + Vector3.ONE * 8.0)


func _set_layers_visible(on: bool) -> void:
	for mi in _layers:
		mi.visible = on and mi.get_meta(&"nimblux_off", false) != true


func _update_center() -> void:
	var cam: Camera3D = get_camera()
	if follow_target and is_instance_valid(follow_target):
		_center = follow_target.global_position
	elif follow_camera and cam:
		var fwd: Vector3 = -cam.global_basis.z
		fwd.y = 0.0
		if fwd.length_squared() > 0.0001:
			fwd = fwd.normalized()
		_center = cam.global_position + fwd * area_size.x * world_scale() * look_ahead
	else:
		_center = global_position
	if cam:
		var h: float = float(get_viewport().get_visible_rect().size.y) if not Engine.is_editor_hint() else 720.0
		if cam.projection == Camera3D.PROJECTION_PERSPECTIVE:
			_pixel_angle = 2.0 * tan(deg_to_rad(cam.fov) * 0.5) / maxf(h, 1.0)
		else:
			_pixel_angle = 0.0005


func _update_common() -> void:
	var bounds: AABB = _layer_bounds()
	for i in _layers.size():
		var mi: MeshInstance3D = _layers[i]
		mi.custom_aabb = bounds
		if mi.global_transform != Transform3D.IDENTITY:
			mi.global_transform = Transform3D.IDENTITY
		var m: ShaderMaterial = _layer_materials[i]
		m.set_shader_parameter("area_center", _center)
		m.set_shader_parameter("time", _time)
		m.set_shader_parameter("pixel_angle", _pixel_angle)
