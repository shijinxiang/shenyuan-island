extends Node3D

enum State {READY,CASTING,WAITING,BITE,REELING,CAUGHT}
const FISH_NAMES:={"BrownFish":"褐鳞鱼","ClownFish":"小丑鱼","DoryFish":"蓝刺尾鱼","TunaFish":"金枪鱼","Eel":"海鳗","Piranha":"红腹食人鱼","fish01":"小丑鱼","fish01_shade":"小丑鱼","fish02":"青背小鱼","fish02_shade":"青背小鱼","fish03":"蓝鳍小鱼","fish03_shade":"蓝鳍小鱼"}
const SAVE_PATH:="user://fishing_catches.json"
var player:CharacterBody3D
var wildlife:Node3D
var skeleton:Skeleton3D
var rod:Node3D
var rod_skeleton:Skeleton3D
var tip:Node3D
var hook:Node3D
var hook_anchor:=Vector3.ZERO
var line:MeshInstance3D
var line_mesh:=ImmediateMesh.new()
var line_material:=StandardMaterial3D.new()
var state:=State.READY
var state_time:=0.0
var elapsed:=0.0
var cast_duration:=4.0
var cast_from:=Vector3.ZERO
var target:=Vector3.ZERO
var hook_position:=Vector3.ZERO
var landed:=false
var selected_fish:Dictionary={}
var tension:=.25
var progress:=0.0
var catches:Array=[]
var caught_display:Node3D
var notice:=""
var notice_time:=0.0
var prompt:Label
var panel:VBoxContainer
var meters:HBoxContainer
var progress_bar:ProgressBar
var tension_bar:ProgressBar
var inventory:PanelContainer
var inventory_text:Label
var rng:=RandomNumberGenerator.new()
var locomotion:RefCounted
var dropped_fish:Node3D
var fish_definitions:Dictionary={}
var pickup_candidate:Node3D
var inventory_items:ItemList
var inventory_details:Label
var progress_data:Dictionary={}

func _ready() -> void:
	rng.randomize()
	player=get_parent().get_node("Player")
	wildlife=get_parent().get_node("IslandWildlife")
	skeleton=player.visual.find_children("*","Skeleton3D",true,false)[0]
	player.fishing=self
	locomotion=preload("res://scripts/fishing/fishing_locomotion.gd").new(player)
	dropped_fish=Node3D.new()
	dropped_fish.name="GroundFish"
	add_child(dropped_fish)
	var manifest:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/fauna/habitats.json"))
	for definition:Dictionary in manifest.species:fish_definitions[definition.name]=definition
	if not InputMap.has_action("fishing_reel"):
		InputMap.add_action("fishing_reel")
		var button:=InputEventMouseButton.new()
		button.button_index=MOUSE_BUTTON_LEFT
		InputMap.action_add_event("fishing_reel",button)
	rod=load("res://assets/fishing/fishing_rod_rigged.glb").instantiate()
	rod.name="HeldFishingRod"
	add_child(rod)
	rod_skeleton=rod.find_children("*","Skeleton3D",true,false)[0]
	for animation:AnimationPlayer in rod.find_children("*","AnimationPlayer",true,false):animation.stop()
	tip=rod.find_child("LineTip",true,false)
	hook=load("res://assets/fishing/fishing_hook.glb").instantiate()
	add_child(hook)
	hook_anchor=hook.to_local(hook.find_child("HookAttach",true,false).global_position)
	line=MeshInstance3D.new()
	line.mesh=line_mesh
	line.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	line_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	line_material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	line_material.albedo_color=Color(.64,.72,.70,.75)
	line_material.render_priority=15
	add_child(line)
	rod.hide()
	hook.hide()
	line.hide()
	player.animation.get_animation("FishCast").loop_mode=Animation.LOOP_NONE
	var ground_records:Array=[]
	if FileAccess.file_exists(SAVE_PATH):
		var loaded:Variant=JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
		if loaded is Dictionary:
			if loaded.get("progress") is Dictionary:progress_data=loaded.progress
			var items:Variant=loaded.get("items",loaded.get("catches",[]))
			if items is Array:catches=items
			if loaded.get("ground_fish") is Array:ground_records=loaded.ground_fish
	_setup_ui()
	for record:Dictionary in ground_records:
		var item:Dictionary=record.get("item",{})
		var corpse: bool = item.get("corpse", false) and item.get("corpse_kind", "") in ["marine","bird","crocodile"]
		if not corpse and not fish_definitions.has(item.get("species","")) and item.get("goods_id", "") not in ["animal_meat", "crocodile_meat", "shark_meat"]:continue
		var owned:=false
		for existing:Dictionary in catches:
			if existing.get("id","")==item.get("id","missing"):owned=true;break
		if owned:continue
		var model:=_fish_model(item)
		var physical=preload("res://scripts/fishing/caught_fish.gd").new()
		physical.configure(model,item,player,Vector3.ZERO,"")
		physical.restore_position(record)
		dropped_fish.add_child(physical)
		physical.landed.connect(_save_catches)
	print("FISHING_READY saved_catches=",catches.size())

func toggle() -> void:
	set_active(not player.fishing_active)

func set_active(active:bool,reset_movement:=true) -> void:
	if active and (player.in_vehicle() or player.interaction_time > 0):
		return
	if active and is_instance_valid(player.adventure):
		if not player.adventure.progress.rod_found:
			_show_notice("木屋里有一支留给你的鱼竿。",3.0)
			return
		player.adventure.harpoon_equipped=false
	if active and player.swimming:
		_show_notice("先上岸或登船，再开始钓鱼",2.5)
		return
	_cleanup_target()
	player.fishing_active=active
	rod.visible=active
	hook.visible=active
	line.visible=active
	caught_display=null
	locomotion.stop()
	state=State.READY
	state_time=0.0
	if reset_movement:player.velocity=Vector3.ZERO
	if is_instance_valid(player.rowing) and player.rowing.boarded:
		player.rowing.drive_speed=0.0
		player.rowing.paddle.visible=not active
	if active:
		player._play_motion("FishIdle",1.0)
		player.animation.advance(0.0)
		_update_gear()
	else:
		var idle_clip:="SwimIdle" if player.swimming else "Idle"
		if is_instance_valid(player.rowing) and player.rowing.boarded:idle_clip="PaddleIdle"
		player._play_motion(idle_clip,1.0)

func _input(event:InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode==KEY_I or event.keycode==KEY_B:
			if is_instance_valid(player.adventure):
				player.adventure.ui.toggle_bag()
				get_viewport().set_input_as_handled()
				return
			inventory.visible=not inventory.visible
			_update_inventory()
			get_viewport().set_input_as_handled()
		elif event.keycode==KEY_ESCAPE and inventory.visible:
			inventory.hide()
			get_viewport().set_input_as_handled()

func _unhandled_input(event:InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode==KEY_ESCAPE and player.fishing_active:set_active(false)
	if not player.fishing_active:return
	if event.is_action_pressed("fishing_reel"):
		match state:
			State.READY:cast_at(_aim_water())
			State.WAITING:
				_cleanup_target()
				_set_state(State.READY)
				_show_notice("已收回鱼钩，可以重新抛竿",2.0)
			State.BITE:
				tension=.25
				progress=0.0
				_set_state(State.REELING)

func _aim_water() -> Vector3:
	var camera:=get_viewport().get_camera_3d()
	var mouse:=get_viewport().get_mouse_position()
	var hit:Variant=Plane(Vector3.UP,0.0).intersects_ray(camera.project_ray_origin(mouse),camera.project_ray_normal(mouse))
	var point:Vector3=hit if hit is Vector3 else player.global_position+player.visual.global_basis.z*10.0
	var offset:=point-player.global_position
	offset.y=0.0
	if offset.length()<3.0:offset=player.visual.global_basis.z*8.0
	point=player.global_position+offset.normalized()*clampf(offset.length(),4.0,16.0)
	point.y=-.28
	return point

func cast_at(point:Vector3) -> void:
	if state!=State.READY or not player.fishing_active:return
	var column:Vector2=wildlife.schools.column(point)
	if column.x>-.65:
		_show_notice("请把鱼钩抛向水面",2.5)
		return
	var direction:=point-player.global_position
	var horizontal:=Vector2(direction.x,direction.z)
	if horizontal.length()>16.1 or horizontal.length()<3.0:return
	target=point
	var zone:="lake" if column.y>.5 else "ocean"
	var nearest:=INF
	for fish:Dictionary in wildlife.fish:
		if fish.get("caught",false) or not FISH_NAMES.has(fish.species) or fish.habitat!=zone:continue
		var distance:float=fish.node.global_position.distance_to(point)
		if distance<nearest and distance<26.0:
			selected_fish=fish
			nearest=distance
	var angle:=atan2(direction.x,direction.z)
	player.visual.global_rotation.y=angle
	landed=false
	player._play_motion("FishCast",2.1)
	cast_duration=player.animation.get_animation("FishCast").length/2.1
	cast_from=tip.global_position
	_set_state(State.CASTING)

func _set_state(value:State) -> void:
	state=value
	state_time=0.0

func _process(delta:float) -> void:
	elapsed+=delta
	notice_time=maxf(0.0,notice_time-delta)
	pickup_candidate=_nearest_drop()
	panel.visible=player.fishing_active or notice_time>0.0 or is_instance_valid(pickup_candidate)
	if not player.fishing_active:
		if notice_time>0:prompt.text=notice
		elif is_instance_valid(pickup_candidate):prompt.text=player.adventure.hunting.pickup_text(pickup_candidate)
		meters.hide()
		return
	state_time+=delta
	var skills: Node = player.adventure.skills
	if state in [State.CASTING, State.WAITING, State.BITE, State.REELING] and selected_fish.get("predated", false):
		_cleanup_target()
		_set_state(State.READY)
		_show_notice("鱼被鳄鱼抢走了，换个地方试试。", 3.0)
	locomotion.update(delta)
	_update_gear()
	if state in [State.CASTING,State.WAITING,State.BITE,State.REELING] and player.global_position.distance_to(target)>27.0:
		_cleanup_target()
		_set_state(State.READY)
		_show_notice("已走出鱼线范围，鱼钩已收回",2.5)
	match state:
		State.READY:
			player._play_motion("FishIdle",1.0)
			hook_position=tip.global_position+Vector3.DOWN*.35
		State.CASTING:
			var release:=cast_duration*.30
			if state_time<release:
				cast_from=tip.global_position
				hook_position=cast_from+Vector3.DOWN*.25
			else:
				var weight:=clampf((state_time-release)/.9,0.,1.)
				hook_position=cast_from.lerp(target,weight)+Vector3.UP*sin(weight*PI)*2.0
				if weight>=1.0 and not landed:
					landed=true
					_splash(target)
					if not selected_fish.is_empty():selected_fish.fishing_target=Vector3(target.x,minf(-.65,point_depth(target)*.5),target.z)
			if state_time>=cast_duration:_set_state(State.WAITING)
		State.WAITING:
			player._play_motion("FishIdle",1.0)
			hook_position=target+Vector3.UP*sin(elapsed*1.8)*.025
			if not selected_fish.is_empty() and state_time>2.0 and selected_fish.node.global_position.distance_to(target)<1.35:
				if rng.randf() <= skills.bite_chance():
					_set_state(State.BITE)
					_splash(target)
				else:
					_cleanup_target()
					_set_state(State.READY)
					_show_notice("鱼试探后游走了。积累钓鱼经验或升级鱼竿会更容易咬钩。", 3.0)
			elif state_time>28.0:
				_cleanup_target()
				_set_state(State.READY)
				_show_notice("鱼没有咬钩，换个位置再试试",3.0)
		State.BITE:
			hook_position=target+Vector3.UP*sin(elapsed*14.0)*.10
			if state_time>skills.bite_window():
				_cleanup_target()
				_set_state(State.READY)
				_show_notice("错过了提竿时机，鱼游走了",2.5)
		State.REELING:
			var held:=Input.is_action_pressed("fishing_reel")
			var struggle:=.5+.5*sin(elapsed*2.4+float(selected_fish.get("wander",0.0)))
			var size:float=selected_fish.get("fish_length",.4)
			tension=clampf(tension+delta*((.12+struggle*.11+size*.025) * skills.tension_factor() if held else -.32),0.,1.)
			progress=clampf(progress+delta*(skills.reel_speed() if held else -.025),0.,1.)
			hook_position=target.lerp(tip.global_position,progress*.65)
			hook_position.y=-.25+sin(elapsed*7.0)*.08
			selected_fish.fishing_target=hook_position+Vector3.DOWN*.32
			player._play_motion("FishIdle",1.35 if held else 1.0)
			if tension>=1.0:
				_cleanup_target()
				_set_state(State.READY)
				_show_notice("鱼线张力过高，鱼挣脱了",3.0)
			elif progress>=1.0:_land_catch()
		State.CAUGHT:
			hook_position=caught_display.global_position if is_instance_valid(caught_display) and caught_display.flight_time<.85 else tip.global_position+Vector3.DOWN*.35
			if state_time>1.8:
				caught_display=null
				_set_state(State.READY)
	hook.global_position=hook_position-hook.global_basis*hook_anchor
	_draw_line()
	_update_prompt()

func point_depth(point:Vector3) -> float:
	return wildlife.schools.column(point).x

func _update_gear() -> void:
	var right:=_hand_center("RightHand","RightHandMiddle1")
	var aim:Vector3=player.visual.global_basis.z if state==State.READY else target-player.global_position
	aim.y=0.0
	aim=aim.normalized()
	var elevation:=.85
	if state==State.CASTING:
		var phase:=clampf(state_time/maxf(cast_duration,.1),0.,1.)
		if phase<.27:elevation=lerpf(.85,1.95,smoothstep(0.,.27,phase))
		elif phase<.48:elevation=lerpf(1.95,.48,smoothstep(.27,.48,phase))
		else:elevation=lerpf(.48,.85,smoothstep(.48,1.,phase))
	elif state==State.REELING:elevation+=tension*.18
	elif state==State.CAUGHT:elevation=lerpf(1.45,.62,smoothstep(.45,1.5,state_time))
	var axis:=aim*cos(elevation)+Vector3.UP*sin(elevation)
	var x_axis:Vector3=player.visual.global_basis.x-axis*player.visual.global_basis.x.dot(axis)
	x_axis=x_axis.normalized()
	rod.global_transform=Transform3D(Basis(x_axis,axis,x_axis.cross(axis).normalized()),right)
	var bend:=.015
	if state==State.BITE:bend=.08+.025*sin(elapsed*15.0)
	elif state==State.REELING:bend=.025+tension*.09
	for index in range(1,7):rod_skeleton.set_bone_pose_rotation(rod_skeleton.find_bone("Rod_%02d"%index),Quaternion(Vector3.RIGHT,-bend))
	var crank:=elapsed*9.0 if state==State.REELING and Input.is_action_pressed("fishing_reel") else 0.0
	rod_skeleton.set_bone_pose_rotation(rod_skeleton.find_bone("Reel_Crank"),Quaternion(Vector3.UP,crank))
	rod_skeleton.set_bone_pose_rotation(rod_skeleton.find_bone("Reel_Knob"),Quaternion(Vector3.UP,-crank))

func _hand_center(hand:String,finger:String) -> Vector3:
	var a:=skeleton.get_bone_global_pose(skeleton.find_bone(hand)).origin
	var b:=skeleton.get_bone_global_pose(skeleton.find_bone(finger)).origin
	return skeleton.to_global(a.lerp(b,.65))

func _draw_line() -> void:
	line_mesh.clear_surfaces()
	line_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP,line_material)
	var origin:=tip.global_position
	for index in 25:
		var weight:=float(index)/24.0
		var point:=origin.lerp(hook_position,weight)
		point.y-=sin(weight*PI)*(.12 if state==State.REELING else .30)
		line_mesh.surface_add_vertex(to_local(point))
	line_mesh.surface_end()

func _splash(point:Vector3) -> void:
	player.get_node("MovementVFX")._spawn_water(Vector3(point.x,.035,point.z),.8)

func _cleanup_target() -> void:
	if not selected_fish.is_empty():selected_fish.erase("fishing_target")
	selected_fish={}

func _land_catch() -> void:
	var species:String=selected_fish.species
	var length:float=selected_fish.get("fish_length",.4)
	var weight:=snappedf((.12+pow(length,3.0)*2.0)*rng.randf_range(.75,1.25),.01)
	var entry:={"id":str(Time.get_unix_time_from_system())+"_"+str(rng.randi()),"species":species,"name":FISH_NAMES[species],"weight_kg":weight,"length_m":length,"habitat":selected_fish.habitat,"time":Time.get_datetime_string_from_system()}
	var model:Node3D=selected_fish.node.duplicate(Node.DUPLICATE_SIGNALS|Node.DUPLICATE_GROUPS|Node.DUPLICATE_SCRIPTS)
	model.show()
	var physical=preload("res://scripts/fishing/caught_fish.gd").new()
	var clip:String=selected_fish.animator.current_animation if selected_fish.animator else ""
	physical.configure(model,entry,player,hook_position,clip)
	dropped_fish.add_child(physical)
	physical.landed.connect(_save_catches)
	caught_display=physical
	target=hook_position
	selected_fish.caught=true
	selected_fish.node.hide()
	_cleanup_target()
	player.adventure.skills.add_xp("fishing", 10 + roundi(length * 2.0))
	_save_catches()
	_update_inventory()
	_set_state(State.CAUGHT)
	player._play_motion("FishCast",2.4)
	player.animation.seek(1.0,false)
	_show_notice("钓到了 %s · %.2f kg，甩到脚边后按 E 拾取"%[entry.name,weight],3.0)

func _save_catches() -> bool:
	var temporary:=SAVE_PATH+".tmp"
	var file:=FileAccess.open(temporary,FileAccess.WRITE)
	if file==null:
		push_warning("Cannot save fishing catches")
		return false
	var ground_records:Array=[]
	for physical in dropped_fish.get_children():
		if not physical.picked:ground_records.append(physical.save_record())
	file.store_string(JSON.stringify({"version":3,"items":catches,"ground_fish":ground_records,"progress":progress_data},"  "))
	file.close()
	var error:=DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary),ProjectSettings.globalize_path(SAVE_PATH))
	if error!=OK:push_warning("Catch save replacement failed: "+str(error))
	return error==OK

func _fish_model(item:Dictionary) -> Node3D:
	if item.get("corpse", false):
		if item.corpse_kind == "marine" and fish_definitions.has(item.corpse_species):
			return _fish_model({"species":item.corpse_species,"length_m":item.length_m})
		var path := "res://assets/fauna/birds/American_Robin.glb" if item.corpse_kind == "bird" else "res://assets/survival/saltwater_crocodile.glb"
		var model: Node3D = load(path).instantiate()
		var bounds: AABB = preload("res://scripts/core/island_static_setup.gd").bounds(model)
		model.scale *= float(item.get("length_m", .5)) / maxf(.01, maxf(bounds.size.x, maxf(bounds.size.y,bounds.size.z)))
		return model
	if item.has("goods_id"):
		return load("res://assets/cooking/meat.glb").instantiate()
	var definition:Dictionary=fish_definitions[item.species]
	var actor:=Node3D.new()
	actor.scale=Vector3.ONE*float(item.get("length_m",definition.length))/float(definition.length)
	var facing:=Node3D.new()
	facing.rotation.y=definition.yaw
	actor.add_child(facing)
	var model:Node3D=load("res://assets/fauna/marine/"+item.species+".glb").instantiate()
	facing.add_child(model)
	model.scale=Vector3.ONE*float(definition.scale)
	model.position=Vector3(definition.offset[0],definition.offset[1],definition.offset[2])
	return actor

func _nearest_drop() -> Node3D:
	var nearest:Node3D
	var distance:=2.0
	for physical in dropped_fish.get_children():
		if physical.picked or not physical.landed_on_ground:continue
		var corpse: bool = physical.item.get("corpse", false)
		var point: Vector3 = player.adventure.hunting.corpse_point(physical) if corpse else physical.global_position
		var current:float=point.distance_to(player.global_position)
		if corpse and current > player.adventure.hunting.corpse_reach():continue
		if current<distance:
			nearest=physical
			distance=current
	return nearest

func try_pickup(target: Node3D = null) -> bool:
	var physical := target if is_instance_valid(target) else _nearest_drop()
	if physical == null or physical.picked or not physical.landed_on_ground:
		return false
	if physical.item.get("corpse", false):
		return player.adventure.hunting.process_corpse(physical)
	if physical.global_position.distance_to(player.global_position) > 2.2:
		return false
	physical.picked=true
	var before: Array = progress_data.get("goods", []).duplicate(true)
	if physical.item.has("goods_id"):
		player.adventure._add_good(str(physical.item.goods_id), str(physical.item.name), int(physical.item.get("count", 1)))
	else:
		catches.append(physical.item.duplicate(true))
	if not _save_catches():
		if physical.item.has("goods_id"):
			progress_data.goods = before
		else:
			catches.pop_back()
		physical.picked=false
		_show_notice("背包暂时无法保存，请稍后再拾取",3.0)
		return true
	_show_notice("%s 已放入背包 · B 查看"%physical.item.name,2.5)
	physical.queue_free()
	pickup_candidate=null
	_update_inventory()
	return true

func _show_notice(text:String,seconds:float) -> void:
	if is_instance_valid(player.adventure) and is_instance_valid(player.adventure.ui):
		player.adventure.ui.notify(text,seconds)
		notice_time=0.0
		return
	notice=text
	notice_time=seconds

func _setup_ui() -> void:
	var layer:=CanvasLayer.new()
	add_child(layer)
	panel=VBoxContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	panel.position=Vector2(-265,-130)
	panel.custom_minimum_size=Vector2(530,80)
	layer.add_child(panel)
	prompt=Label.new()
	prompt.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	prompt.add_theme_font_size_override("font_size",18)
	prompt.add_theme_color_override("font_shadow_color",Color.BLACK)
	prompt.add_theme_constant_override("shadow_offset_x",2)
	prompt.add_theme_constant_override("shadow_offset_y",2)
	panel.add_child(prompt)
	meters=HBoxContainer.new()
	panel.add_child(meters)
	for label_text in ["收线","张力"]:
		var label:=Label.new()
		label.text=label_text
		meters.add_child(label)
		var bar:=ProgressBar.new()
		bar.custom_minimum_size=Vector2(205,22)
		bar.show_percentage=false
		meters.add_child(bar)
		if label_text=="收线":progress_bar=bar
		else:tension_bar=bar
	inventory=PanelContainer.new()
	inventory.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	inventory.position=Vector2(-365,150)
	inventory.custom_minimum_size=Vector2(350,390)
	layer.add_child(inventory)
	var contents:=VBoxContainer.new()
	inventory.add_child(contents)
	inventory_text=Label.new()
	inventory_text.add_theme_font_size_override("font_size",17)
	contents.add_child(inventory_text)
	inventory_items=ItemList.new()
	inventory_items.custom_minimum_size=Vector2(330,265)
	inventory_items.size_flags_vertical=Control.SIZE_EXPAND_FILL
	inventory_items.item_selected.connect(_select_inventory_item)
	contents.add_child(inventory_items)
	inventory_details=Label.new()
	inventory_details.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	inventory_details.custom_minimum_size=Vector2(330,65)
	contents.add_child(inventory_details)
	var close_button:=Button.new()
	close_button.text="B / I  关闭背包"
	close_button.pressed.connect(func():inventory.hide())
	contents.add_child(close_button)
	inventory.hide()
	panel.hide()

func _update_inventory() -> void:
	if is_instance_valid(player.adventure) and is_instance_valid(player.adventure.ui):
		player.adventure.ui.refresh_bag()
		return
	inventory_items.clear()
	var total:=0.0
	for index in range(catches.size()-1,-1,-1):
		var entry:Dictionary=catches[index]
		total+=float(entry.weight_kg)
		var row:=inventory_items.add_item("%s    %.2f kg"%[entry.name,float(entry.weight_kg)])
		inventory_items.set_item_metadata(row,entry)
	inventory_text.text="背包 · 渔获 %d 条 · %.2f kg"%[catches.size(),total]
	inventory_details.text="钓到的鱼会落在脚边，按 E 拾取入包。" if catches.is_empty() else "选择一条鱼查看详情。"

func _select_inventory_item(index:int) -> void:
	var entry:Dictionary=inventory_items.get_item_metadata(index)
	var habitat:="内湖" if entry.get("habitat","")=="lake" else "海里"
	inventory_details.text="%s · %.2f kg\n钓获地点 %s\n%s"%[entry.name,float(entry.weight_kg),habitat,str(entry.get("time","")).replace("T"," ")]

func _update_prompt() -> void:
	meters.visible=state==State.REELING
	progress_bar.value=progress*100.0
	tension_bar.value=tension*100.0
	tension_bar.modulate=Color(1,.45,.35) if tension>.78 else Color(.7,.9,1)
	if notice_time>0.0:
		prompt.text=notice
		return
	match state:
		State.READY:prompt.text="左键抛竿 · F 收竿"
		State.CASTING:prompt.text="抛竿中…"
		State.WAITING:prompt.text="等待咬钩 · 左键收回"
		State.BITE:prompt.text="咬钩了！左键提竿"
		State.REELING:prompt.text="按住左键收线 · 松开降低张力"
		State.CAUGHT:prompt.text="鱼已提起，正甩向脚边"
	if is_instance_valid(pickup_candidate) and state in [State.READY,State.WAITING]:prompt.text+="\n"+player.adventure.hunting.pickup_text(pickup_candidate)
