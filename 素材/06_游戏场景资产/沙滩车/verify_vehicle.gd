extends SceneTree
const SOURCE := "D:/浪费GPT额度/小温的游戏/素材/06_游戏场景资产/沙滩车/"
const MODEL := "D:/浪费GPT额度/小温的游戏/游戏/assets/vehicle/beach_buggy.glb"
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	assert(doc.append_from_file(MODEL,state)==OK)
	var instance := doc.generate_scene(state)
	root.add_child(instance)
	var box := AABB()
	var first := true
	var surfaces := 0
	var triangles := 0
	var nodes := {}
	for m: MeshInstance3D in instance.find_children("*","MeshInstance3D",true,false):
		var mb: AABB = m.global_transform*m.get_aabb()
		box=mb if first else box.merge(mb)
		first=false
		for s in range(m.mesh.get_surface_count()):
			var arr:=m.mesh.surface_get_arrays(s)
			assert(arr[Mesh.ARRAY_TEX_UV]!=null)
			assert(m.mesh.surface_get_material(s)!=null)
			surfaces+=1
			triangles+=arr[Mesh.ARRAY_INDEX].size()/3
	for name in ["Wheel_FL","Wheel_FR","Wheel_RL","Wheel_RR","Steer_L","Steer_R","SteeringWheel","DriverSeat","SeatPelvis","EntryPoint","ExitPoint","HandGripL","HandGripR"]:
		var node := instance.find_child(name,true,false) as Node3D
		assert(node!=null,"Missing node "+name)
		nodes[name]={"path":str(instance.get_path_to(node)),"position":[node.global_position.x,node.global_position.y,node.global_position.z]}
	var report := {"passed":true,"triangles":triangles,"surfaces":surfaces,"aabb_min":[box.position.x,box.position.y,box.position.z],"size_x_y_z":[box.size.x,box.size.y,box.size.z],"nodes":nodes}
	FileAccess.open(SOURCE+"godot_vehicle_validation.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("VEHICLE_MODEL_VALIDATED ",JSON.stringify(report))
	instance.free()
	quit()
