extends Node
var cabin:Node3D
var player:Node3D
var roof:Node3D

func _ready() -> void:
	cabin=get_parent()
	player=cabin.get_parent().get_parent().get_node_or_null("Player")
	roof=cabin.find_child("B01_Roof_HideForInterior",true,false)
	var controls:=cabin.get_node_or_null("DoorControls")
	if controls:controls.set_open("main",true,true)

func _process(_delta:float) -> void:
	if player==null or roof==null:return
	var point:=cabin.to_local(player.global_position)
	var inside:=absf(point.x)<3.35 and point.z>-2.85 and point.z<2.78 and point.y>.35 and point.y<3.3
	roof.visible=not inside
