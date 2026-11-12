extends SceneTree
class HuntingMock extends Node3D:
 var game: Node3D
 var equipped="hunting_rifle"
 var aiming=true
 var reloading=false
 var draw_amount=1.0
 var aim_direction=Vector3(0,0,1)
 var models={}
 func can_use():return true
var h:HuntingMock
var cam:Camera3D
var count=0
func _initialize():
 _go.call_deferred()
func _go():
 var world=Node3D.new();root.add_child(world)
 var env=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color(.16,.19,.22);env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color.WHITE;env.environment.ambient_light_energy=.8;world.add_child(env)
 var light=DirectionalLight3D.new();world.add_child(light);light.rotation_degrees=Vector3(-40,-25,0);light.light_energy=2.0
 var character=load("res://assets/characters/C01_locomotion.glb").instantiate();world.add_child(character)
 var sk:Skeleton3D=character.find_children("*","Skeleton3D",true,false)[0]
 var ap:AnimationPlayer=character.find_children("*","AnimationPlayer",true,false)[0]
 print(ap.get_animation_list())
 var lib=AnimationLibrary.new();lib.add_animation("GunAim",load("res://assets/characters/C01_gun_aim.res"));ap.add_animation_library("h",lib);ap.play("h/GunAim")
 h=HuntingMock.new();world.add_child(h)
 for id in ["hunting_rifle","bow"]:
  var model=load("res://assets/hunting/"+id+".glb").instantiate();world.add_child(model);h.models[id]=model;model.visible=id==h.equipped
 var mod=load("res://scripts/player/weapon_grip.gd").new();mod.hunting=h;sk.add_child(mod)
 cam=Camera3D.new();world.add_child(cam);cam.position=Vector3(2.2,1.7,2.3);cam.look_at(Vector3(0,1.25,.3));cam.fov=38
 root.size=Vector2i(1100,900)
 await process_frame;await process_frame;await process_frame
 for spec in [["hunting_rifle",false,1.0,"gun_aim"],["hunting_rifle",true,1.0,"gun_reload"],["bow",false,1.0,"bow_draw"],["bow",false,0.0,"bow_release"]]:
  var id=spec[0]
  h.reloading=spec[1];h.draw_amount=spec[2]
  h.equipped=id
  for key in h.models:h.models[key].visible=key==id
  for i in 8:await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("D:/Temp/weapon_"+spec[3]+".png")
 quit()
