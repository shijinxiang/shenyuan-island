extends RefCounted

const Utility=preload("res://scripts/core/island_static_setup.gd")
var groups:Dictionary={}
var members:Array[Dictionary]=[]
var global_bed:PackedFloat32Array
var local_bed:PackedFloat32Array
var obstacles:Array[Vector4]=[]
var obstacle_cells:Dictionary={}
var timer:=0.0
var elapsed:=0.0
var rng:=RandomNumberGenerator.new()

func _init(world:Node3D) -> void:
	rng.seed=6110615
	global_bed=FileAccess.get_file_as_bytes("res://assets/generated/shallow_water/global_terrain.bin").to_float32_array()
	local_bed=FileAccess.get_file_as_bytes("res://assets/generated/shallow_water/local_terrain.bin").to_float32_array()
	for actor in world.get_node("AllIslandStatic").get_children():
		if actor.get_meta("category","")!="large_rock":continue
		var foot:Vector3=actor.get_meta("ground_position",actor.position)
		if foot.y>.1:continue
		_add_obstacle(Utility.bounds(actor))
	var extra:=world.get_node_or_null("NearshoreEnrichment")
	if extra:
		for body:StaticBody3D in extra.find_children("*","StaticBody3D",true,false):
			var shape:CollisionShape3D=body.get_child(0)
			_add_obstacle(body.global_transform*shape.transform*shape.shape.get_debug_mesh().get_aabb())

func _add_obstacle(bounds:AABB) -> void:
	var center:=bounds.get_center()
	var radius:=maxf(bounds.size.x,maxf(bounds.size.y,bounds.size.z))*.52
	var index:=obstacles.size()
	obstacles.append(Vector4(center.x,center.y,center.z,radius))
	var low:=(Vector2(center.x-radius,center.z-radius)/4.).floor()
	var high:=(Vector2(center.x+radius,center.z+radius)/4.).floor()
	for x in range(int(low.x),int(high.x)+1):
		for z in range(int(low.y),int(high.y)+1):
			var key:=Vector2i(x,z)
			if not obstacle_cells.has(key):obstacle_cells[key]=[]
			obstacle_cells[key].append(index)

func register(animal:Dictionary,entry:Dictionary) -> void:
	var key:String=entry.school_key
	if not groups.has(key):
		groups[key]={"curve":animal.curve,"distance":float(animal.distance),"zone":entry.zone,"members":[]}
	var group:Dictionary=groups[key]
	animal.curve=group.curve
	animal.school=key
	animal.school_velocity=Vector3.ZERO
	animal.wander=rng.randf_range(0,TAU)
	animal.max_speed=rng.randf_range(.85,1.20)
	animal.zone=entry.zone
	var curve:Curve3D=group.curve
	var center:=curve.sample_baked(group.distance,true)
	var position:=center
	for attempt in 100:
		var spread:=1.5+float(attempt)*.055
		var candidate:=center+Vector3(rng.randf_range(-spread,spread),rng.randf_range(-.25,.25),rng.randf_range(-spread,spread))
		if safe(candidate,entry.zone):
			position=candidate
			break
	animal.node.position=position
	var forward:=curve.sample_baked(fposmod(float(group.distance)+1.0,curve.get_baked_length()),true)-center
	animal.school_velocity=forward.normalized()*.6
	group.members.append(animal)
	members.append(animal)

func column(point:Vector3) -> Vector2:
	var local:=point.x>88 and point.x<216 and point.z>72 and point.z<200
	var uv:=(Vector2(point.x,point.z)-Vector2(88,72))/128.0 if local else (Vector2(point.x,point.z)+Vector2(400,400))/800.0
	var x:=clampi(int(uv.x*384),0,383)
	var z:=clampi(int(uv.y*384),0,383)
	var index:=(z*384+x)*4
	return Vector2(local_bed[index],local_bed[index+3]) if local else Vector2(global_bed[index],global_bed[index+3])

func rock_avoidance(point:Vector3) -> Vector3:
	var force:=Vector3.ZERO
	var key:=Vector2i(floori(point.x/4.),floori(point.z/4.))
	for x in range(-1,2):
		for z in range(-1,2):
			for index in obstacle_cells.get(key+Vector2i(x,z),[]):
				var rock:=obstacles[index]
				var away:=point-Vector3(rock.x,rock.y,rock.z)
				var distance:=away.length()
				if distance<rock.w+.7 and distance>.001:force+=away/distance*(rock.w+.7-distance)*2.2
	return force

func safe(point:Vector3,zone:String) -> bool:
	var bed:=column(point)
	if bed.x>-.65 or point.y<bed.x+.16 or point.y>-.25:return false
	if (zone=="lake" and bed.y<.55) or (zone=="ocean" and bed.y>.45):return false
	var key:=Vector2i(floori(point.x/4.),floori(point.z/4.))
	for index in obstacle_cells.get(key,[]):
		var rock:=obstacles[index]
		if point.distance_to(Vector3(rock.x,rock.y,rock.z))<rock.w+.12:return false
	return true

func update(delta:float,player_position:Vector3) -> void:
	elapsed+=delta
	timer+=delta
	for group:Dictionary in groups.values():
		var curve:Curve3D=group.curve
		group.distance=fposmod(float(group.distance)+delta*.65,curve.get_baked_length())
	if timer>=.1:
		_steer(minf(timer,.2),player_position)
		timer=0.0
	for animal in members:
		if animal.get("caught",false):continue
		var actor:Node3D=animal.node
		var velocity:Vector3=animal.school_velocity
		var next:=actor.position+velocity*delta
		if safe(next,animal.zone):actor.position=next
		else:
			var group:Dictionary=groups[animal.school]
			var target:Vector3=group.curve.sample_baked(group.distance,true)
			var side:=Vector3(velocity.z,0,-velocity.x).normalized()*.65
			if side.dot(target-actor.position)<0:side=-side
			if safe(actor.position+side*delta,animal.zone):animal.school_velocity=side
			elif safe(actor.position-side*delta,animal.zone):animal.school_velocity=-side
			else:animal.school_velocity=-velocity*.6
		if velocity.length_squared()>.001:
			actor.rotation.y=lerp_angle(actor.rotation.y,atan2(-velocity.x,-velocity.z),1.0-exp(-delta*7.0))
			actor.rotation.x=lerpf(actor.rotation.x,atan2(velocity.y,Vector2(velocity.x,velocity.z).length()),1.0-exp(-delta*5.0))
		if animal.animator:animal.animator.speed_scale=clampf(.7+velocity.length()*.55,.7,1.5)

func _steer(delta:float,player_position:Vector3) -> void:
	var grid:Dictionary={}
	for animal in members:
		if animal.get("caught",false):continue
		var p:Vector3=animal.node.position
		var key:=Vector3i(floori(p.x/2.5),floori(p.y/2.5),floori(p.z/2.5))
		if not grid.has(key):grid[key]=[]
		grid[key].append(animal)
	var new_velocities:Array[Vector3]=[]
	for animal in members:
		if animal.get("caught",false):
			new_velocities.append(Vector3.ZERO)
			continue
		var position:Vector3=animal.node.position
		var velocity:Vector3=animal.school_velocity
		var separation:=Vector3.ZERO
		var alignment:=Vector3.ZERO
		var center:=Vector3.ZERO
		var count:=0
		var key:=Vector3i(floori(position.x/2.5),floori(position.y/2.5),floori(position.z/2.5))
		for x in range(-1,2):
			for y in range(-1,2):
				for z in range(-1,2):
					for neighbor:Dictionary in grid.get(key+Vector3i(x,y,z),[]):
						if neighbor.node==animal.node:continue
						var away:Vector3=position-neighbor.node.position
						var distance:=away.length()
						if distance<.7 and distance>.001:separation+=away/distance*(.7-distance)*2.5
						if neighbor.school==animal.school and distance<3.5:
							alignment+=Vector3(neighbor.school_velocity)
							center+=Vector3(neighbor.node.position)
							count+=1
		var group:Dictionary=groups[animal.school]
		var curve:Curve3D=group.curve
		var goal:=curve.sample_baked(fposmod(float(group.distance)+2.0,curve.get_baked_length()),true)
		var force:Vector3=separation*1.9+(goal-position).limit_length(2.5)*.55
		if count>0:force+=(alignment/count-velocity)*.8+(center/count-position)*.42
		if animal.has("fishing_target"):
			goal=animal.fishing_target
			force=(goal-position).limit_length(2.5)*1.2+separation*.5
		force+=rock_avoidance(position+velocity*.65)
		var away_player:=position-player_position
		if away_player.length()<3.4:force+=away_player.normalized()*(3.4-away_player.length())*1.1
		force+=Vector3(sin(elapsed*.6+animal.wander),sin(elapsed*.4+animal.wander)*.3,cos(elapsed*.7+animal.wander))*.12
		var bed:=column(position)
		if position.y<bed.x+.45:force.y+=(bed.x+.45-position.y)*4.0
		if position.y>-.55:force.y-=maxf(0,position.y+.55)*4.0
		if not safe(position+velocity*.8,animal.zone):force+=(goal-position).normalized()*2.5
		var next_velocity:Vector3=(velocity+force.limit_length(3.0)*delta).limit_length(float(animal.max_speed))
		new_velocities.append(next_velocity)
	for index in members.size():members[index].school_velocity=new_velocities[index]
