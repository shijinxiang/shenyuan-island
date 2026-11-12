@tool
@icon("res://addons/nimblux_fx/icons/rain.svg")
class_name NimbluxRain3D
extends NimbluxEffect3D
## Rain around the camera, from drizzle (amount 0.1) to downpour (amount 1). Drops are
## anchored in world space, so moving the camera does not drag them along. Optional
## ripples and splash crowns on the ground.
## Lite: rain also falls under roofs and indoors. To stop it there, use NimbluxShelter3D
## from the full version (gennai.itch.io/weather-vfx-godot-4).

const PRECIP_SHADER: Shader = preload("res://addons/nimblux_fx/shaders/nimblux_precip.gdshader")
const SPLASH_SHADER: Shader = preload("res://addons/nimblux_fx/shaders/nimblux_splash.gdshader")

@export_group("Drops")
## Drops drawn at amount 1. Lower values reduce the drawn count proportionally.
@export_range(100, 30000, 1) var max_drops: int = 9000:
	set(value):
		max_drops = value
		_rebuild_meshes()
## Fall speed in metres per second.
@export_range(0.5, 60.0, 0.1) var fall_speed: float = 13.0
@export_range(0.0, 0.9, 0.01) var speed_variation: float = 0.2
## Streak length, in seconds of motion.
@export_range(0.0, 0.2, 0.001) var drop_length: float = 0.055
@export_range(0.001, 0.2, 0.001) var drop_width: float = 0.014
@export var color: Color = Color(0.74, 0.79, 0.86, 0.55)
## Self-illumination, so rain still reads in dark scenes.
@export_range(0.0, 4.0, 0.01) var emission: float = 0.25

@export_group("Ground")
## Height of the ground where ripples and splashes appear.
@export var ground_height: float = 0.0
## Find the ground under the camera with a physics ray instead of using ground_height.
@export var ground_from_raycast: bool = false
@export_flags_3d_physics var ground_mask: int = 1
## Radius around the camera with ripples and splashes.
@export_range(1.0, 60.0, 0.1) var splash_radius: float = 9.0
@export var ripples: bool = true:
	set(value):
		ripples = value
		_update_flags()
@export_range(0, 6000, 1) var max_ripples: int = 700:
	set(value):
		max_ripples = value
		_rebuild_meshes()
@export_range(0.05, 3.0, 0.01) var ripple_size: float = 0.45
@export var splashes: bool = true:
	set(value):
		splashes = value
		_update_flags()
@export_range(0, 6000, 1) var max_splashes: int = 500:
	set(value):
		max_splashes = value
		_rebuild_meshes()
@export_range(0.05, 3.0, 0.01) var splash_size: float = 0.22
@export var splash_color: Color = Color(0.78, 0.83, 0.9, 0.4)

var _offset: Vector3 = Vector3.ZERO
var _drops: ShaderMaterial
var _ripples: ShaderMaterial
var _splashes: ShaderMaterial
var _ground_y: float = 0.0


func _class_defaults() -> Dictionary:
	return {&"area_size": Vector3(24.0, 14.0, 24.0)}


func _build() -> void:
	_drops = make_layer(PRECIP_SHADER, NimbluxMeshes.quads(max_drops), 1)
	_ripples = make_layer(SPLASH_SHADER, NimbluxMeshes.quads(maxi(max_ripples, 1)), 0)
	_ripples.set_shader_parameter("mode", 0)
	_splashes = make_layer(SPLASH_SHADER, NimbluxMeshes.quads(maxi(max_splashes, 1)), 1)
	_splashes.set_shader_parameter("mode", 1)
	_update_flags()


func _rebuild_meshes() -> void:
	if not _drops:
		return
	set_layer_mesh(_drops, NimbluxMeshes.quads(max_drops))
	set_layer_mesh(_ripples, NimbluxMeshes.quads(maxi(max_ripples, 1)))
	set_layer_mesh(_splashes, NimbluxMeshes.quads(maxi(max_splashes, 1)))
	_update_flags()


func _update_flags() -> void:
	if not _drops:
		return
	set_layer_enabled(_ripples, ripples and max_ripples > 0)
	set_layer_enabled(_splashes, splashes and max_splashes > 0)


func _tick(delta: float) -> void:
	var ws: float = world_scale()
	var a: float = effective_amount()
	var vel: Vector3 = Vector3(0.0, -fall_speed * ws, 0.0)
	_offset += vel * delta
	if _offset.length_squared() > 1.0e8:
		_offset = Vector3.ZERO
	_ground_y = _find_ground()

	_drops.set_shader_parameter("area_size", area_size * ws)
	_drops.set_shader_parameter("offset", _offset)
	_drops.set_shader_parameter("velocity", vel)
	_drops.set_shader_parameter("amount", a)
	_drops.set_shader_parameter("size", drop_width * ws)
	_drops.set_shader_parameter("speed_variation", speed_variation)
	_drops.set_shader_parameter("size_variation", 0.35)
	_drops.set_shader_parameter("stretch", drop_length * lerpf(0.75, 1.0, a))
	_drops.set_shader_parameter("color", color)
	_drops.set_shader_parameter("emission", emission)
	_drops.set_shader_parameter("near_fade", 0.5 * ws)

	for m: ShaderMaterial in [_ripples, _splashes]:
		m.set_shader_parameter("radius", splash_radius * ws)
		m.set_shader_parameter("ground_height", _ground_y)
		m.set_shader_parameter("amount", a)
		m.set_shader_parameter("color", splash_color)
		m.set_shader_parameter("emission", emission)
	_ripples.set_shader_parameter("size", ripple_size * ws)
	_ripples.set_shader_parameter("rate", 1.4)
	_splashes.set_shader_parameter("size", splash_size * ws)
	_splashes.set_shader_parameter("rate", 1.1)


func _find_ground() -> float:
	if not ground_from_raycast or Engine.is_editor_hint() or not is_inside_tree():
		return ground_height
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	if space == null:
		return ground_height
	var from: Vector3 = _center + Vector3.UP * 2.0
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 200.0, ground_mask)
	var hit: Dictionary = space.intersect_ray(q)
	if hit.is_empty():
		return ground_height
	var pos: Vector3 = hit["position"]
	return pos.y
