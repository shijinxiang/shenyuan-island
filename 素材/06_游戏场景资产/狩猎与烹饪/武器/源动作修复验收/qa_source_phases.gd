extends SceneTree
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
 print("SOURCE_LENGTH ",clip.length)
 for at in [0.,.5,1.,1.5,2.,2.15,2.5,2.8,3.,3.25,3.5,4.,4.5]:
  ap.seek(at,true)
  for i in 3:await process_frame
  var pts={}
  for n in ["Hips","Spine","Head","LeftArm","LeftHand","RightHand"]:pts[n]=sk.get_bone_global_pose(sk.find_bone(n)).origin
  print("SOURCE ",at," ",pts)
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("D:/Temp/bow_source_fix/source_%03d.png"%int(at*100))
 quit()
