extends RefCounted
const Utility=preload("res://scripts/core/island_static_setup.gd")
const PALMS=["V03","V04","TP35","TP36","TP37","TP38"]
static func setup(scene:Node3D) -> void:
	clear_structures(scene)
	if scene.get_meta("coastal_palms_settled",false):return
	for actor in scene.get_node("CoastalDressing").get_children():
		var code:=String(actor.name).substr(0,3)
		if code.begins_with("V") or code in ["R01","R02","R03","R04","F01","F02","T05","T06","T07"]:actor.free()
	var coast:Array=JSON.parse_string(FileAccess.get_file_as_string("res://assets/generated/outer_coast.json"))
	var inner:Array=JSON.parse_string(FileAccess.get_file_as_string("res://assets/generated/inner_coast.json"))
	var audit:Array=[]
	for actor in scene.get_node("AllIslandStatic").get_children():
		var code:String=actor.get_meta("asset_id","")
		if not code in PALMS:continue
		var foot:Vector3=actor.get_meta("ground_position")
		var shoreline:Array=inner if actor.get_meta("layout_group","")=="lagoon_palms" else coast
		var distance:=INF
		for index in range(shoreline.size()-1):
			var a:=Vector2(shoreline[index][0],shoreline[index][1])
			var b:=Vector2(shoreline[index+1][0],shoreline[index+1][1])
			var point:=Vector2(foot.x,foot.z)
			var closest:=Geometry2D.get_closest_point_to_segment(point,a,b)
			distance=minf(distance,point.distance_to(closest))
		audit.append({"name":actor.name,"code":code,"distance_m":distance,"ground_height_m":foot.y,"group":actor.get_meta("layout_group","")})
	scene.set_meta("coastal_palms_settled",true)
	var report_path := "res://../整理记录/运行诊断/棕榈位置核验.json" if OS.has_feature("editor") else "user://diagnostics/palm_positions.json"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(report_path.get_base_dir()))
	var report_file := FileAccess.open(report_path,FileAccess.WRITE)
	if report_file:report_file.store_string(JSON.stringify(audit,"  "))

static func clear_structures(scene:Node3D) -> void:
	var structure:=scene.get_node_or_null("LighthouseBreakwater") as Node3D
	var vegetation:=scene.get_node_or_null("AllIslandStatic")
	if structure==null or vegetation==null:return
	var points:=PackedVector2Array()
	for mesh in Utility.meshes(structure):
		var transform:=Utility.world_transform(mesh)
		for corner in 8:
			var point:Vector3=transform*mesh.get_aabb().get_endpoint(corner)
			points.append(Vector2(point.x,point.z))
	var hull:=Geometry2D.convex_hull(points)
	var expanded:=Geometry2D.offset_polygon(hull,1.5)
	if not expanded.is_empty():hull=expanded[0]
	var removed:=0
	for actor in vegetation.get_children():
		if not String(actor.get_meta("asset_id","")) in PALMS:continue
		var foot:Vector3=actor.get_meta("ground_position",actor.position)
		if Geometry2D.is_point_in_polygon(Vector2(foot.x,foot.z),hull):
			actor.free()
			removed+=1
	if removed>0:print("BREAKWATER_PALMS_REMOVED ",removed)
