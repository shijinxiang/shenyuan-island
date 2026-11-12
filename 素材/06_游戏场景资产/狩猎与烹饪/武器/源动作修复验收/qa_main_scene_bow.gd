extends SceneTree
var world:Node3D
var game:Node3D
var player:CharacterBody3D
var output="D:/浪费GPT额度/小温的游戏/素材/06_游戏场景资产/狩猎与烹饪/武器/源动作修复验收/"
func _initialize():
 ProjectSettings.set_setting("application/config/use_custom_user_dir",true)
 ProjectSettings.set_setting("application/config/custom_user_dir_name","CodexAbyssBowNormalSceneReview20261110")
 DirAccess.make_dir_recursive_absolute(OS.get_user_data_dir())
 var f=FileAccess.open("user://fishing_catches.json",FileAccess.WRITE)
 f.store_string(JSON.stringify({"version":3,"items":[],"progress":{"intro_seen":true,"rod_found":true,"merchant_intro":true,"goods":[{"id":"bow","name":"木弓","count":1},{"id":"wooden_arrow","name":"木箭","count":20}]}}));f.close()
 run.call_deferred()
func tick(n=3):
 for i in n:await physics_frame;await process_frame
 await RenderingServer.frame_post_draw
func run():
 world=load("res://scenes/coastal_beauty.scn").instantiate();root.add_child(world);current_scene=world
 game=world.get_node("IslandAdventure");player=game.player
 while not world.get_node("ShallowWaterSimulation").ready_for_render:await tick(1)
 await tick(20)
 game.set_process(false);game.crocodiles.set_physics_process(false);game.wildlife.set_process(false);game.weather.set_process(false);player.set_physics_process(false)
 var center:Vector3=game.survival.cabin.to_global(Vector3(0,0,9));center.y=game.wildlife.ground.height(center.x,center.z)
 player.global_position=center+Vector3.UP*.02;player.swimming=false;player.velocity=Vector3.ZERO;player.visual.global_rotation.y=0
 game.hunting.equip("bow");game.hunting.set_process(false);game.hunting.aiming=true;game.hunting.draw_amount=1.;game.hunting.models.bow.show();game.ui.toast_time=0;game.ui.toast.hide()
 var sk:Skeleton3D=game.fishing.skeleton
 var ref=load("res://assets/characters/C01_locomotion.glb").instantiate();var refsk:Skeleton3D=ref.find_children("*","Skeleton3D",true,false)[0]
 var differences=[]
 for i in sk.get_bone_count():
  var j=refsk.find_bone(sk.get_bone_name(i))
  if j<0 or not sk.get_bone_rest(i).is_equal_approx(refsk.get_bone_rest(j)):differences.append(sk.get_bone_name(i))
 print("MAIN_SCENE_REST_DIFFERENCES ",differences," skeleton_global ",sk.global_transform)
 ref.free()
 var cam=Camera3D.new();world.add_child(cam);cam.fov=44;cam.make_current();root.size=Vector2i(1200,1000)
 for spec in [["level_front",0.,Vector3(2.3,1.8,2.6)],["level_rear",0.,Vector3(-2.3,1.7,-2.6)],["level_side",0.,Vector3(3.0,1.6,0.)],["up40",40.,Vector3(2.3,1.8,2.6)],["down40",-40.,Vector3(2.3,1.8,2.6)]]:
  var forward:Vector3=player.visual.global_basis.z.normalized();var right=Vector3.UP.cross(forward).normalized()
  game.hunting.aim_direction=forward.rotated(right,-deg_to_rad(spec[1]));game.hunting.draw_amount=1.0
  cam.global_position=player.global_position+spec[2];cam.look_at(player.global_position+Vector3(0,1.0,.15))
  await tick(8)
  print("MAIN_SCENE_AIM ",spec[0]," ",game.hunting.aim_direction," can_use=",game.hunting.can_use()," model=",game.hunting.models.bow.global_transform)
  root.get_texture().get_image().save_png(output+"main_scene_"+spec[0]+".png")
 print("MAIN_SCENE_RENDER_PASS")
 current_scene=null;world.queue_free();await process_frame;quit()

