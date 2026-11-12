extends RefCounted

var player:CharacterBody3D
var skeleton:Skeleton3D
var legs:AnimationPlayer
var hips_index:int
var spine_index:int

func _init(actor:CharacterBody3D) -> void:
	player=actor
	skeleton=player.visual.find_children("*","Skeleton3D",true,false)[0]
	hips_index=skeleton.find_bone("Hips")
	spine_index=skeleton.find_bone("Spine")
	legs=AnimationPlayer.new()
	legs.name="FishingLegs"
	legs.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	player.visual.add_child(legs)
	legs.root_node=legs.get_path_to(player.visual)
	var library:=AnimationLibrary.new()
	for clip_name in ["Walk","Run"]:
		var clip:Animation=player.animation.get_animation(clip_name).duplicate()
		for track in range(clip.get_track_count()-1,-1,-1):
			var path:=clip.track_get_path(track)
			var bone:=String(path.get_subname(0)) if path.get_subname_count()>0 else ""
			if bone!="Hips" and not ("Leg" in bone or "Foot" in bone or "Toe" in bone):clip.remove_track(track)
		clip.loop_mode=Animation.LOOP_LINEAR
		library.add_animation(clip_name,clip)
	legs.add_animation_library("",library)

func update(delta:float) -> void:
	player.animation.advance(0.0)
	var velocity:Vector3=player.fishing_move_velocity
	velocity.y=0.0
	var speed:=velocity.length()
	if speed<.06:
		legs.stop(true)
		return
	var torso_basis:=skeleton.get_bone_global_pose(spine_index).basis
	var angle:=wrapf(atan2(velocity.x,velocity.z)-player.visual.global_rotation.y,-PI,PI)
	var backwards:=absf(angle)>PI*.65
	if backwards:angle=wrapf(angle-PI,-PI,PI)
	var clip_name:="Run" if speed>player.walk_speed*1.25 else "Walk"
	var native_speed:float=player.native_run_speed if clip_name=="Run" else player.native_walk_speed
	if legs.current_animation!=clip_name or not legs.is_playing():legs.play(clip_name,.12)
	legs.speed_scale=clampf(speed/native_speed,.2,1.6)*(-1.0 if backwards else 1.0)
	legs.advance(delta)
	var hips:=skeleton.get_bone_global_pose(hips_index)
	var up:=skeleton.global_basis.inverse()*Vector3.UP
	hips.basis=Basis(up.normalized(),clampf(angle,-1.0,1.0))*hips.basis
	skeleton.set_bone_global_pose(hips_index,hips)
	var spine:=skeleton.get_bone_global_pose(spine_index)
	spine.basis=torso_basis
	skeleton.set_bone_global_pose(spine_index,spine)

func stop() -> void:
	legs.stop(true)
