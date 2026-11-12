extends SubViewportContainer
var model:Node3D
var animator:AnimationPlayer
var time:=0.0
var view:SubViewport
var base_height:=0.0
var animated_fish:=false

func setup(object:Node3D,is_fish:bool,clip_suffix:="") -> void:
	animated_fish=is_fish
	time=randf()*TAU
	custom_minimum_size=Vector2(128,108)
	stretch=true
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	mouse_target = true
	view=SubViewport.new()
	view.size=Vector2i(160,128)
	view.transparent_bg=true
	view.own_world_3d=true
	view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	view.handle_input_locally=false
	view.gui_disable_input = true
	add_child(view)
	var stage:=Node3D.new()
	view.add_child(stage)
	model=object
	stage.add_child(model)
	var bounds:=preload("res://scripts/core/island_static_setup.gd").bounds(model)
	var factor:=1.35/maxf(.01,maxf(bounds.size.x,maxf(bounds.size.y,bounds.size.z)))
	model.scale*=factor
	model.position-=bounds.get_center()*factor
	base_height=model.position.y
	var environment:=WorldEnvironment.new()
	environment.environment=Environment.new()
	environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color=Color(.94,.91,.83)
	environment.environment.ambient_light_energy=.8
	stage.add_child(environment)
	var light:=DirectionalLight3D.new()
	light.rotation_degrees=Vector3(-45,-35,0)
	light.light_energy=.85
	stage.add_child(light)
	var camera:=Camera3D.new()
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.size=1.9
	stage.add_child(camera)
	camera.position=Vector3(1.7,.7,2.0)
	camera.look_at(Vector3.ZERO)
	camera.make_current()
	var players:=model.find_children("*","AnimationPlayer",true,false)
	if not players.is_empty():
		animator=players[0]
		var chosen:=""
		if not clip_suffix.is_empty() and animator.has_animation(clip_suffix):
			chosen = clip_suffix
		else:
			for name in animator.get_animation_list():
				if name=="RESET":continue
				if chosen.is_empty():chosen=name
				if not clip_suffix.is_empty() and name.ends_with(clip_suffix):chosen=name;break
		if not chosen.is_empty():
			animator.get_animation(chosen).loop_mode=Animation.LOOP_LINEAR
			animator.play(chosen)
			animator.seek(randf()*animator.get_animation(chosen).length,true)
			animator.speed_scale=2.0

func _propagate_input_event(_event: InputEvent) -> bool:
	return false

func _process(delta:float) -> void:
	var visible_now:=is_visible_in_tree()
	view.render_target_update_mode=SubViewport.UPDATE_ALWAYS if visible_now else SubViewport.UPDATE_DISABLED
	if animator:animator.active=visible_now
	if not visible_now:return
	time+=delta
	if animated_fish:
		model.position.y=base_height+maxf(0.0,sin(time*7.0))*.07
		model.rotation.z=sin(time*11.0)*.10
	else:model.rotation.y=sin(time*.65)*.18
