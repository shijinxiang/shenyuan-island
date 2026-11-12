extends SceneTree
const P="D:/浪费GPT额度/小温的游戏/"
const S=P+"素材/06_游戏场景资产/狩猎与烹饪/武器/"
func scene(path:String)->Node:
 var d=GLTFDocument.new();var s=GLTFState.new();assert(d.append_from_file(path,s)==OK);return d.generate_scene(s)
func _initialize():
 var target=scene(P+"游戏/assets/characters/C01_locomotion.glb");root.add_child(target)
 var ap:AnimationPlayer=target.find_children("*","AnimationPlayer",true,false)[0]
 var sk:Skeleton3D=target.find_children("*","Skeleton3D",true,false)[0]
 var path=ap.get_node(ap.root_node).get_path_to(sk)
 for spec in [["gunplay","Gunplay",0.0,77.0/30,false],["gunplay","GunAim",42.0/30,45.0/30,true],["gunplay","GunFire",44.0/30,54.0/30,false],["gunplay","GunReload",0.0,42.0/30,false],["bow","Bow",0.0,5.0,false]]:
  var src=scene(S+spec[0]+".glb");var sap:AnimationPlayer=src.find_children("*","AnimationPlayer",true,false)[0]
  var original=sap.get_animation(sap.get_animation_list()[0]);var clip=Animation.new();clip.length=spec[3]-spec[2];clip.resource_name=spec[1];clip.loop_mode=Animation.LOOP_LINEAR if spec[4] else Animation.LOOP_NONE
  for t in original.get_track_count():
   var bone=original.track_get_path(t).get_subname(0);assert(sk.find_bone(bone)>=0)
   var typ=original.track_get_type(t);var n=clip.add_track(typ);clip.track_set_path(n,NodePath(str(path)+":"+bone))
   for k in range(int(ceil(clip.length*30))+1):
    var time=minf(k/30.0,clip.length);var at=spec[2]+time
    if typ==Animation.TYPE_ROTATION_3D:clip.rotation_track_insert_key(n,time,original.rotation_track_interpolate(t,at))
    elif typ==Animation.TYPE_POSITION_3D:clip.position_track_insert_key(n,time,original.position_track_interpolate(t,at))
    elif typ==Animation.TYPE_SCALE_3D:clip.scale_track_insert_key(n,time,original.scale_track_interpolate(t,at))
  var slug={"Gunplay":"gunplay","GunAim":"gun_aim","GunFire":"gun_fire","GunReload":"gun_reload","Bow":"bow"}[spec[1]]
  assert(ResourceSaver.save(clip,P+"游戏/assets/characters/C01_"+slug+".res")==OK)
  print(spec[1]," duration=",clip.length," tracks=",clip.get_track_count()," path=",path)
  src.free()
 quit()
