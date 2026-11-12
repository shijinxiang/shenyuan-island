import bpy,json
from pathlib import Path
proj=Path('D:/浪费GPT额度/小温的游戏')
target=bpy.data.objects['GeneralSkeleton'];rest={b.name:list(b.matrix_local.translation) for b in target.data.bones}
report={'target_world':str(target.matrix_world),'target_rest':{k:v for k,v in rest.items() if k in ['Root','Hips','Head','LeftHand','RightHand','LeftFoot','RightFoot']},'sources':{}}
for name in ['Entering Car','Driving']:
    previous=set(bpy.context.scene.objects)
    bpy.ops.import_scene.fbx(filepath=str(proj/'素材/07_动作源文件/Mixamo'/(name+'.fbx')))
    objs=set(bpy.context.scene.objects)-previous;arm=next(o for o in objs if o.type=='ARMATURE');action=arm.animation_data.action
    first,last=action.frame_range
    d={'frames':[first,last],'fps':bpy.context.scene.render.fps,'world':str(arm.matrix_world),'poses':{}}
    for f in [first,(first+last)/2,last]:
        bpy.context.scene.frame_set(int(f));bpy.context.view_layer.update()
        d['poses'][str(f)]={b.name.split(':')[-1]:list((arm.matrix_world@b.matrix).translation) for b in arm.pose.bones if b.name.split(':')[-1] in ['Hips','Head','LeftHand','RightHand','LeftFoot','RightFoot']}
    report['sources'][name]=d
    for o in objs:bpy.data.objects.remove(o,do_unlink=True)
out=Path(__file__).parent/'source_inspection.json';out.write_text(json.dumps(report,indent=2),encoding='utf-8');print(json.dumps(report))
