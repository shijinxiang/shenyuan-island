extends Node3D

signal landed
const Utility=preload("res://scripts/core/island_static_setup.gd")
var item:Dictionary={}
var visual:Node3D
var animator:AnimationPlayer
var player:CharacterBody3D
var boat:Node3D
var boat_local:=Vector3.ZERO
var landed_on_ground:=false
var picked:=false
var deceased := false
var floating := false
var flight_time:=0.0
var elapsed:=0.0
var launch_position:=Vector3.ZERO
var lift_position:=Vector3.ZERO
var landing_position:=Vector3.ZERO
var landing_normal:=Vector3.UP
var release_position:=Vector3.ZERO
var visual_rest_height:=0.0
var fish_length:=.4
var heading:=0.0
var clip_name:=""

func configure(model:Node3D,record:Dictionary,actor:CharacterBody3D,source:Vector3,source_clip:String) -> void:
	item=record
	player=actor
	visual=model
	visual.name="FishModel"
	visual.position=Vector3.ZERO
	visual.rotation=Vector3.ZERO
	add_child(visual)
	clip_name=source_clip
	fish_length=float(item.get("length_m",.4))
	heading=randf()*TAU
	visual.rotation.z=PI*.5
	var bounds:=Utility.bounds(visual)
	visual_rest_height=-bounds.position.y+.012
	visual.rotation=Vector3.ZERO
	for mesh:MeshInstance3D in Utility.meshes(visual):mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	launch_position=source
	landing_position=actor.global_position
	position=source
	if is_instance_valid(actor.rowing) and actor.rowing.boarded:
		boat=actor.rowing
		var stand:Vector3=boat.fishing_deck_position
		boat_local=Vector3(clampf(stand.x+(.30 if stand.x<=0 else -.30),-.4,.4),stand.y+.018,clampf(stand.z,.45,.65))
		if fish_length>1.0:boat_local=Vector3(0,.74,-.35)

func _ready() -> void:
	var players:=visual.find_children("*","AnimationPlayer",true,false)
	if not players.is_empty():
		animator=players[0]
		if deceased:
			animator.stop()
		else:
			if clip_name.is_empty():
				for animation_name in animator.get_animation_list():
					if animation_name!="RESET":clip_name=animation_name;break
			if animator.has_animation(clip_name):
				animator.get_animation(clip_name).loop_mode=Animation.LOOP_LINEAR
				animator.play(clip_name)
				animator.speed_scale=2.2
	if item.get("corpse", false):
		# Freeze the skin in its rendered rest pose before measuring or picking it.
		# Rig bind transforms can make the raw mesh bounds much larger than the animal.
		for skeleton: Skeleton3D in visual.find_children("*", "Skeleton3D", true, false):
			skeleton.force_update_all_bone_transforms()
		for mesh: MeshInstance3D in Utility.meshes(visual):
			if mesh.get_node_or_null(mesh.skeleton) is Skeleton3D:
				var frozen := mesh.bake_mesh_from_current_skeleton_pose()
				if frozen:
					for surface in frozen.get_surface_count():
						frozen.surface_set_material(surface, mesh.get_active_material(surface))
					mesh.mesh = frozen
					mesh.skin = null
					mesh.skeleton = NodePath("")
		visual.rotation = Vector3(0, 0, PI * .5)
		visual.position = Vector3.ZERO
		var bounds := Utility.bounds(visual)
		visual.scale *= fish_length / maxf(.01, maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z)))
		bounds = Utility.bounds(visual)
		visual_rest_height = global_position.y - bounds.position.y + .012
	if not landed_on_ground:_choose_landing()
	if landed_on_ground:global_position=landing_position

func _choose_landing() -> void:
	if is_instance_valid(boat):
		landing_position=boat.boat_visual.to_global(boat_local/boat.boat_visual.scale)
		return
	if not is_instance_valid(player) or player.swimming:return
	var right:Vector3=player.visual.global_basis.x.normalized()
	var forward:Vector3=player.visual.global_basis.z.normalized()
	var distance:=maxf(.65,fish_length*.5+.35)
	for offset in [right*distance+forward*.15,-right*distance+forward*.15,forward*distance,-forward*distance,Vector3.ZERO]:
		var candidate:Vector3=player.global_position+offset
		var query:=PhysicsRayQueryParameters3D.create(candidate+Vector3.UP*.8,candidate-Vector3.UP*1.3,1,[player.get_rid()])
		var hit:=get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty() or hit.normal.y<.65:continue
		if absf(hit.position.y-player.global_position.y)>.55:continue
		landing_position=hit.position
		landing_normal=hit.normal
		return

func restore_position(record:Dictionary) -> void:
	deceased = bool(record.get("deceased", false))
	floating = bool(record.get("floating", false))
	heading = float(record.get("heading", heading))
	var point:Array=record.get("position",[0,0,0])
	landing_position=Vector3(point[0],point[1],point[2])
	var normal:Array=record.get("normal",[0,1,0])
	landing_normal=Vector3(normal[0],normal[1],normal[2]).normalized()
	if record.get("on_boat",false) and is_instance_valid(player.rowing):
		boat=player.rowing
		var local_point:Array=record.get("boat_local",[.3,.26,.62])
		boat_local=Vector3(local_point[0],local_point[1],local_point[2])
	else:boat=null
	landed_on_ground=true
	position=landing_position

func save_record() -> Dictionary:
	return {"item":item,"position":[landing_position.x,landing_position.y,landing_position.z],"normal":[landing_normal.x,landing_normal.y,landing_normal.z],"on_boat":is_instance_valid(boat),"boat_local":[boat_local.x,boat_local.y,boat_local.z],"deceased":deceased,"floating":floating,"heading":heading}

func _process(delta:float) -> void:
	if picked:return
	elapsed+=delta
	if not landed_on_ground:
		flight_time+=delta
		if flight_time<.85:
			lift_position=player.global_position+Vector3.UP*1.4+player.visual.global_basis.z*.25
			var weight:=clampf(flight_time/.85,0.,1.)
			global_position=launch_position.lerp(lift_position,weight)+Vector3.UP*sin(weight*PI)*1.1
			release_position=global_position
			_choose_landing()
		else:
			if flight_time<1.05:_choose_landing()
			if is_instance_valid(boat):landing_position=boat.boat_visual.to_global(boat_local/boat.boat_visual.scale)
			var weight:=clampf((flight_time-.85)/.65,0.,1.)
			global_position=release_position.lerp(landing_position,weight)+Vector3.UP*sin(weight*PI)*.45
			if weight>=1.0:
				landed_on_ground=true
				landed.emit()
		visual.rotation=Vector3(0,heading+flight_time*3.0,lerpf(0.,PI*.5,clampf(flight_time/1.5,0.,1.)))
		visual.position.y=visual_rest_height*clampf((flight_time-.85)/.65,0.,1.)
		return
	if is_instance_valid(boat):
		global_transform=Transform3D(boat.boat_visual.global_basis.orthonormalized(),boat.boat_visual.to_global(boat_local/boat.boat_visual.scale))
	else:
		var tangent:=Vector3.FORWARD.cross(landing_normal).normalized()
		global_transform=Transform3D(Basis(tangent,landing_normal,tangent.cross(landing_normal).normalized()),landing_position)
	if deceased:
		visual.rotation = Vector3(0, heading, PI * .5)
		visual.position.y = visual_rest_height * (.5 if floating else 1.0)
		return
	var burst:=smoothstep(-.35,.45,sin(elapsed*1.8))
	var strength:=lerpf(1.0,.35,clampf((elapsed-15.0)/90.0,0.,1.))
	visual.rotation=Vector3(sin(elapsed*13.0)*.08*burst,heading+sin(elapsed*11.0)*.13*burst,PI*.5+sin(elapsed*16.0)*.16*burst*strength)
	visual.position.y=visual_rest_height+maxf(0.0,sin(elapsed*12.0))*.065*burst*strength
	if animator:animator.speed_scale=lerpf(.5,2.8,burst)*strength
