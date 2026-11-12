extends Node3D

const Utility = preload("res://scripts/core/island_static_setup.gd")
const ASSET_DIR := "res://assets/farming/"
const TOOLS := {"axe": "斧头", "hoe": "锄头", "watering_can": "浇水壶", "axe_steel": "钢制斧头", "hoe_steel": "钢制锄头", "watering_can_large": "大号浇水壶"}
const CROP_NAMES := {"turnip": "萝卜", "tomato": "番茄", "pumpkin": "南瓜"}
const GROW_DAYS := {"turnip": 3, "tomato": 4, "pumpkin": 5}
const PLOT_SIZE := 1.4
const WATERING_PALM_ANCHOR := Vector3(0.0, 0.09, -0.048)
const WATERING_HAND_BASIS := Basis(Vector3(1,0,0), Vector3(0,-1,0), Vector3(0,0,-1))

var game: Node3D
var trees: Dictionary = {}
var tree_bins: Dictionary = {}
var tree_hits: Dictionary = {}
var plot_nodes: Dictionary = {}
var log_nodes: Dictionary = {}
var stump_nodes: Dictionary = {}
var held_tools: Dictionary = {}
var grips: Dictionary = {}
var selected_tool := ""
var action_cooldown := 0.0
var swing_remaining := 0.0
var wet_material: Material
var dry_material: Material

func _ready() -> void:
	game = get_parent()
	for field in ["plots", "felled_trees", "wood_logs"]:
		if not game.progress.has(field):
			game.progress[field] = []
	if not game.progress.has("farm_day"):
		game.progress.farm_day = game.day_count
	wet_material = load(ASSET_DIR + "soil_wet.tres")
	dry_material = load(ASSET_DIR + "soil_dry.tres")
	_index_trees()
	_migrate_crops()
	_restore_views()
	_setup_tools()
	selected_tool = str(game.progress.get("selected_tool", ""))
	if not game.has_good(selected_tool):
		selected_tool = ""
	var grip_modifier = preload("res://scripts/player/watering_grip.gd").new()
	grip_modifier.name = "WateringGrip"
	grip_modifier.farming = self
	game.fishing.skeleton.add_child(grip_modifier)
	game.fishing.skeleton.skeleton_updated.connect(_update_held_tool)
	print("ISLAND_FARMING_READY trees=", trees.size(), " plots=", plot_nodes.size())

func _index_trees() -> void:
	for actor: Node3D in game.world.get_node("AllIslandStatic").get_children():
		if actor.get_meta("category", "") != "tree":
			continue
		var id := String(game.world.get_path_to(actor))
		var foot: Vector3 = actor.get_meta("ground_position", actor.global_position)
		trees[id] = {"node": actor, "position": foot, "name": String(actor.name)}
		var cell := Vector2i(floori(foot.x / 8.0), floori(foot.z / 8.0))
		if not tree_bins.has(cell):
			tree_bins[cell] = []
		tree_bins[cell].append(id)
	for record: Dictionary in game.progress.felled_trees:
		if trees.has(record.id):
			_disable_tree(trees[record.id])

func _disable_tree(tree: Dictionary) -> void:
	var actor: Node3D = tree.node
	tree.felled = true
	actor.hide()
	for group_name in ["TraversalCollisions", "CameraOccluders"]:
		var group: Node = game.world.get_node_or_null(group_name)
		if group == null:
			continue
		for body: Node3D in group.get_children():
			if String(body.name) in [str(tree.name) + "_Trunk", str(tree.name) + "_CameraCrown"]:
				for shape: CollisionShape3D in body.find_children("*", "CollisionShape3D", true, false):
					shape.set_deferred("disabled", true)
	for body: CollisionObject3D in actor.find_children("*", "CollisionObject3D", true, false):
		body.collision_layer = 0
		body.collision_mask = 0

func _migrate_crops() -> void:
	for crop: Dictionary in game.progress.crops:
		if crop.has("plot_id"):
			continue
		var plot_id := "legacy_" + str(crop.id)
		var old_duration: float = {"turnip": 2.0, "tomato": 3.0, "pumpkin": 4.0}.get(crop.type, 2.0)
		var age: float = maxf(0.0, game.day_count * 24.0 + game.weather.hour - float(crop.get("planted", 0)))
		crop.plot_id = plot_id
		crop.growth_days = mini(int(GROW_DAYS[crop.type]), floori(age / old_duration * int(GROW_DAYS[crop.type])))
		game.progress.plots.append({"id": plot_id, "position": crop.position, "watered_day": game.day_count})

func _restore_views() -> void:
	for group in [plot_nodes, log_nodes, stump_nodes]:
		for node: Node3D in group.values():
			node.free()
		group.clear()
	for record: Dictionary in game.progress.felled_trees:
		if not record.get("stump_removed", false):
			_spawn_stump(record)
	for record: Dictionary in game.progress.wood_logs:
		_spawn_log(record)
	for record: Dictionary in game.progress.plots:
		_spawn_plot(record)

func _setup_tools() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ASSET_DIR + "manifest.json"))
	for id: String in ["axe", "hoe", "watering_can"]:
		var model := item_model(id)
		model.name = "Held_" + id
		model.hide()
		add_child(model)
		held_tools[id] = model
		var point: Array = manifest.tools[id].grip
		grips[id] = Vector3(point[0], point[1], point[2])

func item_model(id: String) -> Node3D:
	return load(ASSET_DIR + ("log" if id == "wood" else base_tool(id)) + ".glb").instantiate()

func base_tool(id: String) -> String:
	return id.trim_suffix("_steel").trim_suffix("_large")

func crop_model(type: String, stage: int) -> Node3D:
	return load(ASSET_DIR + type + "_stage_" + str(stage) + ".glb").instantiate()

func has_tools() -> bool:
	for id: String in TOOLS:
		if game.has_good(id):
			return true
	return false

func equip_tool(id: String) -> void:
	if action_cooldown > 0 and game.player.interaction_time > 0:
		return
	if not id.is_empty() and not game.has_good(id):
		return
	selected_tool = id
	game.progress.selected_tool = id
	if not id.is_empty():
		game.harpoon_equipped = false
		if game.player.fishing_active:
			game.fishing.set_active(false)
	game.save()
	game.ui.notify("已收起工具。" if id.is_empty() else "已装备" + str(TOOLS[id]) + "，靠近目标按 E 使用。")
	game._update_context()

func cycle_tool() -> void:
	var available: Array[String] = [""]
	for base: String in ["axe", "hoe", "watering_can"]:
		var upgrade := base + ("_large" if base == "watering_can" else "_steel")
		if game.has_good(upgrade):
			available.append(upgrade)
		elif game.has_good(base):
			available.append(base)
	if available.size() == 1:
		game.ui.notify("闻舟带来了斧头、锄头和浇水壶，可以拿鱼获交换。")
		return
	equip_tool(available[(available.find(selected_tool) + 1) % available.size()])

func on_land() -> bool:
	return not game.cinematic_active and not game.dead and not game.player.swimming and not game.player.rowing.boarded and not game.player.fishing_active and not game.player.in_vehicle()

func _update_held_tool() -> void:
	for id: String in held_tools:
		var model: Node3D = held_tools[id]
		model.visible = id == base_tool(selected_tool) and on_land() and not game.cinematic_active and not game.dead and game.player.current_motion != "Harvest"
		if not model.visible:
			continue
		if id == "watering_can":
			var skeleton: Skeleton3D = game.fishing.skeleton
			var hand_pose := skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone("RightHand"))
			var orientation := hand_pose.basis.orthonormalized() * WATERING_HAND_BASIS
			var grip_center := hand_pose * WATERING_PALM_ANCHOR
			model.global_transform = Transform3D(orientation, grip_center - orientation * Vector3(grips[id]))
			continue
		var skeleton: Skeleton3D = game.fishing.skeleton
		var hand_pose := skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone("RightHand"))
		var axis := -hand_pose.basis.x.normalized()
		var hand := hand_pose * WATERING_PALM_ANCHOR
		var side: Vector3 = game.player.visual.global_basis.x
		side = (side - axis * side.dot(axis)).normalized()
		if side.length_squared() < .01:
			side = hand_pose.basis.y.normalized()
		if id == "axe":
			side = -side
		var basis := Basis(side, axis, side.cross(axis).normalized())
		model.global_transform = Transform3D(basis, hand - basis * Vector3(grips[id]))
func _new_id() -> String:
	return str(Time.get_unix_time_from_system()) + "_" + str(randi())

func _position(record: Dictionary) -> Vector3:
	return Vector3(record.position[0], record.position[1], record.position[2])

func _nearest(records: Array, maximum: float) -> Dictionary:
	var result: Dictionary = {}
	var closest := maximum
	var point: Vector3 = game.player.global_position
	for record: Dictionary in records:
		var distance := point.distance_to(_position(record))
		if distance < closest:
			closest = distance
			result = record
	return result

func nearest_plot() -> Dictionary:
	return _nearest(game.progress.plots, 2.25)

func _nearest_tree() -> String:
	var point: Vector3 = game.player.global_position
	var cell := Vector2i(floori(point.x / 8.0), floori(point.z / 8.0))
	var nearest := 2.8
	var selected := ""
	var forward: Vector3 = game.player.visual.global_basis.z.normalized()
	for x in range(cell.x - 1, cell.x + 2):
		for z in range(cell.y - 1, cell.y + 2):
			for id: String in tree_bins.get(Vector2i(x, z), []):
				var tree: Dictionary = trees[id]
				if tree.get("felled", false):
					continue
				var offset: Vector3 = tree.position - point
				offset.y = 0.0
				if offset.length() < nearest and offset.normalized().dot(forward) > -.15:
					nearest = offset.length()
					selected = id
	return selected

func _crop_on(plot_id: String) -> Dictionary:
	for crop: Dictionary in game.progress.crops:
		if str(crop.get("plot_id", "")) == plot_id:
			return crop
	return {}

func context() -> Dictionary:
	var log := _nearest(game.progress.wood_logs, 2.3)
	if not log.is_empty():
		return {"kind": "wood", "id": log.id, "text": "E  拾取木头"}
	if not on_land():
		return {}
	if base_tool(selected_tool) == "axe":
		var stump := _nearest(game.progress.felled_trees.filter(func(record): return not record.get("stump_removed", false)), 2.2)
		if not stump.is_empty():
			return {"kind": "stump", "id": stump.id, "text": "E  清理树桩"}
		var tree_id := _nearest_tree()
		if not tree_id.is_empty():
			return {"kind": "tree", "id": tree_id, "text": "E  砍树  %d/%d" % [int(tree_hits.get(tree_id, 0)), game.skills.axe_hits()]}
	var plot := nearest_plot()
	if not plot.is_empty():
		return plot_context(str(plot.id))
	if base_tool(selected_tool) == "hoe":
		return {"kind": "till", "text": "E  用锄头开垦耕地"}
	return {}

func plot_context(id: String) -> Dictionary:
	for plot: Dictionary in game.progress.plots:
		if str(plot.id) != id:
			continue
		var crop := _crop_on(id)
		var status := "湿润" if int(plot.watered_day) == game.day_count else "干裂 · 今日未浇水"
		if not crop.is_empty():
			if int(crop.growth_days) >= int(GROW_DAYS[crop.type]):
				return {"kind":"harvest","id":id,"text":"E  收获" + str(CROP_NAMES[crop.type])}
			status += " · %s %d/%d天" % [CROP_NAMES[crop.type], crop.growth_days, GROW_DAYS[crop.type]]
		if base_tool(selected_tool) == "watering_can":
			return {"kind":"water","id":id,"text":"E  浇水 · " + status}
		return {"kind":"inspect","id":id,"text":"E  查看耕地 · " + status}
	return {}

func interact(target: Dictionary = {}) -> void:
	if action_cooldown > 0.0:
		return
	if target.is_empty():
		target = context()
	match target.get("kind", ""):
		"tree": chop_tree(str(target.id))
		"stump": clear_stump(str(target.id))
		"wood": pickup_log(str(target.id))
		"till": till_ground()
		"water": water_plot(str(target.id))
		"harvest": harvest(str(target.id))
		"inspect":
			game.ui.notify("先装备浇水壶再按 E 浇水。空耕地上可按 G 播种；缺水当天不计生长。", 4.0)

func _saved(before: Dictionary) -> bool:
	if game.save():
		return true
	game.restore_progress(before)
	_restore_views()
	game.ui.notify("这次操作未能保存，请稍后重试。")
	return false

func _swing() -> void:
	action_cooldown = .55
	swing_remaining = .5

func _play_action(clip: String, duration: float) -> void:
	action_cooldown = duration + .15
	game.player.interaction_clip = clip
	game.player.interaction_time = duration
	game.player.interaction_rate = game.player.animation.get_animation(clip).length / duration
	game.player._play_motion(clip, game.player.interaction_rate)

func _tree_pivot(tree: Dictionary) -> Node3D:
	if tree.has("pivot"):
		return tree.pivot
	var pivot := Node3D.new()
	add_child(pivot)
	pivot.global_position = tree.position
	tree.node.reparent(pivot, true)
	tree.pivot = pivot
	return pivot

func _sway_tree(tree: Dictionary) -> void:
	var pivot := _tree_pivot(tree)
	if tree.has("sway") and tree.sway.is_valid():
		tree.sway.kill()
	var direction: Vector3 = game.player.visual.global_basis.z.normalized()
	var axis := Vector3.UP.cross(direction).normalized()
	var tween := create_tween()
	tree.sway = tween
	tween.tween_property(pivot, "quaternion", Quaternion(axis, .045), .1)
	tween.tween_property(pivot, "quaternion", Quaternion(axis, -.022), .13)
	tween.tween_property(pivot, "quaternion", Quaternion.IDENTITY, .2)

func chop_tree(id: String) -> void:
	if base_tool(selected_tool) != "axe" or not trees.has(id) or not on_land():
		return
	var tree: Dictionary = trees[id]
	if tree.get("felled", false):
		return
	_play_action("Chop", .8)
	await get_tree().create_timer(.754).timeout
	if tree.get("felled", false) or not on_land():
		return
	var hits := int(tree_hits.get(id, 0)) + 1
	tree_hits[id] = hits
	var hits_needed: int = game.skills.axe_hits()
	if hits < hits_needed:
		_sway_tree(tree)
		game.ui.notify("树干松动了  %d/%d" % [hits, hits_needed], 1.0)
		return
	var before: Dictionary = game.progress.duplicate(true)
	game.skills.add_xp("woodcutting", 12)
	var bounds: AABB = Utility.bounds(tree.node)
	var radius: float = clampf(float(tree.node.get_meta("grass_clearance_radius", .4)) * .5, .18, .65)
	var foot: Vector3 = tree.position
	game.progress.felled_trees.append({"id": id, "position": [foot.x, foot.y, foot.z], "radius": radius, "stump_removed": false})
	var count := clampi(ceili(bounds.size.y / 2.0), 3, 5)
	var forward: Vector3 = game.player.visual.global_basis.z.normalized()
	var added: Array[Dictionary] = []
	for index in count:
		var point := foot + forward * (1.0 + index * .8) + Vector3(forward.z, 0, -forward.x) * (.25 if index % 2 == 0 else -.25)
		point.y = game.wildlife.ground.height(point.x, point.z)
		point.y = maxf(point.y, 0.0)
		var record := {"id": _new_id(), "position": [point.x, point.y + .02, point.z], "yaw": atan2(forward.x, forward.z) + index * .23}
		game.progress.wood_logs.append(record)
		added.append(record)
	if not _saved(before):
		tree_hits[id] = hits_needed - 1
		return
	_disable_tree(tree)
	# Rotate the actual tree around its ground contact before replacing it with logs.
	var pivot := _tree_pivot(tree)
	if tree.has("sway") and tree.sway.is_valid():
		tree.sway.kill()
	pivot.quaternion = Quaternion.IDENTITY
	var actor: Node3D = tree.node
	actor.show()
	var fall_axis := Vector3.UP.cross(forward).normalized()
	var tween := create_tween()
	tween.tween_property(pivot, "quaternion", Quaternion(fall_axis, PI * .48), .85).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(actor.hide)
	_spawn_stump(game.progress.felled_trees.back())
	for record: Dictionary in added:
		_spawn_log(record)
	game.ui.notify("树倒下了，留下 %d 段木头。树桩也可以用斧头清理。" % count)

func _spawn_stump(record: Dictionary) -> void:
	var model := item_model("stump")
	add_child(model)
	model.position = _position(record)
	model.scale = Vector3.ONE * float(record.radius) / .3
	stump_nodes[record.id] = model
	var body := StaticBody3D.new()
	model.add_child(body)
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = .3
	cylinder.height = .3
	shape.shape = cylinder
	shape.position.y = .15
	body.add_child(shape)

func _spawn_log(record: Dictionary) -> void:
	var model := item_model("wood")
	add_child(model)
	model.position = _position(record)
	model.rotation.y = float(record.yaw)
	log_nodes[record.id] = model

func clear_stump(id: String) -> void:
	if base_tool(selected_tool) != "axe":
		return
	for record: Dictionary in game.progress.felled_trees:
		if record.id != id or record.get("stump_removed", false):
			continue
		var before: Dictionary = game.progress.duplicate(true)
		record.stump_removed = true
		game._add_good("wood", "木材", 1)
		if not _saved(before):
			return
		stump_nodes[id].queue_free()
		stump_nodes.erase(id)
		_swing()
		game.ui.notify("树桩已清理，获得 1 份木材。空地可以继续开垦。")
		return

func pickup_log(id: String) -> void:
	for record: Dictionary in game.progress.wood_logs:
		if record.id != id:
			continue
		var before: Dictionary = game.progress.duplicate(true)
		game.progress.wood_logs.erase(record)
		game._add_good("wood", "木材", 1)
		if not _saved(before):
			return
		log_nodes[id].queue_free()
		log_nodes.erase(id)
		game.ui.notify("拾取了 1 份木材。", 1.5)
		return

func till_position() -> Vector3:
	var point: Vector3 = game.player.global_position + game.player.visual.global_basis.z * 1.55
	point.x = snappedf(point.x, .1)
	point.z = snappedf(point.z, .1)
	point.y = game.wildlife.ground.height(point.x, point.z)
	return point

func placement_error(point: Vector3) -> String:
	if point.y < 1.5:
		return "请到岛内的草地上开垦，沙滩不适合种菜。"
	for plot: Dictionary in game.progress.plots:
		var offset := _position(plot) - point
		if absf(offset.x) < PLOT_SIZE + .1 and absf(offset.z) < PLOT_SIZE + .1:
			return "这里已经有耕地，给相邻地块留些空间。"
	var low := INF
	var high := -INF
	for x in [-.7, 0.0, .7]:
		for z in [-.7, 0.0, .7]:
			var height: float = game.wildlife.ground.height(point.x + x, point.z + z)
			low = minf(low, height)
			high = maxf(high, height)
	var slope_limit := .75 if game.has_good("hoe_steel") else .55
	if low < 1.35 or high - low > slope_limit:
		return "这块地坡度太大，请换一处较平缓的草地。"
	var query := PhysicsShapeQueryParameters3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.35, .7, 1.35)
	query.shape = box
	query.transform = Transform3D(Basis.IDENTITY, Vector3(point.x, high + .43, point.z))
	query.collision_mask = 1
	query.exclude = [game.player.get_rid()]
	if not get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty():
		return "这里有树木、树桩、石头或建筑，请先清理或换一处空地。"
	return ""

func till_ground(target := Vector3.INF) -> void:
	if base_tool(selected_tool) != "hoe" or not on_land():
		return
	var point := till_position() if not target.is_finite() else target
	if point.distance_to(game.player.global_position) > 2.8:
		return
	var error := placement_error(point)
	if not error.is_empty():
		game.ui.notify(error)
		return
	var before: Dictionary = game.progress.duplicate(true)
	var record := {"id": _new_id(), "position": [point.x, point.y, point.z], "watered_day": -1}
	if game.weather.current_weather >= 2:
		record.watered_day = game.day_count
	game.progress.plots.append(record)
	if not _saved(before):
		return
	_spawn_plot(record)
	_swing()
	if game.has_good("hoe_steel"):
		action_cooldown = .3
	game.ui.notify("耕地已开垦。选好种子按 G 播种，再用浇水壶按 E 浇水。", 4.0)

func _spawn_plot(record: Dictionary) -> void:
	var plot := Node3D.new()
	plot.name = "Plot_" + str(record.id).replace(".", "_")
	add_child(plot)
	plot.position = _position(record)
	var soil: Node3D = load(ASSET_DIR + "soil_plot.glb").instantiate()
	soil.name = "Soil"
	plot.add_child(soil)
	for mesh: MeshInstance3D in Utility.meshes(soil):
		var conformed := ArrayMesh.new()
		for surface in mesh.mesh.get_surface_count():
			var arrays := mesh.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			for index in vertices.size():
				var point := mesh.to_global(vertices[index])
				var thickness := point.y - plot.global_position.y
				point.y = game.wildlife.ground.height(point.x, point.z) + thickness + .012
				vertices[index] = mesh.to_local(point)
			arrays[Mesh.ARRAY_VERTEX] = vertices
			var segment := ArrayMesh.new()
			segment.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			var builder := SurfaceTool.new()
			builder.create_from(segment, 0)
			builder.generate_normals()
			builder.commit(conformed)
		mesh.mesh = conformed
		var body := StaticBody3D.new()
		mesh.add_child(body)
		var collision := CollisionShape3D.new()
		collision.shape = conformed.create_trimesh_shape()
		body.add_child(collision)
	plot_nodes[record.id] = plot
	_clear_grass(plot.position)
	_sync_plot(record)

func _clear_grass(center: Vector3) -> void:
	var field: Node3D = game.world.get_node("IslandGrass")
	for chunk: MultiMeshInstance3D in field.get_children():
		if absf(chunk.global_position.x - center.x) > 22 or absf(chunk.global_position.z - center.z) > 22:
			continue
		var original: MultiMesh = chunk.multimesh
		if original.instance_count == 0:
			continue
		var buffer := original.buffer
		var stride: int = buffer.size() / original.instance_count
		var kept := PackedFloat32Array()
		for index in original.instance_count:
			var start: int = index * stride
			var point := chunk.to_global(Vector3(buffer[start+3], buffer[start+7], buffer[start+11]))
			# Clear the roots and a margin for blades bending in the wind.
			if absf(point.x - center.x) >= 1.1 or absf(point.z - center.z) >= 1.1:
				kept.append_array(buffer.slice(start, start + stride))
		if kept.size() != buffer.size():
			var replacement: MultiMesh = original.duplicate()
			replacement.instance_count = kept.size() / stride
			replacement.buffer = kept
			chunk.multimesh = replacement

func _sync_plot(record: Dictionary) -> void:
	var plot: Node3D = plot_nodes[record.id]
	var wet: bool = int(record.watered_day) == game.day_count
	for mesh: MeshInstance3D in Utility.meshes(plot.get_node("Soil")):
		mesh.material_override = wet_material if wet else dry_material
	plot.set_meta("wet", wet)
	var crop := _crop_on(str(record.id))
	var stage := -1
	if not crop.is_empty():
		var days: int = GROW_DAYS[crop.type]
		var growth: int = int(crop.growth_days)
		if growth >= days:
			stage = 3
		elif growth >= ceili(days * .5):
			stage = 2
		elif growth > 0:
			stage = 1
		else:
			stage = 0
	if int(plot.get_meta("stage", -2)) != stage:
		var old := plot.get_node_or_null("Crop")
		if old:
			old.free()
		if stage >= 0:
			var model := crop_model(str(crop.type), stage)
			model.name = "Crop"
			plot.add_child(model)
			model.position.y = .10
		plot.set_meta("stage", stage)
	plot.set_meta("ripe", stage == 3)

func plant_seed(plot_id := "") -> void:
	if not on_land() or action_cooldown > 0:
		return
	var seed: String = game.selected_seed
	if seed.is_empty() or not game.has_good(seed):
		game.ui.notify("先从背包选择一种种子。")
		return
	var plot := nearest_plot()
	if not plot_id.is_empty():
		plot = {}
		for candidate: Dictionary in game.progress.plots:
			if str(candidate.id) == plot_id and _position(candidate).distance_to(game.player.global_position) < 2.8:
				plot = candidate
				break
	if plot.is_empty():
		game.ui.notify("种子需要耕地。先装备锄头，按 E 开垦。")
		return
	if not _crop_on(str(plot.id)).is_empty():
		game.ui.notify("这块地已经种了作物，请先收获或换一块空耕地。")
		return
	var before: Dictionary = game.progress.duplicate(true)
	var type := seed.trim_prefix("seed_")
	for item: Dictionary in game.progress.goods:
		if item.id == seed:
			item.count = int(item.count) - 1
			break
	game.progress.crops.append({"id": _new_id(), "type": type, "position": plot.position.duplicate(), "plot_id": plot.id, "growth_days": 0, "planted_day": game.day_count})
	game.skills.add_xp("farming", 4)
	if not _saved(before):
		return
	_sync_plot(plot)
	game.ui.notify("种下了%s，每天浇水，%d天后成熟。下雨会自动浇水。" % [CROP_NAMES[type], GROW_DAYS[type]], 4.0)

func water_plot(id: String) -> void:
	if base_tool(selected_tool) != "watering_can" or not on_land():
		return
	_play_action("Watering", 2.0)
	await get_tree().create_timer(.75).timeout
	if not on_land():
		return
	for plot: Dictionary in game.progress.plots:
		if plot.id != id:
			continue
		if int(plot.watered_day) == game.day_count:
			game.ui.notify("这块地今天已经湿润了。", 1.5)
			return
		var before: Dictionary = game.progress.duplicate(true)
		plot.watered_day = game.day_count
		game.skills.add_xp("farming", 2)
		if game.has_good("watering_can_large"):
			for neighbor: Dictionary in game.progress.plots:
				if _position(neighbor).distance_to(_position(plot)) < 2.6:
					neighbor.watered_day = game.day_count
		if not _saved(before):
			return
		for neighbor: Dictionary in game.progress.plots:
			_sync_plot(neighbor)
		game.ui.notify("浇好水了，土壤恢复湿润。", 2.0)
		return

func harvest(id: String) -> void:
	var crop := _crop_on(id)
	if crop.is_empty() or int(crop.growth_days) < int(GROW_DAYS[crop.type]):
		return
	_play_action("Harvest", 2.1)
	await get_tree().create_timer(1.2).timeout
	if not on_land() or _crop_on(id).is_empty():
		return
	var before: Dictionary = game.progress.duplicate(true)
	game._add_good("crop_" + str(crop.type), str(CROP_NAMES[crop.type]), game.skills.harvest_count())
	game.skills.add_xp("farming", 12)
	game.progress.crops.erase(crop)
	if not _saved(before):
		return
	for plot: Dictionary in game.progress.plots:
		if plot.id == id:
			_sync_plot(plot)
			break
	game.ui.notify("收获了" + str(CROP_NAMES[crop.type]) + "，耕地可以继续播种。")

func update_days() -> void:
	var previous_day := int(game.progress.farm_day)
	var changed: bool = previous_day < game.day_count
	for day in range(previous_day, game.day_count):
		for plot: Dictionary in game.progress.plots:
			var crop := _crop_on(str(plot.id))
			if not crop.is_empty() and int(plot.watered_day) == day:
				crop.growth_days = mini(int(GROW_DAYS[crop.type]), int(crop.growth_days) + 1)
	game.progress.farm_day = game.day_count
	if game.weather.current_weather >= 2:
		for plot: Dictionary in game.progress.plots:
			if int(plot.watered_day) != game.day_count:
				plot.watered_day = game.day_count
				changed = true
	if changed:
		for plot: Dictionary in game.progress.plots:
			_sync_plot(plot)
		game.save()

func _process(delta: float) -> void:
	action_cooldown = maxf(0.0, action_cooldown - delta)
	swing_remaining = maxf(0.0, swing_remaining - delta)
	if not game.cinematic_active:
		update_days()
	_update_held_tool()


