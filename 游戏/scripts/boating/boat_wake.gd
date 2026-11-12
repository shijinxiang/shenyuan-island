extends Node3D
var vessel:Node3D
var mesh:=ImmediateMesh.new()
var material:=ShaderMaterial.new()
var history:Array[Dictionary]=[]
var sample_timer:=0.0
var spray_timer:=0.0

func _ready() -> void:
	vessel=get_parent()
	top_level=true
	global_transform=Transform3D.IDENTITY
	material.shader=preload("res://shaders/boat_foam.gdshader")
	material.render_priority=7
	var visual:=MeshInstance3D.new();visual.mesh=mesh;visual.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(visual)

func _vertex(point:Vector3,uv:Vector2,alpha:float) -> void:
	mesh.surface_set_uv(uv);mesh.surface_set_color(Color(1,1,1,alpha));mesh.surface_add_vertex(point)

func _strip(left:Array[Vector3],right:Array[Vector3],alphas:Array[float]) -> void:
	for i in range(left.size()-1):
		_vertex(left[i],Vector2(0,0),alphas[i]);_vertex(right[i],Vector2(1,0),alphas[i]);_vertex(left[i+1],Vector2(0,1),alphas[i+1])
		_vertex(right[i],Vector2(1,0),alphas[i]);_vertex(right[i+1],Vector2(1,1),alphas[i+1]);_vertex(left[i+1],Vector2(0,1),alphas[i+1])

func _process(delta:float) -> void:
	var water:Node=vessel.water
	if water.water_material:
		for key in ["swe_global_state","swe_global_terrain","swe_local_state","swe_local_terrain","swe_ready"]:material.set_shader_parameter(key,water.water_material.get_shader_parameter(key))
		material.set_shader_parameter("daylight",water.water_material.get_shader_parameter("weather_daylight"))
	var speed:=absf(vessel.drive_speed)
	for point in history:point.age+=delta
	history=history.filter(func(point):return point.age<4.5)
	sample_timer-=delta;spray_timer-=delta
	var forward:Vector3=vessel.global_basis.z
	var across:Vector3=vessel.global_basis.x
	var center:Vector3=vessel.global_position
	if speed>.5 and sample_timer<=0:
		sample_timer=.10
		history.push_front({"position":center-forward*1.85,"right":across,"age":0.0,"strength":clampf(speed/5.,.1,1.)})
	if speed>1.0 and spray_timer<=0:
		spray_timer=.28
		for side in [-1,1]:
			var bow:Vector3=center+forward*1.7+across*.85*float(side);bow.y=water.boat_elevation+.04
			vessel.player.get_node("MovementVFX")._spawn_water(bow,.45+speed*.035)
	mesh.clear_surfaces()
	if history.size()<2 and speed<.5:return
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES,material)
	var left:Array[Vector3]=[];var right:Array[Vector3]=[];var alpha:Array[float]=[]
	for point in history:
		var width:=.3+float(point.age)*.32
		left.append(Vector3(point.position)-Vector3(point.right)*width);right.append(Vector3(point.position)+Vector3(point.right)*width)
		alpha.append((1.-float(point.age)/4.5)*float(point.strength)*.65)
	_strip(left,right,alpha)
	if speed>.5:
		for side in [-1.0,1.0]:
			left=[];right=[];alpha=[]
			for i in 7:
				var t:=float(i)/6.
				var path:Vector3=center+forward*(2.05-t*2.6)+across*side*(.25+t*1.3)
				left.append(path-across*.12);right.append(path+across*.22);alpha.append(sin(t*PI)*clampf(speed/4.,0.,1.)*.8)
			_strip(left,right,alpha)
	mesh.surface_end()
