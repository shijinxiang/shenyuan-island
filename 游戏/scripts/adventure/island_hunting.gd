extends Node3D

const WEAPONS := ["hunting_rifle", "bow"]
const BOW_DAMAGE := .75
const BOW_LARGE_DAMAGE := .25
const LARGE_MARINE_LENGTH := 1.25
var game: Node3D
var models: Dictionary = {}
var equipped := ""
var aiming := false
var reloading := false
var reload_duration := 3.0
var reload_remaining := 0.0
var draw_amount := 1.0
var shot_cooldown := 0.0
var aim_direction := Vector3.FORWARD
var camera_offset := Vector3.ZERO
var aim_cursor := Vector2(640, 360)
var hud: Control
var quest: Node
var audio: AudioStreamPlayer
var processing_corpse := false
var processing_progress := 0.0
var processing_target := Vector3.ZERO
var knife_model: Node3D
var processing_body: Node3D
const CORPSE_PROCESS_SECONDS := 2.2
const CORPSE_REACH := .9
const WATER_CORPSE_REACH := .75

func _ready() -> void:
	game = get_parent()
	process_priority = 60
	for key in ["animal_health", "hunting_stats"]:
		if not game.progress.has(key):
			game.progress[key] = {}
	for id: String in WEAPONS:
		var model: Node3D = load("res://assets/hunting/" + id + ".glb").instantiate()
		add_child(model)
		model.hide()
		models[id] = model
	var grip = preload("res://scripts/player/weapon_grip.gd").new()
	grip.hunting = self
	grip.name = "WeaponGrip"
	game.fishing.skeleton.add_child(grip)
	knife_model = load("res://assets/hunting/skinning_knife.glb").instantiate()
	add_child(knife_model)
	knife_model.hide()
	var knife_grip = preload("res://scripts/player/skinning_grip.gd").new()
	knife_grip.hunting = self
	game.fishing.skeleton.add_child(knife_grip)
	hud = preload("res://scripts/ui/hunting_hud.gd").new()
	hud.hunting = self
	game.ui.add_child(hud)
	audio = AudioStreamPlayer.new()
	add_child(audio)
	quest = preload("res://scripts/adventure/merchant_hunting.gd").new()
	add_child(quest)
	for animal: Dictionary in game.wildlife.fish:
		restore_animal(animal)
	for bird: Dictionary in game.wildlife.birds:
		restore_animal(bird)
	var previous: String = str(game.progress.get("selected_weapon", ""))
	if previous in WEAPONS and game.has_good(previous):
		equip.call_deferred(previous)

func can_use() -> bool:
	var player: CharacterBody3D = game.player
	return (
		equipped in WEAPONS
		and game.has_good(equipped)
		and not game.dead
		and not game.cinematic_active
		and not game.ui.modal_open()
		and not player.swimming
		and not player.in_vehicle()
		and not player.fishing_active
		and not processing_corpse
		and player.interaction_time <= 0
	)

func equip(id: String) -> void:
	if id == equipped and str(game.progress.get("selected_weapon", "")) == id:
		return
	if not id.is_empty() and (id not in WEAPONS or not game.has_good(id) or game.player.interaction_time > 0):
		return
	var before: Dictionary = game.progress.duplicate(true)
	var old_tool: String = game.farming.selected_tool
	var old_harpoon: bool = game.harpoon_equipped
	if not id.is_empty():
		game.farming.selected_tool = ""
		game.progress.selected_tool = ""
		game.harpoon_equipped = false
		if game.player.fishing_active:
			game.fishing.set_active(false)
	game.progress.selected_weapon = id
	if not game.save():
		game.restore_progress(before)
		game.farming.selected_tool = old_tool
		game.harpoon_equipped = old_harpoon
		return
	equipped = id
	reloading = false
	shot_cooldown = 0
	draw_amount = 1
	if not id.is_empty():
		aim_cursor = get_viewport().get_visible_rect().size * .5
		game.player.activate_free_camera()
		game.player.third_distance = clampf(game.player.third_distance, 2.8, 5.0)
		game.player.arm.spring_length = game.player.third_distance
		game.player.arm.rotation.x = -.18
		game.player.orbit.rotation.y = game.player.visual.global_rotation.y + PI
		game.ui.notify("已进入瞄准，左键射击。R 装填 · C 制箭 · 工具栏空格位收起。", 4)
		if id == "hunting_rifle" and not bool(game.progress.get("rifle_loaded", false)):
			start_reload()

func start_reload() -> void:
	if equipped != "hunting_rifle" or reloading or not can_use() or bool(game.progress.get("rifle_loaded", false)):
		return
	if game.economy.quantity("rifle_ammo") < 1:
		game.ui.notify("没有子弹，向闻舟购买猎枪弹。")
		return
	reload_duration = game.skills.reload_seconds()
	reload_remaining = reload_duration
	reloading = true

func _finish_reload() -> void:
	reloading = false
	if equipped != "hunting_rifle" or not can_use() or game.economy.quantity("rifle_ammo") < 1:
		return
	var before: Dictionary = game.progress.duplicate(true)
	game.economy._consume("rifle_ammo", 1)
	game.progress.rifle_loaded = true
	if not game.save():
		game.restore_progress(before)
		game.ui.notify("装填未能保存，子弹已恢复。")

func craft_arrows() -> void:
	if game.economy.quantity("wood") < 1:
		game.ui.notify("制作3支木箭需要1份木材。")
		return
	var before: Dictionary = game.progress.duplicate(true)
	game.economy._consume("wood", 1)
	game._add_good("wooden_arrow", "木箭", 3)
	if not game.save():
		game.restore_progress(before)
		return
	game.ui.notify("制作了木箭×3。")

func restore_animal(animal: Dictionary) -> void:
	var key := String(animal.node.name)
	if game.progress.animal_health.has(key):
		animal.hp = float(game.progress.animal_health[key])
		if animal.hp <= 0:
			animal.caught = true
			animal.node.hide()
			if animal.animator:
				animal.animator.active = false

func _targets() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for animal: Dictionary in game.wildlife.fish:
		if not animal.get("caught", false):
			result.append({"kind":"marine","actor":animal,"node":animal.node})
	for bird: Dictionary in game.wildlife.birds:
		if not bird.get("caught", false):
			result.append({"kind":"bird","actor":bird,"node":bird.node})
	for croc: Dictionary in game.crocodiles.actors:
		if float(croc.record.hp) > 0:
			result.append({"kind":"crocodile","actor":croc,"node":croc.body})
	return result

func trace_shot() -> Dictionary:
	var camera := get_viewport().get_camera_3d()
	var cursor := aim_cursor
	var origin := camera.project_ray_origin(cursor)
	var direction := camera.project_ray_normal(cursor).normalized()
	var distance := 100.0 if equipped == "hunting_rifle" else 50.0
	var excluded: Array[RID] = [game.player.get_rid()]
	if game.player.rowing.boarded:
		excluded.append(game.player.rowing.get_rid())
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * distance, 1, excluded)
	query.hit_from_inside = true
	var wall := get_world_3d().direct_space_state.intersect_ray(query)
	if not wall.is_empty():
		distance = origin.distance_to(wall.position)
	var result := {"point":origin + direction * distance}
	for entry: Dictionary in _targets():
		var point: Vector3 = entry.node.global_position
		if point.distance_to(origin) > distance + 8:
			continue
		var closest := Geometry3D.get_closest_point_to_segment(point, origin, origin + direction * distance)
		if closest.distance_to(point) > (5.0 if entry.kind == "marine" else 2.0):
			continue
		var bounds: AABB = game.Utility.bounds(entry.node)
		var hit = bounds.grow(.04).intersects_ray(origin, direction)
		if hit == null:
			continue
		var travel := origin.distance_to(hit)
		if travel < distance:
			distance = travel
			result = {"point":hit,"target":entry}
	# Aim from the camera, then check the muzzle path to prevent firing around walls.
	var muzzle := models[equipped].find_child("Muzzle" if equipped == "hunting_rifle" else "ArrowRest", true, false) as Node3D
	if muzzle:
		var muzzle_query := PhysicsRayQueryParameters3D.create(muzzle.global_position, result.point, 1, excluded)
		muzzle_query.hit_from_inside = true
		var blocked := get_world_3d().direct_space_state.intersect_ray(muzzle_query)
		if not blocked.is_empty() and muzzle.global_position.distance_to(blocked.position) + .08 < muzzle.global_position.distance_to(result.point):
			result = {"point":blocked.position}
	return result

func shot_damage(target: Dictionary) -> float:
	if equipped == "hunting_rifle":
		return 2.0
	var large: bool = target.kind == "crocodile"
	if target.kind == "marine":
		large = target.actor.species in game.SHARKS or float(target.actor.get("fish_length", 0)) >= LARGE_MARINE_LENGTH
	return BOW_LARGE_DAMAGE if large else BOW_DAMAGE

func damage_target(target: Dictionary, amount: float) -> bool:
	var animal: Dictionary = target.actor
	if amount <= 0 or animal.get("caught", false) or (target.kind == "crocodile" and float(animal.record.hp) <= 0):
		return false
	if target.kind == "marine" and animal.species in game.SHARKS:
		return game.damage_shark(animal, amount)
	var before: Dictionary = game.progress.duplicate(true)
	var fish_before: Array = game.fishing.catches.duplicate(true)
	var key := String(target.node.name)
	var previous := float(animal.record.hp) if target.kind == "crocodile" else float(animal.get("hp", 1))
	var hp := maxf(0, previous - amount)
	var dropped: Node3D
	if target.kind == "crocodile":
		animal.record.hp = hp
	else:
		game.progress.animal_health[key] = hp
	if hp == 0:
		dropped = create_corpse(str(target.kind), animal)
		game.progress.hunting_stats.kills = int(game.progress.hunting_stats.get("kills", 0)) + 1
		game.skills.add_xp("hunting", 10)
	if not game.save():
		discard_drop(dropped)
		game.restore_progress(before)
		game.fishing.catches = fish_before
		if target.kind == "crocodile":
			animal.record = game.progress.crocodiles.filter(func(record):return record.id == key)[0]
		return false
	if target.kind == "crocodile":
		animal.flee = 5.0
		if hp == 0:
			animal.body.collision_layer = 0
			animal.body.collision_mask = 0
			animal.body.hide()
	else:
		animal.hp = hp
		if hp == 0:
			animal.caught = true
			animal.node.hide()
			if animal.animator:
				animal.animator.active = false
	if hp == 0:
		game.ui.notify("猎物已倒下，随身带上剥皮小刀，靠近尸体按 E 处理。")
	return true

func create_corpse(kind: String, animal: Dictionary) -> Node3D:
	var node: Node3D = animal.body if kind == "crocodile" else animal.node
	var species: String = str(animal.get("species", ""))
	var meat := "fish_meat" if kind == "marine" else "crocodile_meat" if kind == "crocodile" else "animal_meat"
	var name := "鳄鱼" if kind == "crocodile" else "知更鸟"
	var length := 1.8 if kind == "crocodile" else .5
	var count := 1
	if kind == "marine":
		name = game.EXTRA_NAMES.get(species, game.fishing.FISH_NAMES.get(species, species))
		length = float(animal.fish_length)
		if species in game.SHARKS:
			meat = "shark_meat"
			count = 2
	var item := {
		"id":String(node.name) + "_corpse_" + str(Time.get_ticks_usec()),
		"name":name + "尸体","corpse":true,"corpse_kind":kind,
		"corpse_species":species,"length_m":length,"count":count,
		"meat_id":meat,"meat_name":{"fish_meat":"鱼肉","shark_meat":"鲨鱼肉","crocodile_meat":"鳄鱼肉","animal_meat":"野味肉"}[meat]
	}
	return create_drop(node.global_position, item, kind == "marine")

func corpse_point(body: Node3D) -> Vector3:
	var bounds: AABB = game.Utility.bounds(body.visual)
	var nearest: Vector3 = game.player.global_position.clamp(bounds.position, bounds.end)
	var meshes: Array[MeshInstance3D] = game.Utility.meshes(body.visual)
	var segments: Array[PackedVector3Array] = []
	# Large carcasses can be worked from their side as well as from above.
	for height in [.12,.3,.5]:
		var origin: Vector3 = game.player.global_position + Vector3.UP * height
		segments.append(PackedVector3Array([origin, Vector3(bounds.get_center().x,origin.y,bounds.get_center().z)]))
	for fraction in [0.0,.25,.5,.75,1.0]:
		var sample: Vector3 = nearest.lerp(bounds.get_center(), fraction)
		var origin := Vector3(sample.x, bounds.end.y + .03, sample.z)
		var end := Vector3(sample.x, bounds.position.y - .03, sample.z)
		segments.append(PackedVector3Array([origin,end]))
	var surface: Vector3 = bounds.get_center()
	var distance := INF
	for segment: PackedVector3Array in segments:
		for mesh: MeshInstance3D in meshes:
			var id := mesh.mesh.get_instance_id()
			if not game.interaction.triangle_cache.has(id):
				game.interaction.triangle_cache[id] = mesh.mesh.generate_triangle_mesh()
			var triangles: TriangleMesh = game.interaction.triangle_cache[id]
			if triangles:
				var inverse := mesh.global_transform.affine_inverse()
				var hit := triangles.intersect_segment(inverse * segment[0], inverse * segment[1])
				if not hit.is_empty():
					var point: Vector3 = mesh.global_transform * Vector3(hit.position)
					var current := point.distance_squared_to(game.player.global_position)
					if current < distance:
						surface = point
						distance = current
	return surface

func pickup_text(body: Node3D) -> String:
	if body.item.get("corpse", false):
		if processing_corpse and body == processing_body:
			return "处理尸体  %d%%" % roundi(processing_progress * 100)
		return "E  用剥皮小刀处理" + str(body.item.name) if game.has_good("skinning_knife") else "E  查看" + str(body.item.name) + " · 需要剥皮小刀"
	return "E  拾取" + str(body.item.name)

func corpse_reach() -> float:
	return WATER_CORPSE_REACH if game.player.swimming else CORPSE_REACH

func process_corpse(body: Node3D) -> bool:
	if processing_corpse:
		return true
	if not is_instance_valid(body) or body.picked or not body.item.get("corpse", false):
		return false
	if not game.has_good("skinning_knife"):
		game.ui.notify("需要先到闻舟的狩猎装备店购买剥皮小刀。")
		return true
	if game.dead or game.cinematic_active or game.ui.modal_open() or game.player.interaction_time > 0 or game.player.in_vehicle():
		return true
	var target := corpse_point(body)
	if target.distance_to(game.player.global_position) > corpse_reach():
		game.ui.notify("请再靠近尸体，使用剥皮小刀处理。")
		return true
	if game.player.fishing_active:
		game.fishing.set_active(false)
	var direction: Vector3 = body.global_position - game.player.global_position
	if Vector2(direction.x,direction.z).length_squared() > .001:
		game.player.visual.global_rotation.y = atan2(direction.x,direction.z)
	processing_body = body
	processing_target = target
	processing_progress = 0
	processing_corpse = true
	reloading = false
	game.player.velocity = Vector3.ZERO
	game.player.interaction_clip = "Treading Water" if game.player.swimming else "Harvest"
	game.player.interaction_rate = game.player.animation.get_animation(game.player.interaction_clip).length / CORPSE_PROCESS_SECONDS
	game.player.interaction_time = CORPSE_PROCESS_SECONDS
	game.player._play_motion(game.player.interaction_clip, game.player.interaction_rate)
	return true

func _update_corpse_processing(delta: float) -> void:
	if not processing_corpse:
		return
	if not is_instance_valid(processing_body) or processing_body.picked or game.dead or game.cinematic_active or game.ui.modal_open() or not game.has_good("skinning_knife") or game.player.in_vehicle():
		_finish_corpse_processing()
		return
	processing_target = corpse_point(processing_body)
	if processing_target.distance_to(game.player.global_position) > corpse_reach() + .05:
		_finish_corpse_processing()
		return
	processing_progress = minf(1.0, processing_progress + delta / CORPSE_PROCESS_SECONDS)
	game.player.interaction_time = maxf(.1, (1 - processing_progress) * CORPSE_PROCESS_SECONDS)
	if processing_progress < 1:
		return
	var before: Dictionary = game.progress.duplicate(true)
	var item: Dictionary = processing_body.item
	processing_body.picked = true
	game._add_good(str(item.meat_id), str(item.meat_name), int(item.count))
	if game.save():
		processing_body.queue_free()
		game.ui.notify("处理完毕，获得%s×%d。" % [item.meat_name,item.count])
	else:
		processing_body.picked = false
		game.restore_progress(before)
		game.ui.notify("处理未能保存，尸体和物品已恢复。")
	_finish_corpse_processing()

func _finish_corpse_processing() -> void:
	processing_corpse = false
	processing_body = null
	processing_progress = 0
	game.player.interaction_time = 0
	knife_model.hide()

func create_drop(point: Vector3, item: Dictionary, marine := false) -> Node3D:
	var landing := point
	var normal := Vector3.UP
	var floating := false
	var query := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 2, point + Vector3.DOWN * 100, 1, [game.player.get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		landing = hit.position
		normal = hit.normal
	else:
		landing.y = game.wildlife.ground.height(point.x, point.z)
	if marine and landing.y < 0:
		landing.y = -.05
		normal = Vector3.UP
		floating = true
	var physical = preload("res://scripts/fishing/caught_fish.gd").new()
	physical.configure(game.fishing._fish_model(item), item, game.player, point, "")
	physical.restore_position({"position":[landing.x,landing.y,landing.z],"normal":[normal.x,normal.y,normal.z],"deceased":true,"floating":floating})
	game.fishing.dropped_fish.add_child(physical)
	return physical

func discard_drop(physical: Node3D) -> void:
	if is_instance_valid(physical):
		physical.picked = true
		physical.hide()
		physical.queue_free()

func fire() -> void:
	if not can_use() or reloading or shot_cooldown > 0:
		return
	if equipped == "hunting_rifle" and not bool(game.progress.get("rifle_loaded", false)):
		start_reload()
		return
	if equipped == "bow" and game.economy.quantity("wooden_arrow") < 1:
		game.ui.notify("没有木箭，按 C 用木材制作，或向闻舟购买。")
		return
	var shot := trace_shot()
	var before: Dictionary = game.progress.duplicate(true)
	if equipped == "hunting_rifle":
		game.progress.rifle_loaded = false
	else:
		game.economy._consume("wooden_arrow", 1)
	var saved: bool = damage_target(shot.target, shot_damage(shot.target)) if shot.has("target") else game.save()
	if not saved:
		game.restore_progress(before)
		game.ui.notify("射击未能保存，弹药已恢复。")
		return
	shot_cooldown = .9 if equipped == "bow" else .18
	draw_amount = 0
	_play_shot_sound()
	_show_projectile(shot.point)
	if equipped == "hunting_rifle":
		start_reload.call_deferred()

func _show_projectile(point: Vector3) -> void:
	var origin: Vector3 = models[equipped].global_position
	var muzzle := models[equipped].find_child("Muzzle" if equipped == "hunting_rifle" else "ArrowRest", true, false) as Node3D
	if muzzle:
		origin = muzzle.global_position
	var projectile: Node3D
	if equipped == "bow":
		projectile = load("res://assets/hunting/wooden_arrow.glb").instantiate()
	else:
		var flash := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = .055
		sphere.height = .11
		flash.mesh = sphere
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = Color("ffe2a0")
		flash.material_override = material
		projectile = flash
	game.world.add_child(projectile)
	projectile.global_position = origin
	if origin.distance_to(point) > .01:
		var up := Vector3.RIGHT if absf((point - origin).normalized().y) > .98 else Vector3.UP
		projectile.look_at(point, up, true)
	var tween := create_tween()
	tween.tween_property(projectile, "global_position", point, .14 if equipped == "hunting_rifle" else .25)
	tween.tween_callback(projectile.queue_free)

func _play_shot_sound() -> void:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	var samples := 3500 if equipped == "hunting_rifle" else 1700
	var bytes := PackedByteArray()
	bytes.resize(samples * 2)
	for index in samples:
		var time := float(index) / samples
		var wave := randf_range(-1, 1) * exp(-time * 10) * (.45 if equipped == "hunting_rifle" else .12)
		bytes.encode_s16(index * 2, roundi(wave * 32767))
	stream.data = bytes
	audio.stream = stream
	audio.play()

func handle_key(event: InputEventKey) -> bool:
	if event.keycode == KEY_C:
		craft_arrows()
	elif event.keycode == KEY_R and not equipped.is_empty() and not game.player.in_vehicle() and not game.player.swimming:
		start_reload()
	else:
		return false
	return true

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and not event.alt_pressed and can_use():
		aim_cursor = event.position
		fire()
		get_viewport().set_input_as_handled()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if game.ui.modal_open():
			return
		if is_instance_valid(game.hotbar) and game.hotbar.visible and game.hotbar.get_global_rect().has_point(event.position):
			return
		if game.survival.mini_map.visible and game.survival.mini_map.get_global_rect().has_point(event.position):
			return
		var control := get_viewport().gui_get_hovered_control()
		if is_instance_valid(control) and control.is_visible_in_tree() and control.get_global_rect().has_point(event.position):
			return
		aim_cursor = event.position

func _process(delta: float) -> void:
	shot_cooldown = maxf(0, shot_cooldown - delta)
	_update_corpse_processing(delta)
	aiming = can_use()
	for id: String in models:
		models[id].visible = aiming and id == equipped
	if not aiming:
		camera_offset = camera_offset.move_toward(Vector3.ZERO, delta * 4)
		reloading = false
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)
		return
	Input.set_default_cursor_shape(Input.CURSOR_CROSS)
	var camera := get_viewport().get_camera_3d()
	var size := get_viewport().get_visible_rect().size
	aim_cursor = aim_cursor.clamp(Vector2.ZERO, size - Vector2.ONE)
	var cursor := aim_cursor
	var relative := (cursor / size - Vector2(.5, .5)) * 2
	var offset := camera.global_basis.x * .7 + (camera.global_basis.x * relative.x - camera.global_basis.y * relative.y) * .8
	camera_offset = camera_offset.lerp(offset, 1 - exp(-delta * 6))
	var target := camera.project_ray_origin(cursor) + camera.project_ray_normal(cursor) * 50
	var shoulder: Vector3 = game.player.global_position + Vector3.UP * 1.3
	aim_direction = (target - shoulder).normalized()
	var flat := Vector3(aim_direction.x, 0, aim_direction.z)
	if flat.length_squared() > .001:
		var facing := atan2(flat.x, flat.z)
		game.player.visual.global_rotation.y = facing if equipped == "bow" else lerp_angle(game.player.visual.global_rotation.y, facing, 1 - exp(-delta * 12))
	draw_amount = move_toward(draw_amount, 1.0, delta)
	if reloading:
		reload_remaining = maxf(0, reload_remaining - delta)
		if reload_remaining <= 0:
			_finish_reload()
	elif equipped == "hunting_rifle" and not bool(game.progress.get("rifle_loaded", false)) and shot_cooldown <= 0 and game.economy.quantity("rifle_ammo") > 0:
		start_reload()

func _exit_tree() -> void:
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
