extends RefCounted
const Utility=preload("res://scripts/core/island_static_setup.gd")

static func setup(scene:Node3D) -> void:
	var player:CharacterBody3D=scene.get_node("Player")
	player.show()
	player.set_physics_process(true)
	player.set_process_unhandled_input(true)
	if not player.has_node("Visual"):
		var visual:=Utility.local_model("res://assets/characters/C01_locomotion.glb")
		visual.name="Visual"
		visual.rotation.y=.65
		player.add_child(visual)
		Utility.own_tree(visual,scene)
	var character:Node3D=player.get_node("Visual")
	Utility.style(character,"character")
	for mesh in Utility.meshes(character):mesh.visibility_range_end=0.
	var marker:=player.get_node_or_null("MovementMarker")
	if marker:marker.free()
	var collision:CollisionShape3D=player.find_children("*","CollisionShape3D",false,false)[0]
	var capsule:=CapsuleShape3D.new();capsule.radius=.27;capsule.height=1.68
	collision.shape=capsule;collision.position.y=.84
	player.collision_layer=2;player.collision_mask=1
	var hud:=scene.get_node_or_null("HUD")
	if hud:
		hud.show()
		var text:Label=hud.get_node("HelpPanel/HelpText")
		text.text="WASD 移动 · Shift 加速 · 深水自动游泳\nV 第三人称 · 右键转视角 · 滚轮缩放\nE 拾取 / 上下船 · F 钓鱼 · B 背包 · R 回码头"
	if scene.is_inside_tree():
		add_obstacle_collisions(scene)
		preload("res://scripts/player/follow_camera_safety.gd").add_camera_occluders(scene)

static func add_obstacle_collisions(scene:Node3D) -> void:
	if scene.has_node("TraversalCollisions"):return
	var group:=Node3D.new();group.name="TraversalCollisions";scene.add_child(group)
	var trees:=0;var rocks:=0
	for actor in scene.get_node("AllIslandStatic").get_children():
		var category:String=actor.get_meta("category","")
		var ground:Vector3=actor.get_meta("ground_position",actor.position)
		if category=="tree":
			var body:=StaticBody3D.new();body.name=String(actor.name)+"_Trunk";group.add_child(body)
			body.position=ground+Vector3.UP*.90
			var shape:=CylinderShape3D.new();shape.height=1.90;shape.radius=clampf(float(actor.get_meta("grass_clearance_radius",.3))*.55,.12,.35)
			var collider:=CollisionShape3D.new();collider.shape=shape;body.add_child(collider);trees+=1
		elif category=="large_rock" and ground.y>.2:
			var bounds:=Utility.bounds(actor)
			if maxf(bounds.size.x,maxf(bounds.size.y,bounds.size.z))<1.25:continue
			for mesh in Utility.meshes(actor):
				if mesh.has_node("TraversalCollision"):continue
				var body:=StaticBody3D.new();body.name="TraversalCollision";mesh.add_child(body)
				var collider:=CollisionShape3D.new();collider.shape=mesh.mesh.create_trimesh_shape();body.add_child(collider)
			rocks+=1
	print("TRAVERSAL_COLLISIONS trees=",trees," rocks=",rocks)
