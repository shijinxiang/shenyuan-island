extends Node3D

const MODEL := "res://assets/survival/saltwater_crocodile.glb"
const BITE_TIME := .42
const CRAWL_STRIDE_SPEED := .5277778
var game: Node3D
var animals: Array[CharacterBody3D] = []
var actors: Array[Dictionary] = []
var west_beaches: Array[Vector3] = []
var coastline: Array[Vector3] = []
var record_timer := 0.0

func _ready() -> void:
	game = get_parent()
	var coast: Array = JSON.parse_string(FileAccess.get_file_as_string("res://assets/generated/outer_coast.json"))
	var west: Vector3 = -game.survival.east
	for point: Array in coast:
		var shore := Vector3(point[0], 0, point[1])
		shore -= shore.normalized() * 3.0
		shore.y = game.wildlife.ground.height(shore.x, shore.z)
		if shore.y > -.6 and shore.y < 2.2 and _outside_cabin(shore, 45):
			coastline.append(shore)
			if shore.normalized().dot(west) >= .7:
				west_beaches.append(shore)
	assert(not west_beaches.is_empty(), "No safe western beach for crocodiles")
	if not game.progress.has("crocodiles"):
		game.progress.crocodiles = []
		for index in 8:
			var beach_index := (west_beaches.size()/3 if index<3 else west_beaches.size()*2/3) + (index%3-1)*2
			if index>=6:
				beach_index = 0 if index==6 else west_beaches.size()-1
			var point: Vector3 = west_beaches[clampi(beach_index,0,west_beaches.size()-1)]
			game.progress.crocodiles.append({"id":"croc_" + str(index),"position":[point.x,point.y,point.z],"home":[point.x,point.y,point.z],"hp":3,"roamer":index >= 6,"yaw":0.0})
	for record: Dictionary in game.progress.crocodiles:
		if float(record.hp) > 0:
			_spawn(record)
	print("CROCODILES_READY western_group=", animals.size(), " cabin_safe_radius=30m")

func _outside_cabin(point: Vector3, radius := 32.0) -> bool:
	var offset: Vector3 = point - game.survival.cabin_center
	return Vector2(offset.x, offset.z).length() >= radius

func _spawn(record: Dictionary) -> void:
	var body := CharacterBody3D.new()
	body.name = str(record.id)
	body.collision_layer = 4
	body.collision_mask = 1 | 2
	body.floor_max_angle = deg_to_rad(45)
	body.floor_snap_length = .4
	add_child(body)
	var point := Vector3(record.position[0], record.position[1], record.position[2])
	if not _outside_cabin(point):
		point = west_beaches[0]
	body.global_position = point
	body.rotation.y = float(record.yaw)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(.75, .45, 1.7)
	collision.shape = shape
	collision.position = Vector3(0, .25, .05)
	body.add_child(collision)
	var model: Node3D = load(MODEL).instantiate()
	body.add_child(model)
	var animation: AnimationPlayer = model.find_children("*", "AnimationPlayer", true, false)[0]
	for clip in animation.get_animation_list():
		animation.get_animation(clip).loop_mode = Animation.LOOP_NONE if clip in ["Attack", "Death"] else Animation.LOOP_LINEAR
	animation.play("Idle")
	animals.append(body)
	actors.append({"body":body,"animation":animation,"record":record,"home":Vector3(record.home[0],record.home[1],record.home[2]),"destination":point,"decision":randf_range(.1,1.0),"attack":0.0,"bitten":false,"cooldown":0.0,"prey":{},"target_player":false,"flee":0.0})

func _choose_target(actor: Dictionary) -> void:
	var body: CharacterBody3D = actor.body
	actor.target_player = false
	actor.prey = {}
	var player_point: Vector3 = game.player.global_position
	if not game.dead and _outside_cabin(player_point, 31) and body.global_position.distance_to(player_point) < 11:
		actor.target_player = true
		actor.destination = player_point
		return
	var nearest := 12.0
	for animal: Dictionary in game.wildlife.fish:
		if animal.get("caught", false) or float(animal.fish_length) > 2.0:
			continue
		var point: Vector3 = animal.node.global_position
		var distance := body.global_position.distance_to(point)
		if distance < nearest and _outside_cabin(point):
			nearest = distance
			actor.prey = animal
			actor.destination = point
	if not actor.prey.is_empty():
		return
	if body.global_position.distance_to(actor.destination) < 2.0:
		var home: Vector3 = actor.home
		var point := home + Vector3(randf_range(-18,18),0,randf_range(-18,18))
		if bool(actor.record.roamer) and randf() < .4:
			point = coastline[randi() % coastline.size()]
		if _outside_cabin(point, 35):
			actor.destination = point

func _animate(actor: Dictionary, clip: String, rate := 1.0) -> void:
	var animation: AnimationPlayer = actor.animation
	if animation.current_animation != clip:
		animation.play(clip, .18)
	animation.speed_scale = rate

func _bite(actor: Dictionary) -> void:
	var body: CharacterBody3D = actor.body
	if actor.target_player:
		if body.global_position.distance_to(game.player.global_position) < 2.65 and _outside_cabin(game.player.global_position, 30) and _clear_bite(body, game.player.global_position):
			game.take_hit(body.global_position, "鳄鱼")
	elif not actor.prey.is_empty() and not actor.prey.get("caught", false):
		if body.global_position.distance_to(actor.prey.node.global_position) < 2.7 and _clear_bite(body, actor.prey.node.global_position):
			actor.prey.caught = true
			actor.prey.predated = true
			actor.prey.node.hide()
			actor.prey.erase("fishing_target")
			_animate(actor, "Eat")

func _clear_bite(body: CharacterBody3D, target: Vector3) -> bool:
	var mouth := body.global_position + Vector3.UP * .35 + body.global_basis.z * .9
	var query := PhysicsRayQueryParameters3D.create(mouth, target + Vector3.UP * .3, 1, [body.get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func _physics_process(delta: float) -> void:
	if game.cinematic_active:
		return
	for actor: Dictionary in actors:
		if float(actor.record.hp) <= 0:
			continue
		var body: CharacterBody3D = actor.body
		actor.cooldown = maxf(0.0, float(actor.cooldown) - delta)
		actor.flee = maxf(0.0, float(actor.flee) - delta)
		actor.decision = float(actor.decision) - delta
		if float(actor.attack) > 0.0:
			actor.attack = float(actor.attack) - delta
			if not actor.bitten and float(actor.attack) <= .9 - BITE_TIME:
				actor.bitten = true
				_bite(actor)
			body.velocity.x = 0
			body.velocity.z = 0
			continue
		if actor.decision <= 0:
			actor.decision = .65
			_choose_target(actor)
		if actor.target_player and _outside_cabin(game.player.global_position, 32):
			actor.destination = game.player.global_position
		elif not actor.prey.is_empty() and not actor.prey.get("caught", false):
			actor.destination = actor.prey.node.global_position
		var offset: Vector3 = actor.destination - body.global_position
		offset.y = 0
		var direction := offset.normalized()
		if actor.flee > 0:
			direction = (body.global_position - game.player.global_position).normalized()
			direction.y = 0
		var bed: float = game.wildlife.ground.height(body.global_position.x, body.global_position.z)
		var swimming := bed < -.35
		var speed := 1.15 if not swimming else 1.9
		if actor.target_player:
			speed = 1.6 if not swimming else 2.2
		if offset.length() < 1.0 and actor.flee <= 0:
			speed = 0
		if not _outside_cabin(body.global_position + direction * maxf(speed * delta, .5), 32):
			speed = 0
			actor.destination = actor.home
		body.velocity.x = direction.x * speed
		body.velocity.z = direction.z * speed
		if swimming:
			body.velocity.y = clampf((-.20 - body.global_position.y) * 5, -2, 2)
		else:
			body.velocity.y = 0 if body.is_on_floor() else body.velocity.y - 15 * delta
		body.move_and_slide()
		if not _outside_cabin(body.global_position, 30):
			var away: Vector3 = body.global_position - game.survival.cabin_center
			away.y = 0
			body.global_position = game.survival.cabin_center + away.normalized() * 32
			body.global_position.y = game.wildlife.ground.height(body.global_position.x, body.global_position.z)
		if speed > .01:
			body.rotation.y = lerp_angle(body.rotation.y, atan2(direction.x,direction.z), 1 - exp(-delta * 3))
		var actual_speed := Vector2(body.get_real_velocity().x, body.get_real_velocity().z).length()
		_animate(actor, "Swim" if swimming else "Crawl" if actual_speed > .05 else "Idle", 1.0 if swimming or actual_speed <= .05 else clampf(actual_speed / CRAWL_STRIDE_SPEED, .2, 3.1))
		if actor.cooldown <= 0 and (actor.target_player or not actor.prey.is_empty()) and offset.length() < 2.25 and body.global_basis.z.dot(direction) > .5:
			actor.attack = .9
			actor.bitten = false
			actor.cooldown = 2.7
			_animate(actor, "Attack")
	record_timer -= delta
	if record_timer <= 0:
		record_timer = 1.0
		for actor: Dictionary in actors:
			var point: Vector3 = actor.body.global_position
			actor.record.position = [point.x,point.y,point.z]
			actor.record.yaw = actor.body.rotation.y

func context() -> Dictionary:
	if not game.harpoon_equipped or game.capture_cooldown > 0 or game.player.rowing.boarded:
		return {}
	for actor: Dictionary in actors:
		if float(actor.record.hp) > 0 and actor.body.global_position.distance_to(game.player.global_position) < 4.2:
			return {"text":"E  用鱼叉抵御鳄鱼","id":str(actor.record.id)}
	return {}

func strike(id := "") -> void:
	var target: Dictionary = context() if id.is_empty() else {"id":id}
	if target.is_empty():
		return
	for actor: Dictionary in actors:
		if actor.record.id == target.id:
			if not game.harpoon_equipped or game.capture_cooldown > 0 or float(actor.record.hp) <= 0 or actor.body.global_position.distance_to(game.player.global_position) > 4.2:
				return
			game.capture_cooldown = 1.0
			game._spear_flash(actor.body.global_position + Vector3.UP * .3)
			game.hunting.damage_target({"kind":"crocodile","actor":actor,"node":actor.body}, 2 if game.has_good("harpoon_steel") else 1)
			return
