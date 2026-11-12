class_name PDVFX
extends RefCounted
## Pixel Dreamer VFX helpers - scale, aim and spawn any effect from code.
##
## Why: Godot particles ignore the node's scale by default (particles live in world
## space and billboard materials drop the scale). PDVFX.set_scale() fixes both.
##
##   var fx := PDVFX.spawn(preload("res://addons/.../Explosion.tscn"), self, hit_pos, 2.0)
##   PDVFX.aim(fx, enemy.global_position)      # fire a fountain/geyser/sparks sideways at a target
##   PDVFX.set_angle(fx, 45.0)                 # tilt a slash arc on screen
##   PDVFX.set_scale(fx, 0.5)                  # half size
##   PDVFX.play(fx)                            # restart one-shot effects
##   await PDVFX.warm_up([preload(...)], self) # loading screen: prepare effects ahead of time


## Scale an effect (3D or 2D). 1.0 = original size.
static func set_scale(fx: Node, s: float) -> void:
	if fx is Node3D:
		(fx as Node3D).scale = Vector3.ONE * s
	elif fx is Node2D:
		(fx as Node2D).scale = Vector2.ONE * s
	for p in _all(fx, "GPUParticles3D"):
		p.local_coords = true
		for i in p.draw_passes:
			var m: Mesh = p.get("draw_pass_%d" % (i + 1))
			if m == null:
				continue
			var mat = m.surface_get_material(0) if m.get_surface_count() > 0 else null
			if mat is StandardMaterial3D and mat.billboard_mode == BaseMaterial3D.BILLBOARD_PARTICLES and not mat.billboard_keep_scale:
				var m2: Mesh = m.duplicate()
				var mat2: StandardMaterial3D = mat.duplicate()
				mat2.billboard_keep_scale = true
				m2.surface_set_material(0, mat2)
				p.set("draw_pass_%d" % (i + 1), m2)
	for p in _all(fx, "GPUParticles2D"):
		p.local_coords = true


## Turn camera-facing (billboard) effects on screen, e.g. tilt a slash arc.
## Rotating the node does not turn billboards - they always face the camera.
static func set_angle(fx: Node, degrees: float) -> void:
	for p in _all(fx, "GPUParticles3D") + _all(fx, "GPUParticles2D"):
		var pm = p.process_material
		if pm is ParticleProcessMaterial:
			if not pm.has_meta("pd_base_angle"):
				pm = pm.duplicate()
				pm.set_meta("pd_base_angle", Vector2(pm.angle_min, pm.angle_max))
				p.process_material = pm
			var b: Vector2 = pm.get_meta("pd_base_angle")
			pm.angle_min = b.x + degrees
			pm.angle_max = b.y + degrees



## Point the effect's up axis (+Y) at a world position - for effects that shoot upward
## (fountains, geysers, pillars, sparks) when you want them to fire sideways or at a target.
static func aim(fx: Node3D, target: Vector3) -> void:
	var from := fx.global_position if fx.is_inside_tree() else fx.position
	var d := target - from
	if d.length() < 0.0001:
		return
	var b := Basis(Quaternion(Vector3.UP, d.normalized())).scaled(fx.basis.get_scale())
	if fx.is_inside_tree():
		fx.global_basis = b
	else:
		fx.basis = b


## Restart every particle system inside the effect (one-shot effects: cast, hit, burst).
static func play(fx: Node) -> void:
	if fx.has_method("play"):
		fx.play()
		return
	for p in _all(fx, "GPUParticles3D") + _all(fx, "GPUParticles2D"):
		p.restart()


## Instance an effect under a parent at a position (Vector3 for 3D, Vector2 for 2D), scaled, and play it.
static func spawn(scene: PackedScene, parent: Node, pos, s: float = 1.0) -> Node:
	var fx := scene.instantiate()
	parent.add_child(fx)
	if fx is Node3D:
		if fx.is_inside_tree():
			(fx as Node3D).global_position = pos
		else:
			(fx as Node3D).position = pos
	elif fx is Node2D:
		if fx.is_inside_tree():
			(fx as Node2D).global_position = pos
		else:
			(fx as Node2D).position = pos
	if s != 1.0:
		set_scale(fx, s)
	play(fx)
	return fx


## Load and show each effect once, for a few frames, so its textures and shaders are
## prepared now instead of on first play. Call it behind a loading screen or fade: each batch
## is shown in front of the current camera, then freed. Accepts PackedScenes or res:// paths.
##   await PDVFX.warm_up([preload("res://addons/.../Fireball_Orange.tscn"), "res://.../Heal.tscn"], self)
static func warm_up(scenes: Array, parent: Node, frames: int = 3, batch: int = 16) -> void:
	var tree := parent.get_tree()
	var vp := parent.get_viewport()
	var i := 0
	while i < scenes.size():
		var cam := vp.get_camera_3d()
		var live := []
		for s in scenes.slice(i, i + batch):
			var ps: PackedScene = s if s is PackedScene else load(s)
			if ps == null:
				continue
			var fx := ps.instantiate()
			parent.add_child(fx)
			if fx is Node3D and cam:
				(fx as Node3D).global_position = cam.global_position - cam.global_basis.z * 4.0
			elif fx is Node2D:
				(fx as Node2D).global_position = vp.get_canvas_transform().affine_inverse() * (vp.get_visible_rect().size * 0.5)
			# show every part at once (a projectile's bolt and hit normally wait for launch())
			for n in fx.find_children("*", "", true, false):
				if n is Node3D or n is CanvasItem:
					n.visible = true
			for p in _all(fx, "GPUParticles3D") + _all(fx, "GPUParticles2D"):
				p.emitting = true
				p.restart()
			live.append(fx)
		for f in frames:
			await tree.process_frame
		for fx in live:
			fx.queue_free()
		i += batch


static func _all(fx: Node, type: String) -> Array:
	var out := fx.find_children("*", type, true, false)
	if fx.is_class(type):
		out.push_front(fx)
	return out
