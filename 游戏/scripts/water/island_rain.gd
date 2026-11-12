extends "res://addons/nimblux_fx/nodes_3d/nimblux_rain_3d.gd"

var horizontal_wind := Vector3.ZERO
var water_material: ShaderMaterial
var surface_bound := false

func _build() -> void:
	super._build()
	_drops.shader = preload("res://shaders/weather_rain_precip.gdshader")
	_ripples.shader = preload("res://shaders/weather_rain_splash.gdshader")
	_splashes.shader = preload("res://shaders/weather_rain_splash.gdshader")
	_ripples.set_shader_parameter("mode", 0)
	_splashes.set_shader_parameter("mode", 1)
	for domain in ["global", "local"]:
		var bytes := FileAccess.get_file_as_bytes("res://assets/generated/shallow_water/" + domain + "_terrain.bin")
		var texture := ImageTexture.create_from_image(Image.create_from_data(384, 384, false, Image.FORMAT_RGBAF, bytes))
		for material in [_drops, _ripples, _splashes]:
			material.set_shader_parameter("rain_ground" if domain == "global" else "rain_local_ground", texture)

func _tick(delta: float) -> void:
	if not surface_bound and water_material and water_material.get_shader_parameter("swe_ready"):
		for material in [_drops,_splashes]:
			for parameter in ["swe_global_state","swe_global_terrain","swe_local_state","swe_local_terrain","swe_ready"]:
				material.set_shader_parameter(parameter,water_material.get_shader_parameter(parameter))
		surface_bound=true
	_offset += horizontal_wind * delta
	super._tick(delta)
	_drops.set_shader_parameter("velocity", horizontal_wind + Vector3(0, -fall_speed, 0))
