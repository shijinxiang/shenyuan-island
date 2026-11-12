extends Node3D

var game: Node3D
var candidates: Array[Dictionary] = []
var hovered: Dictionary = {}
var selected: Dictionary = {}
var selected_key := ""
var cursor := Vector2.ZERO
var refresh_time := 0.0
var triangle_cache: Dictionary = {}
var collision_lookup: Dictionary = {}
var outline_effect: Node
var ground_hover := MeshInstance3D.new()
var ground_selected := MeshInstance3D.new()

func _ready() -> void:
	game = get_parent()
	process_priority = 65
	for group_name in ["TraversalCollisions", "CameraOccluders"]:
		var group: Node = game.world.get_node_or_null(group_name)
		if group:
			for body: CollisionObject3D in group.get_children():
				collision_lookup[String(body.name)] = body.get_rid()
	outline_effect = preload("res://scripts/ui/interaction_outline.gd").new()
	add_child(outline_effect)
	for marker in [ground_hover, ground_selected]:
		add_child(marker)
		marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = Color.WHITE
		marker.material_override = material
		marker.hide()

func _append(key: String, kind: String, node: Node3D, point: Vector3, distance: float, text: String, action: Dictionary = {}) -> void:
	if not is_instance_valid(node) or not node.is_visible_in_tree() or point.distance_to(game.player.global_position) > distance + 2.0:
		return
	candidates.append({"key":key,"kind":kind,"node":node,"point":point,"range":distance,"text":text,"action":action})

func collect() -> void:
	candidates.clear()
	var player: CharacterBody3D = game.player
	var farm: Node3D = game.farming
	if player.in_vehicle():
		_append("vehicle", "vehicle", game.vehicle, game.vehicle.global_position, 3, "E  下车")
		return
	for record: Dictionary in game.progress.wood_logs:
		if farm.log_nodes.has(record.id):
			_append("wood:" + str(record.id), "farming", farm.log_nodes[record.id], farm._position(record), 2.3, "E  拾取木头", {"kind":"wood","id":record.id})
	if farm.on_land():
		for id: String in farm.trees:
			var tree: Dictionary = farm.trees[id]
			if not tree.get("felled", false):
				_append("tree:" + id, "farming", tree.node, tree.position, 2.8, "E  砍树" if farm.base_tool(farm.selected_tool) == "axe" else "树木 · 请装备斧头后按 E", {"kind":"tree","id":id})
		for record: Dictionary in game.progress.felled_trees:
			if not record.get("stump_removed", false) and farm.stump_nodes.has(record.id):
				_append("stump:" + str(record.id), "farming", farm.stump_nodes[record.id], farm._position(record), 2.2, "E  清理树桩", {"kind":"stump","id":record.id})
		for record: Dictionary in game.progress.plots:
			if farm.plot_nodes.has(record.id):
				var action: Dictionary = farm.plot_context(str(record.id))
				_append("plot:" + str(record.id), "farming", farm.plot_nodes[record.id], farm._position(record), 2.8, action.text, action)
	if not player.swimming and not player.in_vehicle() and not player.rowing.boarded:
		_append("pot", "nutrition", game.nutrition.pot, game.nutrition.pot.global_position, 2.1, "E  使用大锅烹饪", {"kind":"cook"})
		for entry: Dictionary in game.nutrition.forage:
			if entry.harvest.visible:
				_append(entry.id, "nutrition", entry.node, entry.node.global_position, 1.8, "E  采摘" + str(game.nutrition.FOOD_NAMES[entry.item]), {"kind":"forage","entry":entry})
		for kind in ["bed", "chest", "lamp"]:
			var node: Node3D = game.survival.get(kind)
			var text: String = {"bed":"E  上床休息","chest":"E  打开储物箱","lamp":"E  开关床头灯"}[kind]
			_append("home:" + kind, "home", node, node.global_position, 1.8 if kind != "lamp" else 1.1, text, {"kind":kind})
		_append("letter", "letter", game.letter_table, game.letter_table.global_position, 2.5, "E  阅读留下的信")
		if not game.progress.rod_found:
			_append("rod", "rod", game.rod_pickup, game.rod_pickup.global_position, 2.3, "E  拿起鱼竿")
	if game.merchant_available:
		_append("merchant", "merchant", game.merchant, game.merchant.global_position, 3, "E  与闻舟交谈")
	if game.vehicle.visible:
		_append("vehicle", "vehicle", game.vehicle, game.vehicle.global_position, 3, "E  下车" if player.in_vehicle() else "E  驾驶沙滩车")
	_append("boat", "boat", player.rowing, player.rowing.global_position, 6, "E  下船" if player.rowing.boarded else "E  上船")
	for physical: Node3D in game.fishing.dropped_fish.get_children():
		if not physical.picked and physical.landed_on_ground:
			var corpse: bool = physical.item.get("corpse", false)
			var point: Vector3 = game.hunting.corpse_point(physical) if corpse else physical.global_position
			var reach: float = game.hunting.corpse_reach() if corpse else 2.2
			_append("pickup:" + str(physical.item.id), "pickup", physical, point, reach, game.hunting.pickup_text(physical))
	if is_instance_valid(game.voyage.treasure) and not game.has_good("quest_treasure"):
		_append("salvage", "salvage", game.voyage.treasure, game.voyage.treasure.global_position, 2.3, "E  打捞沉船宝藏")
	if player.swimming:
		var spear: bool = game.harpoon_equipped and not player.swim_moving
		for animal: Dictionary in game.wildlife.fish:
			if animal.get("caught", false) or (animal.species in game.HARPOON_ONLY and not spear):
				continue
			if not animal.species in game.HARPOON_ONLY and (not game.fishing.FISH_NAMES.has(animal.species) or float(animal.fish_length) > .85):
				continue
			var text := "E  用鱼叉击退鲨鱼" if animal.species in game.SHARKS else "E  鱼叉捕捉" if spear else "E  徒手抓鱼"
			_append("fish:" + String(animal.node.name), "catch", animal.node, animal.node.global_position, 4.5 if spear else 1.8, text, {"animal":animal})
	if game.harpoon_equipped:
		for actor: Dictionary in game.crocodiles.actors:
			if float(actor.record.hp) > 0:
				_append("croc:" + str(actor.record.id), "crocodile", actor.body, actor.body.global_position, 4.2, "E  用鱼叉抵御鳄鱼", {"id":actor.record.id})

func _collision_ids(entry: Dictionary) -> Array[RID]:
	var result: Array[RID] = []
	var node: Node3D = entry.node
	if not is_instance_valid(node):
		return result
	if node is CollisionObject3D:
		result.append(node.get_rid())
	for body: CollisionObject3D in node.find_children("*", "CollisionObject3D", true, false):
		result.append(body.get_rid())
	if entry.key.begins_with("tree:"):
		for suffix in ["_Trunk", "_CameraCrown"]:
			var name: String = String(node.name) + suffix
			if collision_lookup.has(name):
				result.append(collision_lookup[name])
	return result

func _mesh_hit(node: Node3D, origin: Vector3, direction: Vector3) -> float:
	var nearest := INF
	for mesh: MeshInstance3D in game.Utility.meshes(node):
		if not mesh.is_visible_in_tree() or mesh.mesh == null:
			continue
		var inverse := mesh.global_transform.affine_inverse()
		var local_origin := inverse * origin
		var local_direction := inverse.basis * direction
		var box_hit = mesh.get_aabb().grow(.025).intersects_ray(local_origin, local_direction)
		if box_hit == null:
			continue
		if mesh.skin != null:
			nearest = minf(nearest, origin.distance_to(mesh.global_transform * Vector3(box_hit)))
			continue
		var id := mesh.mesh.get_instance_id()
		if not triangle_cache.has(id):
			triangle_cache[id] = mesh.mesh.generate_triangle_mesh()
		var triangles: TriangleMesh = triangle_cache[id]
		if triangles:
			var hit := triangles.intersect_ray(local_origin, local_direction)
			if not hit.is_empty():
				nearest = minf(nearest, origin.distance_to(mesh.global_transform * Vector3(hit.position)))
	return nearest

func _pick() -> Dictionary:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return {}
	var origin := camera.project_ray_origin(cursor)
	var direction := camera.project_ray_normal(cursor)
	var excluded: Array[RID] = [game.player.get_rid()]
	for entry: Dictionary in candidates:
		excluded.append_array(_collision_ids(entry))
	var ray := PhysicsRayQueryParameters3D.create(origin, origin + direction * 1600, 1 | 128, excluded)
	var wall := get_world_3d().direct_space_state.intersect_ray(ray)
	var nearest: float = origin.distance_to(wall.position) + .08 if not wall.is_empty() else 1600.0
	var result: Dictionary = {}
	for entry: Dictionary in candidates:
		var distance := _mesh_hit(entry.node, origin, direction)
		if distance < nearest:
			nearest = distance
			result = entry
	if result.is_empty() and not wall.is_empty() and game.farming.on_land() and game.farming.base_tool(game.farming.selected_tool) == "hoe" and wall.normal.y > .7:
		var point: Vector3 = wall.position
		if point.distance_to(game.player.global_position) <= 2.8:
			ground_hover.show()
			_ground_marker(ground_hover, point, false)
			result = {"key":"ground_hover","kind":"ground","node":ground_hover,"point":point,"range":2.8,"text":"E  开垦选中的地面","action":{}}
	return result

func _reachable(entry: Dictionary) -> bool:
	var offset: Vector3 = entry.point - game.player.global_position
	var distance := Vector2(offset.x, offset.z).length() if entry.kind == "home" else offset.length()
	if distance > float(entry.range) or (entry.kind == "home" and absf(offset.y) > 2.0):
		return false
	var excluded := _collision_ids(entry)
	excluded.append(game.player.get_rid())
	if game.player.rowing.boarded:
		excluded.append(game.player.rowing.get_rid())
	var endpoint: Vector3 = entry.point + Vector3.UP * (.12 if entry.kind in ["catch", "pickup"] else .35)
	var ray := PhysicsRayQueryParameters3D.create(game.player.global_position + Vector3.UP * .7, endpoint, 1, excluded)
	return get_world_3d().direct_space_state.intersect_ray(ray).is_empty()

func _ground_marker(marker: MeshInstance3D, point: Vector3, strong: bool) -> void:
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var width := .032 if strong else .014
	var corners := [Vector2(-.7,-.7),Vector2(.7,-.7),Vector2(.7,.7),Vector2(-.7,.7)]
	for index in 4:
		var start: Vector2 = corners[index]
		var end: Vector2 = corners[(index + 1) % 4]
		var side := Vector2(-(end-start).y, (end-start).x).normalized() * width
		for corner in [start-side,end-side,end+side,start-side,end+side,start+side]:
			var x: float = point.x + corner.x
			var z: float = point.z + corner.y
			mesh.surface_add_vertex(Vector3(x, game.wildlife.ground.height(x,z) + .035, z))
	mesh.surface_end()
	marker.mesh = mesh
	(marker.material_override as StandardMaterial3D).cull_mode = BaseMaterial3D.CULL_DISABLED
	marker.show()

func refresh() -> void:
	collect()
	ground_hover.hide()
	ground_selected.hide()
	var old_selected := selected
	selected = {}
	for entry: Dictionary in candidates:
		if entry.key == selected_key:
			selected = entry
			break
	if selected_key == "ground" and not old_selected.is_empty() and game.farming.on_land() and old_selected.point.distance_to(game.player.global_position) < 4.8:
		selected = old_selected
		selected.text = "E  开垦选中的地面" if game.farming.base_tool(game.farming.selected_tool) == "hoe" else "地面 · 请装备锄头后按 E"
		_ground_marker(ground_selected, selected.point, true)
	elif selected.is_empty():
		selected_key = ""
	var control := get_viewport().gui_get_hovered_control()
	var over_ui := is_instance_valid(control) and control.is_visible_in_tree() and control.get_global_rect().has_point(cursor)
	hovered = {} if over_ui else _pick()
	_update_outlines()
	game._update_context()

func _update_outlines() -> void:
	if is_instance_valid(outline_effect):
		outline_effect.set_targets(hovered, selected)

func context() -> Dictionary:
	var entry := selected if not selected.is_empty() else hovered
	if entry.is_empty():
		return {}
	if not is_instance_valid(entry.node) or entry.node.is_queued_for_deletion():
		return {}
	var text: String = entry.text
	if not _reachable(entry):
		text = "靠近选中物体后按 E"
	return {"text":text,"kind":"targeted","entry":entry}

func interact() -> bool:
	var target := context()
	if target.is_empty():
		return false
	var entry: Dictionary = target.entry
	if not _reachable(entry):
		game.ui.notify("请靠近选中的物体，并留出无遮挡的交互路径。")
		return true
	if entry.kind in ["farming", "ground", "nutrition"]:
		_face(entry.point)
	match entry.kind:
		"farming":
			if entry.action.kind in ["tree", "stump"] and game.farming.base_tool(game.farming.selected_tool) != "axe":
				game.ui.notify("先从工具栏装备斧头，再按 E。")
			else:
				game.farming.interact(entry.action)
		"ground":
			if game.farming.base_tool(game.farming.selected_tool) != "hoe":
				game.ui.notify("先从工具栏装备锄头，再按 E。")
				return true
			var before: int = game.progress.plots.size()
			game.farming.till_ground(entry.point)
			if game.progress.plots.size() > before:
				selected_key = "plot:" + str(game.progress.plots.back().id)
				refresh()
		"nutrition": game.nutrition.interact(entry.action)
		"home": game.survival.interact(entry.action.kind)
		"merchant": game.open_merchant()
		"letter": game.read_letter()
		"boat": game.player.rowing.interact()
		"vehicle": game.vehicle.interact()
		"pickup": game.fishing.try_pickup(entry.node)
		"catch":
			game.context_animal = entry.action.animal
			game.capture_swimming_fish()
		"crocodile": game.crocodiles.strike(str(entry.action.id))
		"salvage": game.voyage.salvage()
		"rod":
			game.progress.rod_found = true
			game.rod_pickup.hide()
			game.save()
	return true

func plant_selected() -> bool:
	if selected.is_empty() or not selected_key.begins_with("plot:"):
		return false
	if _reachable(selected):
		_face(selected.point)
		game.farming.plant_seed(str(selected.action.id))
	else:
		game.ui.notify("请靠近选中的耕地。")
	return true

func _face(point: Vector3) -> void:
	var direction: Vector3 = point - game.player.global_position
	if Vector2(direction.x, direction.z).length_squared() > .001:
		game.player.visual.global_rotation.y = atan2(direction.x, direction.z)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion or event is InputEventMouseButton:
		cursor = event.position
		if event is InputEventMouseButton:
			refresh_time = 0

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and not game.ui.modal_open() and not game.dead and not game.cinematic_active:
		refresh()
		if hovered.is_empty() and (game.hunting.can_use() or game.player.fishing_active) and not event.alt_pressed:
			selected = {}
			selected_key = ""
			_update_outlines()
			game._update_context()
			return
		if hovered.is_empty():
			selected = {}
			selected_key = ""
		else:
			selected = hovered.duplicate()
			selected_key = "ground" if selected.kind == "ground" else str(selected.key)
			selected.key = selected_key
		_update_outlines()
		game._update_context()
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	refresh_time -= delta
	if game.ui.modal_open() or game.dead or game.cinematic_active:
		hovered = {}
		ground_hover.hide()
		ground_selected.hide()
		var held := selected
		selected = {}
		_update_outlines()
		selected = held
		return
	if refresh_time <= 0:
		refresh_time = .1
		refresh()

