extends RefCounted
static var material_cache:Dictionary={}

static func local_model(path:String) -> Node3D:
	var imported:Node3D=load(path).instantiate()
	var local:Node3D=imported.duplicate(Node.DUPLICATE_SIGNALS|Node.DUPLICATE_GROUPS|Node.DUPLICATE_SCRIPTS)
	imported.free()
	return local

static func meshes(node:Node) -> Array[MeshInstance3D]:
	var result:Array[MeshInstance3D]=[]
	if node is MeshInstance3D:result.append(node)
	for child in node.get_children():result.append_array(meshes(child))
	return result

static func world_transform(node:Node3D) -> Transform3D:
	var result:=node.transform
	var parent:=node.get_parent()
	while parent:
		if parent is Node3D:result=parent.transform*result
		parent=parent.get_parent()
	return result

static func bounds(node:Node3D) -> AABB:
	var result:=AABB()
	var first:=true
	for mesh in meshes(node):
		var box:=world_transform(mesh)*mesh.get_aabb()
		result=box if first else result.merge(box)
		first=false
	return result

static func own_tree(node:Node,scene:Node) -> void:
	node.scene_file_path=""
	node.owner=scene
	for child in node.get_children():own_tree(child,scene)

static func localize_scene(node:Node) -> void:
	# Explicitly owned nodes must be saved locally instead of instancing their GLB again.
	node.scene_file_path=""
	var last_by_name:Dictionary={}
	for child in node.get_children():last_by_name[String(child.name)]=child
	for child in node.get_children():
		if last_by_name[String(child.name)]!=child:
			node.remove_child(child)
			child.free()
	for child in node.get_children():localize_scene(child)

static func style(node:Node3D,category:String="") -> void:
	var code:String=node.get_meta("asset_id","")
	for mesh in meshes(node):
		mesh.visibility_range_end=1600. if category in ["tree","building","large_rock"] else 300.
		if code in ["V03","V04"]:mesh.lod_bias=1000000.
		if category in ["shell","coral","seaweed","bush","mushroom","forest_detail"]:
			mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for index in mesh.mesh.get_surface_count():
			var original:=mesh.get_active_material(index)
			if original is StandardMaterial3D:
				var key:=original.get_instance_id()
				if not material_cache.has(key):
					var material:=original.duplicate() as StandardMaterial3D
					material.roughness=maxf(material.roughness,.25 if material.transparency!=BaseMaterial3D.TRANSPARENCY_DISABLED else .78)
					material.metallic=minf(material.metallic,.12)
					material.metallic_specular=.22
					if code.begins_with("TP"):
						material.albedo_color=Color(1.05,1.18,1.03,1.)
					if code in ["V01","V02","V03","V04"]:
						material.albedo_color*=Color(.88,.90,.86,1.)
					if code.begins_with("MP_Coral"):
						var palette=["cb856a","c77d8f","e7a36d","9d8bb5","d27f65","75aaa3","c2ae86"]
						material.albedo_color=Color(palette[code.trim_prefix("MP_Coral").to_int()%palette.size()])
					if category=="seaweed":
						material.albedo_color=Color("54834d")
						material.cull_mode=BaseMaterial3D.CULL_DISABLED
					if code.begins_with("MP_Shell"):
						material.albedo_color=Color("dcc9a9")
					if code=="MP_StarFish":material.albedo_color=Color("dfa778")
					if code.begins_with("MP_Rock"):
						var palette=["7c8581","697a7d","969285"]
						material.albedo_color=Color(palette[code.trim_prefix("MP_Rock").to_int()%palette.size()])
					material_cache[key]=material
				mesh.set_surface_override_material(index,material_cache[key])

static func optimized_copy(old:Node3D,parent:Node3D,code:String,scene:Node3D) -> Node3D:
	var previous_box:=bounds(old)
	var object:Node3D=(load("res://assets/optimized/"+code+".glb") as PackedScene).instantiate()
	object.name=old.name
	parent.add_child(object)
	object.transform=old.transform
	var new_box:=bounds(object)
	object.scale*=previous_box.size.y/maxf(new_box.size.y,.0001)
	new_box=bounds(object)
	object.position+=Vector3(previous_box.get_center().x-new_box.get_center().x,previous_box.position.y-new_box.position.y,previous_box.get_center().z-new_box.get_center().z)
	object.set_meta("asset_id",code)
	object.set_meta("optimized",true)
	style(object,"tree" if code in ["V01","V02","V03","V04"] else "building" if code.begins_with("B") or code in ["P01","P03"] else "large_rock" if code.begins_with("R") or code=="P02" else "bush")
	old.free()
	own_tree(object,scene)
	return object

static func optimize_existing(scene:Node3D) -> void:
	if scene.get_meta("static_assets_optimized",false):return
	var old_island:Node3D=scene.get_node("Island")
	var clean_island:=Node3D.new()
	clean_island.name="OptimizedIsland"
	clean_island.transform=old_island.transform
	scene.add_child(clean_island)
	clean_island.owner=scene
	for child in old_island.get_children():
		if child.name.begins_with("TERRAIN") or child.name.begins_with("W02"):
			old_island.remove_child(child)
			child.owner=null
			clean_island.add_child(child)
			own_tree(child,scene)
		elif child.name.begins_with("B01") or child.name.begins_with("B03") or child.name.begins_with("P02"):
			optimized_copy(child,clean_island,String(child.name).substr(0,3),scene)
	old_island.free()
	clean_island.name="Island"
	var dressing:=scene.get_node("CoastalDressing")
	for child in dressing.get_children():
		var original_name:=String(child.name)
		var code:="C02" if original_name=="CoastalGull" else original_name.substr(0,3)
		var replacement:=optimized_copy(child,dressing,code,scene)
		replacement.name=original_name
	for pair in [["FishingPier","P01"],["LighthouseBreakwater","P03"]]:
		var original:Node3D=scene.get_node(pair[0])
		var replacement:=optimized_copy(original,scene,pair[1],scene)
		replacement.name=pair[0]
	var legacy:=scene.get_node_or_null("Landscape")
	if legacy:legacy.free()
	for body in scene.get_children():
		if body is StaticBody3D and (body.name.begins_with("Collision_B02") or body.name.ends_with("_Trunk")):
			body.free()
	scene.set_meta("static_assets_optimized",true)

static func setup(scene:Node3D) -> void:
	optimize_existing(scene)
	if not scene.has_node("AllIslandStatic"):
		var assets:Node3D=load("res://assets/library/all_island_static.scn").instantiate()
		assets.name="AllIslandStatic"
		scene.add_child(assets)
		assets.owner=scene
	if not scene.has_node("IslandTrails") and ResourceLoader.exists("res://assets/library/island_trails.scn"):
		var trails=load("res://assets/library/island_trails.scn").instantiate()
		scene.add_child(trails)
		trails.owner=scene

static func trim_grass(scene:Node3D,group:Node3D) -> Dictionary:
	var field:=scene.get_node("IslandGrass")
	var masks:Dictionary={}
	for actor in group.get_children():
		var position:Vector3=actor.get_meta("ground_position")
		if position.y<1.0:continue
		var radius:float=actor.get_meta("grass_clearance_radius")+.15
		var rect:Rect2=actor.get_meta("grass_clearance_box",Rect2(Vector2(position.x-radius,position.z-radius),Vector2.ONE*radius*2))
		var entry:={"position":Vector2(position.x,position.z),"radius":radius,"box":rect,"rectangular":actor.has_meta("grass_clearance_box")}
		var low:Vector2=(rect.position/20).floor()
		var high:Vector2=(rect.end/20).floor()
		for x in range(int(low.x),int(high.x)+1):
			for z in range(int(low.y),int(high.y)+1):
				var key:=Vector2i(x,z)
				if not masks.has(key):masks[key]=[]
				masks[key].append(entry)
	var before:=0
	var after:=0
	for chunk in field.get_children():
		var old:MultiMesh=chunk.multimesh
		before+=old.instance_count
		var key:=Vector2i(floori(chunk.position.x/20),floori(chunk.position.z/20))
		if not masks.has(key):
			after+=old.instance_count
			continue
		var data:=old.buffer
		var kept:=PackedFloat32Array()
		for index in old.instance_count:
			var point:=Vector2(data[index*16+3]+chunk.position.x,data[index*16+11]+chunk.position.z)
			var blocked:=false
			for mask in masks[key]:
				if (mask.box.has_point(point) if mask.rectangular else point.distance_squared_to(mask.position)<mask.radius*mask.radius):
					blocked=true
					break
			if not blocked:kept.append_array(data.slice(index*16,index*16+16))
		var replacement:MultiMesh=old.duplicate()
		replacement.instance_count=kept.size()/16
		replacement.buffer=kept
		chunk.multimesh=replacement
		after+=replacement.instance_count
	field.set_meta("instances",after)
	field.scene_file_path=""
	own_tree(field,scene)
	return {"before":before,"after":after,"cleared":before-after}

static func finish_ground(scene:Node3D) -> void:
	if scene.has_node("IslandGrass") and scene.has_node("AllIslandStatic") and not scene.get_meta("grass_static_trimmed",false):
		trim_grass(scene,scene.get_node("AllIslandStatic"))
		scene.set_meta("grass_static_trimmed",true)
