extends SceneTree
class PlayerMock extends Node3D:
 var velocity=Vector3.ZERO
class GameMock extends Node3D:
 var player:Node3D
class HuntingMock extends Node3D:
 var game:Node3D
 var equipped="bow"
 var aiming=true
 var reloading=false
 var shot_cooldown=0.0
 var reload_duration=1.0
 var draw_amount=1.0
 var aim_direction=Vector3.BACK
 var models={}
 func can_use():return true
func _initialize():
 run.call_deferred()
func run():
 var world=Node3D.new();root.add_child(world)
 var env=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color(.12,.16,.20);env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color.WHITE;env.environment.ambient_light_energy=.8;world.add_child(env)
 var light=DirectionalLight3D.new();world.add_child(light);light.rotation_degrees=Vector3(-40,-25,0);light.light_energy=1.4
 var character=load("res://assets/characters/C01_locomotion.glb").instantiate();world.add_child(character)
 var sk:Skeleton3D=character.find_children("*","Skeleton3D",true,false)[0]
 var ap:AnimationPlayer=character.find_children("*","AnimationPlayer",true,false)[0]
 var lib=AnimationLibrary.new();var clip=load("res://assets/characters/C01_bow.res");lib.add_animation("Bow",clip);ap.add_animation_library("src",lib);ap.play("src/Bow");ap.pause()
 var cam=Camera3D.new();world.add_child(cam);cam.position=Vector3(2.3,1.6,2.6);cam.look_at(Vector3(0,1.0,0));cam.fov=42
 root.size=Vector2i(900,900)

 var h=HuntingMock.new();world.add_child(h)
 h.game=GameMock.new();world.add_child(h.game);h.game.player=PlayerMock.new();world.add_child(h.game.player)
 var model=load("res://assets/hunting/bow.glb").instantiate();world.add_child(model);h.models.bow=model
 var mod=load("res://scripts/player/weapon_grip.gd").new();mod.hunting=h;sk.add_child(mod)
 print(ap.get_animation_list())
 sk.skeleton_updated.connect(func(): check_hat(sk,mod,h))
 var specs=[]
 for pitch in [-1.0,0.0,1.0]:
  specs.append(["grid",1.0,pitch,Vector3(2.3,1.8,2.6),false])
  for i in 41:specs.append(["grid",float(i)/40.0,pitch,Vector3(2.3,1.8,2.6),false])
 for spec in specs:
  h.draw_amount=spec[1];h.aim_direction=Vector3(0,sin(spec[2]),cos(spec[2]));cam.position=spec[3];cam.look_at(Vector3(0,1.0,.15))
  if spec[4]:
   h.game.player.velocity=Vector3(0,0,2)
   for anim in ap.get_animation_list():
    if "walk" in anim.to_lower():
     ap.play(anim);ap.seek(.25,true);ap.pause();break
  for i in 4:await process_frame
  await RenderingServer.frame_post_draw
  pass
 h.equipped="";model.visible=false
 for i in 4:await process_frame
 assert(mod._body_mesh.mesh == mod._original_mesh)
 assert(mod._body_mesh.skin == mod._original_skin)
 print("HAT_RESTORE_PASS")
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("D:/Temp/bow_source_fix/fixed_hat_restored.png")
 quit()


var last_key=""
func check_hat(sk, mod, h):
 if h.equipped != "bow" or mod._body_mesh == null:return
 var key=str(h.draw_amount)+str(h.aim_direction)
 if key==last_key:return
 last_key=key
 var mesh=mod._body_mesh.mesh
 var skin=mod._body_mesh.skin
 var arr=mesh.surface_get_arrays(0)
 var vertices=arr[Mesh.ARRAY_VERTEX];var bones=arr[Mesh.ARRAY_BONES];var weights=arr[Mesh.ARRAY_WEIGHTS];var indices=arr[Mesh.ARRAY_INDEX]
 var transforms=[]
 for i in skin.get_bind_count():
  var bi=sk.find_bone(skin.get_bind_name(i))
  if bi<0:bi=skin.get_bind_bone(i)
  transforms.append(sk.global_transform*sk.get_bone_global_pose(bi)*skin.get_bind_pose(i))
 var points={}
 var influences=bones.size()/vertices.size()
 for i in vertices.size():
  var v=vertices[i]
  if v.y<1.48:continue
  var pp=Vector3.ZERO
  for j in int(influences):
   var wi=i*int(influences)+j
   if weights[wi]>.00001:pp+=(transforms[bones[wi]]*v)*weights[wi]
  points[i]=pp
 var a=mod.model_transform*Vector3(0,.64,-.08)
 var b=mod.model_transform*mod.string_center
 var hits=[]
 for i in range(0,indices.size(),3):
  var aa=indices[i];var bb=indices[i+1];var cc=indices[i+2]
  if points.has(aa) and points.has(bb) and points.has(cc):
   var hit=Geometry3D.segment_intersects_triangle(a,b,points[aa],points[bb],points[cc])
   if hit!=null:hits.append(hit)
 print("UPPER_STRING_HEAD_INTERSECTIONS ",key," ",hits)
