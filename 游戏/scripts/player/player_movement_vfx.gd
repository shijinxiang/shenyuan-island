extends Node

const DUST = preload("res://addons/pd_move_vfx/effects/Dash_Ground.tscn")
const WATER_STEP = preload("res://addons/pd_move_vfx/effects/Footstep_Water_PSX.tscn")
var player:CharacterBody3D
var last_step := -1
var last_motion := ""
var swim_timer := 0.0
var skeleton:Skeleton3D

func _ready() -> void:
	player=get_parent()
	skeleton=player.visual.find_children("*","Skeleton3D",true,false)[0]

func _process(delta:float) -> void:
	if is_instance_valid(player.rowing) and player.rowing.boarded:return
	if player.swimming:
		swim_timer-=delta
		if swim_timer<=0.0 and player.planar_speed>.1 and player.global_position.y>player.water_level-.55:
			swim_timer=.7
			_spawn_water(Vector3(player.global_position.x,player.water_level+.04,player.global_position.z),.7)
		return
	if not player.is_on_floor() or player.planar_speed<.15:return
	var animation:AnimationPlayer=player.fishing.locomotion.legs if player.fishing_active else player.animation
	var motion:String=animation.current_animation if player.fishing_active else player.current_motion
	if not motion in ["Walk","Run"]:return
	if motion!=last_motion:
		last_motion=motion
		last_step=-1
	var step:=int(floor(animation.current_animation_position/maxf(animation.current_animation_length,.01)*2.0))%2
	if step==last_step:return
	last_step=step
	var foot:=skeleton.find_bone("LeftFoot" if step==0 else "RightFoot")
	var position:=skeleton.to_global(skeleton.get_bone_global_pose(foot).origin)
	position.y=player.global_position.y+.035
	if player.water_level>position.y+.1:
		position.y=player.water_level+.04
		_spawn_water(position,.65)
		return
	# Dry soil, grass and sand receive a restrained puff. Decks remain clean.
	var query:=PhysicsRayQueryParameters3D.create(position+Vector3.UP*.4,position-Vector3.UP*.8,1,[player.get_rid()])
	var hit:=player.get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		var collider:Node=hit.collider
		if "P01" in collider.name or "P03" in collider.name or "Pier" in collider.name:return
	var weather:=player.get_parent().get_node_or_null("IslandWeather")
	if weather and weather.rain_amount>.2:return
	_spawn_dust(position,motion=="Run")

func _spawn_dust(position:Vector3,running:bool) -> void:
	var effect:=DUST.instantiate() as Node3D
	for child in effect.get_children():
		if child.name!="Dust_Kick":child.free()
	var dust:GPUParticles3D=effect.get_node("Dust_Kick")
	dust.amount=5 if running else 3
	dust.lifetime=.55 if running else .45
	dust.position.y=.025
	dust.local_coords=false
	dust.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var process:=dust.process_material.duplicate() as ParticleProcessMaterial
	process.initial_velocity_min=.15
	process.initial_velocity_max=.45 if running else .28
	process.gravity=Vector3(0,.08,0)
	process.emission_box_extents=Vector3(.07,.01,.04)
	process.scale_min=.30
	process.scale_max=.55 if running else .42
	process.anim_speed_min=2.0
	process.anim_speed_max=2.0
	dust.process_material=process
	dust.draw_pass_1=dust.draw_pass_1.duplicate()
	var material:=dust.draw_pass_1.surface_get_material(0).duplicate() as StandardMaterial3D
	material.albedo_color=Color(.66,.59,.46,.36 if running else .25)
	material.shading_mode=BaseMaterial3D.SHADING_MODE_PER_PIXEL
	(dust.draw_pass_1 as QuadMesh).material=material
	effect.free_after=.85
	player.get_parent().add_child(effect)
	effect.global_position=position
	effect.rotation.y=player.visual.rotation.y
	effect.play()

func _spawn_water(position:Vector3,size:float) -> void:
	var effect:=WATER_STEP.instantiate() as Node3D
	for particle:GPUParticles3D in effect.find_children("*","GPUParticles3D",true,false):
		particle.draw_pass_1=particle.draw_pass_1.duplicate()
		var material:=particle.draw_pass_1.surface_get_material(0).duplicate() as StandardMaterial3D
		material.render_priority=12
		material.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR
		(particle.draw_pass_1 as QuadMesh).material=material
		particle.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if particle.name=="Droplets":particle.amount=4
	effect.free_after=.9
	player.get_parent().add_child(effect)
	effect.global_position=position
	effect.scale=Vector3.ONE*size
	effect.play()
