extends Node
var game:Node
var camera:Camera3D
var token:=0
var playing:=false
var tweens:Array[Tween]=[]
var saved:Dictionary={}
var departure:Node3D

func _ready() -> void:game=get_parent()

func present() -> void:
	if game.cinematic_active:return
	if game.player.in_vehicle() and not game.vehicle.leave_vehicle():
		game.ui.notify("先把车停在能安全下车的位置，再重看序章。")
		return
	saved={"position":game.player.global_position,"boat":game.player.rowing.global_transform,"hour":game.weather.hour,"weather":game.weather.current_weather,"day":game.day_count,"replay":bool(game.progress.intro_seen),"swimming":game.player.swimming}
	game.fishing.set_active(false)
	game.player.rowing.leave_boat(true)
	game.player.rowing.set_physics_process(false)
	game.player.set_physics_process(false)
	game.cinematic_active=true
	game.ui.bag.hide();game.ui.settings.hide();game.ui.dialog.hide()
	game.ui.cinematic_panel.show();game.ui.intro_buttons.show()
	game.ui.cinematic_title.text="深 渊 岛\n小爱的第一日"
	game.ui.cinematic_caption.text="一次意外的漂流，一段重新开始的人生。"
	game.ui.fade.color=Color(.02,.06,.07,.60)
	camera=Camera3D.new();camera.fov=50;camera.far=1800;game.world.add_child(camera)
	camera.position=Vector3(181,24,179);camera.look_at(Vector3(143,0,130));camera.make_current()

func _move(object:Node,path:String,to:Variant,duration:float) -> void:
	var tween:=create_tween();tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT);tween.tween_property(object,path,to,duration);tweens.append(tween)

func _shot(position:Vector3,destination:Vector3,look:Vector3,duration:float) -> void:
	camera.global_position=position;camera.look_at(look)
	var tween:=create_tween()
	tween.tween_method(func(weight:float):camera.global_position=position.lerp(destination,weight);camera.look_at(look),0.0,1.0,duration)
	tweens.append(tween)

func _wait(seconds:float,id:int) -> bool:
	await get_tree().create_timer(seconds).timeout
	return token==id and game.cinematic_active

func play() -> void:
	if playing:return
	playing=true;token+=1;var id:=token
	game.ui.intro_buttons.hide();game.ui.cinematic_title.text="";game.ui.fade.color.a=0
	var player:CharacterBody3D=game.player
	var boat:Node3D=player.rowing
	boat.global_position=Vector3(238,-.28,209);boat.rotation=Vector3(0,.4,0)
	departure=load("res://assets/optimized/P02.glb").instantiate();game.world.add_child(departure);departure.scale=Vector3.ONE*3.7;departure.position=Vector3(248,-.28,215)
	player.global_basis=Basis(Vector3.UP,.4);player.visual.rotation=Vector3.ZERO;player.global_position=departure.position+Vector3(0,.35,.3);player._play_motion("Idle",1.)
	game.weather.hour=17.5;game.weather.set_weather(1,1.)
	game.ui.cinematic_caption.text="小爱原本以为，这只是一次短途出海。"
	_shot(Vector3(260,7,226),Vector3(255,5,222),departure.position+Vector3.UP,5.0)
	if not await _wait(5.0,id):return
	game.weather.set_weather(3,1.2)
	game.ui.cinematic_caption.text="突来的浪，把她卷进了海里。"
	_move(departure,"rotation:z",.18,.6)
	_move(player,"global_position",Vector3(244,-.15,214),1.0)
	_move(player.visual,"rotation:z",-1.1,.8)
	_shot(Vector3(250,3,221),Vector3(247,2.5,219),Vector3(244,.3,214),4.0)
	if not await _wait(1.0,id):return
	player.visual.rotation=Vector3.ZERO;player._play_motion("Swim",1.4)
	game.player.get_node("MovementVFX")._spawn_water(Vector3(244,.05,214),1.6)
	_move(departure,"position",Vector3(265,-.2,223),4.0)
	if not await _wait(3.0,id):return
	game.ui.cinematic_caption.text="一条无人照看的旧船，在浪间时隐时现。"
	_shot(Vector3(249,6,219),Vector3(244,4,216),Vector3(240,0,211),5.0)
	player.visual.rotation.y=-1.8
	_move(player,"global_position",Vector3(239,0,210),5.0)
	if not await _wait(5.0,id):return
	game.ui.fade.color.a=1.0
	player.global_basis=Basis(Vector3.UP,.4);player.visual.rotation=Vector3.ZERO;player.global_position=boat.global_position+Vector3(0,.78,.1);player._play_motion("PaddleIdle",1.0)
	game.weather.set_weather(1,1);game.weather.hour=18.2
	game.ui.cinematic_caption.text="她攀上废船。几天过去，食物和淡水都耗尽了。"
	_shot(Vector3(245,4,215),Vector3(243,3.4,214),boat.global_position+Vector3.UP*.8,6.0)
	_move(game.ui.fade,"color:a",0.0,.8)
	if not await _wait(3.0,id):return
	game.weather.hour=7.0
	game.ui.cinematic_caption.text="最后一点力气，也随着饥渴消失。小爱昏倒在船上。"
	_move(player.visual,"rotation:z",1.35,1.6)
	if not await _wait(3.0,id):return
	game.ui.fade.color.a=1.0
	boat.global_position=Vector3(166,-.28,153);player.global_position=boat.global_position+Vector3(0,.85,0)
	game.weather.set_weather(0,2);game.weather.hour=6.5
	game.ui.cinematic_caption.text="风停了。无人掌舵的小船，慢慢漂向一座岛。"
	_shot(Vector3(180,16,173),Vector3(166,10,158),Vector3(141,1,123),6.0)
	_move(game.ui.fade,"color:a",0.,.8)
	_move(boat,"global_position",Vector3(153,-.28,131),5.5)
	_move(player,"global_position",Vector3(153,.57,131),5.5)
	if not await _wait(6.0,id):return
	_move(game.ui.fade,"color:a",1.0,1.0)
	if not await _wait(1.0,id):return
	game.ui.cinematic_title.text="深 渊 岛"
	game.ui.cinematic_caption.text="名字听来深不可测，人生却可以从这里重新开始。"
	if not await _wait(3.0,id):return
	finish()

func finish() -> void:
	if not game.cinematic_active:return
	token+=1;playing=false
	for tween in tweens:if tween.is_valid():tween.kill()
	tweens.clear()
	if is_instance_valid(departure):departure.queue_free()
	if is_instance_valid(camera):camera.queue_free()
	var player:CharacterBody3D=game.player
	player.visual.rotation=Vector3.ZERO;player.visual.position=Vector3.ZERO;player.global_basis=Basis.IDENTITY;player.velocity=Vector3.ZERO
	player.rowing.global_transform=saved.boat;player.rowing.drive_speed=0;player.rowing.set_physics_process(true)
	if saved.replay:
		player.global_position=saved.position;game.weather.hour=saved.hour;game.day_count=saved.day;game.weather.set_weather(saved.weather,.5);player._set_swimming(saved.swimming)
	else:
		var point:=Vector2(130,114)
		player.global_position=Vector3(point.x,game.wildlife.ground.height(point.x,point.y)+.04,point.y)
		game.weather.hour=6.5;game.weather.set_weather(0,1);game.day_count=1;player._set_swimming(false)
	game.progress.intro_seen=true;game.cinematic_active=false
	player.set_physics_process(true);player._play_motion("Idle",1);player.camera.make_current();player.orbit.global_position=player.global_position+Vector3.UP
	game.ui.cinematic_panel.hide();game.ui.fade.color.a=0
	game.save();game.ui.notify("小爱醒来了。岸上的木屋里，似乎有人留下了东西。",6.0)
