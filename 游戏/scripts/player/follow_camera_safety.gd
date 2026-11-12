extends RefCounted

const CAMERA_LAYER:=128
const Utility=preload("res://scripts/core/island_static_setup.gd")
const GROUND_CLEARANCE := .18
var player:CharacterBody3D

func _init(actor:CharacterBody3D) -> void:
	player=actor

static func add_camera_occluders(scene:Node3D) -> void:
	if scene.has_node("CameraOccluders"):return
	var group:=Node3D.new()
	group.name="CameraOccluders"
	scene.add_child(group)
	var vegetation:=scene.get_node_or_null("AllIslandStatic")
	if vegetation==null:return
	for actor:Node3D in vegetation.get_children():
		if actor.get_meta("category","")!="tree":continue
		var bounds:=Utility.bounds(actor)
		var code:String=actor.get_meta("asset_id","")
		var fraction:=.35
		if code in ["V03","V04","TP35","TP36","TP37","TP38"]:fraction=.68
		elif "Spruce" in code or "Pine" in code: fraction=.15
		var bottom:=bounds.position.y+bounds.size.y*fraction
		var crown:=AABB(Vector3(bounds.position.x,bottom,bounds.position.z),Vector3(bounds.size.x,bounds.end.y-bottom,bounds.size.z)).grow(.12)
		var body:=StaticBody3D.new()
		body.name=String(actor.name)+"_CameraCrown"
		body.collision_layer=CAMERA_LAYER
		body.collision_mask=0
		body.position=crown.get_center()
		var shape:=BoxShape3D.new()
		shape.size=crown.size
		var collision:=CollisionShape3D.new()
		collision.shape=shape
		body.add_child(collision)
		group.add_child(body)

func _floor_height(point: Vector3) -> float:
	var wildlife := player.get_parent().get_node_or_null("IslandWildlife")
	var height: float = wildlife.ground.height(point.x, point.z) if wildlife else 0.0
	if not (player.swimming and player.swim_depth > .6):
		height = maxf(height, player.water_level)
	var ceiling: float = player.global_position.y + .3
	if point.y >= ceiling + GROUND_CLEARANCE or height >= ceiling:
		return height
	var excluded: Array[RID] = [player.get_rid()]
	if is_instance_valid(player.rowing) and player.rowing.boarded:
		excluded.append(player.rowing.get_rid())
	if player.in_vehicle():
		excluded.append(player.vehicle.get_rid())
	for attempt in 8:
		var query := PhysicsRayQueryParameters3D.create(Vector3(point.x,ceiling,point.z), Vector3(point.x,height-.05,point.z), 1, excluded)
		var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty():
			break
		var node: Node = hit.collider
		var platform := false
		while node and node != player.get_parent():
			var code: String = str(node.get_meta("asset_id", ""))
			var name := String(node.name)
			if node.get_meta("category", "") == "building" or code.begins_with("B") or code in ["P01","P03"] or name.ends_with("DeckCollision") or name.begins_with("B0") or name.begins_with("Collision_B") or name.begins_with("Collision_P01") or name.begins_with("Collision_P03"):
				platform = true
				break
			node = node.get_parent()
		if platform and hit.normal.y > .65:
			height = maxf(height, hit.position.y)
			break
		excluded.append(hit.rid)
	return height

func _clearance(position: Vector3, basis: Basis, camera: Camera3D, half_size: Vector2) -> float:
	var clearance := position.y - _floor_height(position) - GROUND_CLEARANCE
	var center := position - basis.z * camera.near
	for x in [-1.0,0.0,1.0]:
		for y in [-1.0,0.0,1.0]:
			var point: Vector3 = center + basis.x * half_size.x * x + basis.y * half_size.y * y
			clearance = minf(clearance, point.y - _floor_height(point) - .035)
	return clearance

func update(_delta:float) -> void:
	var camera:Camera3D=player.camera
	if not camera.is_current():return
	var arm:SpringArm3D=player.arm
	var pivot:Vector3=player.orbit.global_position
	var basis:=arm.global_basis.orthonormalized()
	var distance: float = 22.0 if camera.projection == Camera3D.PROJECTION_ORTHOGONAL else player.third_distance
	var half_size := camera.get_camera_projection().get_viewport_half_extents()
	var clearance := _clearance(pivot + basis.z * distance, basis, camera, half_size)
	if clearance < 0:
		if camera.projection == Camera3D.PROJECTION_ORTHOGONAL and basis.z.y > .001:
			# Orthographic scale stays constant while its near plane clears the terrain.
			for attempt in 12:
				distance += (-clearance + .01) / basis.z.y
				clearance = _clearance(pivot + basis.z * distance, basis, camera, half_size)
				if clearance >= 0:
					break
		else:
			var origin_clearance := _clearance(pivot, basis, camera, half_size)
			if origin_clearance < 0:
				pivot.y -= origin_clearance - .01
			var safe := 0.0
			var blocked := distance
			for attempt in 14:
				var middle := (safe + blocked) * .5
				if _clearance(pivot + basis.z * middle, basis, camera, half_size) >= 0:
					safe = middle
				else:
					blocked = middle
			distance = safe
	arm.collision_mask=0
	arm.spring_length = distance
	camera.global_transform = Transform3D(basis, pivot + basis.z * distance)
