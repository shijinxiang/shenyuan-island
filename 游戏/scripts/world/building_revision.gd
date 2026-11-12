extends RefCounted
const Utility=preload("res://scripts/core/island_static_setup.gd")
const CABIN_POSITION:=Vector3(117.5,4.0,102.0)
const CABIN_YAW:=.657

static func add_collision(building:Node3D,scene:Node3D) -> void:
	for mesh in Utility.meshes(building):
		var ancestor:Node=mesh
		var movable:=false
		while ancestor!=building and ancestor:
			if String(ancestor.name).begins_with("Door_"):
				movable=true
				break
			ancestor=ancestor.get_parent()
		if movable:
			if mesh!=ancestor:continue
			var body:=AnimatableBody3D.new()
			body.name="DoorCollision"
			body.sync_to_physics=false
			mesh.add_child(body)
			var shape:=CollisionShape3D.new()
			var box:=BoxShape3D.new()
			var bounds:=mesh.mesh.get_aabb()
			box.size=bounds.size.max(Vector3(.04,.04,.04))
			shape.shape=box
			shape.position=bounds.get_center()
			body.add_child(shape)
			Utility.own_tree(body,scene)
		else:
			if mesh.name.contains("FishingDetails") or mesh.name.contains("TimberCladding"):continue
			var body:=StaticBody3D.new()
			body.name="StructureCollision"
			mesh.add_child(body)
			var shape:=CollisionShape3D.new()
			shape.shape=mesh.mesh.create_trimesh_shape()
			body.add_child(shape)
			Utility.own_tree(body,scene)
	var doors:=Node.new()
	doors.name="DoorControls"
	doors.set_script(load("res://scripts/world/building_doors.gd"))
	building.add_child(doors)
	doors.owner=scene

static func install_cabin(scene:Node3D) -> void:
	if scene.get_meta("new_fishing_cabin",false):return
	var island:Node3D=scene.get_node("Island")
	var old:=island.find_child("B01*",true,false)
	if old:old.free()
	for body in scene.find_children("Collision_B01*","StaticBody3D",true,false):body.free()
	var cabin:Node3D=Utility.local_model("res://assets/optimized/B01_fishing.glb")
	cabin.name="B01_FishingCabin"
	island.add_child(cabin)
	cabin.position=CABIN_POSITION
	cabin.rotation.y=CABIN_YAW
	cabin.set_meta("asset_id","B01")
	for mesh in Utility.meshes(cabin):mesh.visibility_range_end=1600.
	Utility.own_tree(cabin,scene)
	add_collision(cabin,scene)
	var ramp:=StaticBody3D.new()
	ramp.name="EntryWalkRamp"
	cabin.add_child(ramp)
	var collision:=CollisionShape3D.new()
	var shape:=ConvexPolygonShape3D.new()
	shape.points=PackedVector3Array([
		Vector3(-1.73,0.,6.00),Vector3(.23,0.,6.00),Vector3(-1.73,0.,5.05),Vector3(.23,0.,5.05),
		Vector3(-1.73,.05,6.00),Vector3(.23,.05,6.00),Vector3(-1.73,.67,5.05),Vector3(.23,.67,5.05)])
	collision.shape=shape
	ramp.add_child(collision)
	Utility.own_tree(ramp,scene)
	for specification in [["BedZone",Vector3(-2.4,.65,-1.55),Vector2(1.3,1.95)],["TableZone",Vector3(1.7,.65,0),Vector2(1.9,1.3)],["ChestZone",Vector3(.1,.65,-2.25),Vector2(1.4,.6)],["PaintingZone",Vector3(1.7,2.15,-2.74),Vector2(1.5,.8)]]:
		var marker:=Marker3D.new()
		marker.name=specification[0]
		marker.position=specification[1]
		marker.set_meta("reserved_size",specification[2])
		cabin.add_child(marker)
		marker.owner=scene
	var light:=OmniLight3D.new()
	light.name="InteriorWarmFill"
	light.position=Vector3(0,2.8,0)
	light.light_color=Color("ffe6bd")
	light.light_energy=.45
	light.omni_range=7.
	cabin.add_child(light)
	light.owner=scene
	scene.set_meta("new_fishing_cabin",true)

static func install_warehouse(scene:Node3D) -> void:
	for actor in scene.get_node("AllIslandStatic").get_children():
		if actor.get_meta("asset_id","")!="B02":continue
		if not actor.has_node("DoorControls"):add_collision(actor,scene)
		actor.set_meta("interactive_warehouse",true)

static func setup(scene:Node3D) -> void:
	install_cabin(scene)
	install_warehouse(scene)
	repair_cabin_entry(scene)

static func repair_cabin_entry(scene:Node3D) -> void:
	var cabin:=scene.get_node("Island/B01_FishingCabin") as Node3D
	var ramp:=cabin.get_node_or_null("EntryWalkRamp") as StaticBody3D
	if ramp==null:
		ramp=StaticBody3D.new()
		ramp.name="EntryWalkRamp"
		cabin.add_child(ramp)
	for child in ramp.get_children():child.free()
	var shape:=ConvexPolygonShape3D.new()
	shape.points=PackedVector3Array([
		Vector3(-1.70,-.04,6.70),Vector3(.20,-.04,6.70),Vector3(-1.70,-.04,5.0),Vector3(.20,-.04,5.0),
		Vector3(-1.70,.01,6.70),Vector3(.20,.01,6.70),Vector3(-1.70,.67,5.35),Vector3(.20,.67,5.35),
		Vector3(-1.70,.67,5.0),Vector3(.20,.67,5.0)])
	var collision:=CollisionShape3D.new();collision.shape=shape;ramp.add_child(collision)
	if not cabin.has_node("EntryBoardwalk"):
		var boards:=Node3D.new();boards.name="EntryBoardwalk";cabin.add_child(boards)
		var material:=StandardMaterial3D.new();material.albedo_color=Color(.39,.245,.12);material.roughness=.88
		var length:=Vector2(1.35,.66).length()
		for index in 4:
			var plank:=MeshInstance3D.new();var mesh:=BoxMesh.new();mesh.size=Vector3(.455,.055,length)
			plank.mesh=mesh;plank.material_override=material;plank.position=Vector3(-1.46+index*.47,.316,6.025)
			plank.rotation.x=atan2(.66,1.35);boards.add_child(plank)
	if not cabin.has_node("CabinAccess"):
		var access:=Node.new();access.name="CabinAccess";access.set_script(preload("res://scripts/world/cabin_access.gd"));cabin.add_child(access)
