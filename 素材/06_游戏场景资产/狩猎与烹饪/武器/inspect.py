import bpy,json
from pathlib import Path
P=Path('D:/浪费GPT额度/小温的游戏'); O=Path(__file__).parent
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(P/'游戏/assets/characters/C01_locomotion.glb'))
a=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE')
print('TARGET',a.name, len(a.data.bones), a.matrix_world)
bpy.ops.wm.save_as_mainfile(filepath=str(O/'C01_weapon_base.blend'))
r={}
for name in ['Gunplay','弓箭']:
 before=set(bpy.context.scene.objects);bpy.ops.import_scene.fbx(filepath=str(P/'素材/07_动作源文件/Mixamo'/(name+'.fbx')))
 imp=set(bpy.context.scene.objects)-before;arm=next(o for o in imp if o.type=='ARMATURE');act=arm.animation_data.action
 r[name]={'frames':list(act.frame_range),'fps':bpy.context.scene.render.fps,'bones':len(arm.data.bones),'points':{}}
 for f in range(int(act.frame_range.x),int(act.frame_range.y)+1,15):
  bpy.context.scene.frame_set(f);bpy.context.view_layer.update()
  r[name]['points'][f]={b.name.split(':')[-1]:list((arm.matrix_world@b.matrix).translation) for b in arm.pose.bones if b.name.split(':')[-1] in ['Head','LeftHand','RightHand','Hips']}
 for o in imp:bpy.data.objects.remove(o,do_unlink=True)
(O/'source_inspection.json').write_text(json.dumps(r,ensure_ascii=False,indent=2),encoding='utf8');print(json.dumps(r,ensure_ascii=False))
