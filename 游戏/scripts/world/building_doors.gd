extends Node

var closed_transforms:Dictionary={}
var open_transforms:Dictionary={}
var door_nodes:Dictionary={}
var open_states:Dictionary={}
var animations:Dictionary={}

func _ready() -> void:
	var building:=get_parent()
	for name in ["Door_Hinged_105deg","Door_Cargo_Left","Door_Cargo_Right","Door_Service"]:
		var door:=building.find_child(name,true,false) as Node3D
		if door==null:continue
		var closed:=door.transform
		var opened:=door.transform
		if name=="Door_Hinged_105deg":
			closed.basis=Basis.IDENTITY.scaled(door.scale)
			opened=closed
			opened.basis=closed.basis.rotated(Vector3.UP,deg_to_rad(-105.))
		elif name=="Door_Service":
			opened.basis=closed.basis.rotated(Vector3.UP,deg_to_rad(-100.))
		else:
			opened.origin.x+=-3.5 if name=="Door_Cargo_Left" else 3.5
		door_nodes[name]=door
		closed_transforms[name]=closed
		open_transforms[name]=opened
	open_states={"main":door_nodes.has("Door_Hinged_105deg"),"cargo":false,"service":false}

func set_open(group:String,opened:bool,instant:bool=false) -> void:
	var names:Array=[]
	match group:
		"main":names=["Door_Hinged_105deg"]
		"cargo":names=["Door_Cargo_Left","Door_Cargo_Right"]
		"service":names=["Door_Service"]
	var animation:Tween=animations.get(group)
	if animation and animation.is_valid():animation.kill()
	if not instant:
		animation=create_tween().set_parallel(true).set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
		animations[group]=animation
		animation.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	for name in names:
		if not door_nodes.has(name):continue
		var target:Transform3D=open_transforms[name] if opened else closed_transforms[name]
		if instant:door_nodes[name].transform=target
		else:animation.tween_property(door_nodes[name],"transform",target,.85)
	open_states[group]=opened

func toggle(group:String="main") -> void:
	set_open(group,not open_states.get(group,false))
