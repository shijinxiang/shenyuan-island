"""Retarget Mixamo vehicle clips onto the existing C01 rig without X/Z drift."""
import bpy, json, math
from pathlib import Path
from mathutils import Matrix, Quaternion, Vector
SRC=Path(__file__).resolve().parent;PROJECT=SRC.parents[3]
scene=bpy.context.scene;target=bpy.data.objects['GeneralSkeleton'];body=next(o for o in scene.objects if o.type=='MESH')
rest={b.name:b.matrix_local.copy() for b in target.data.bones};rr={n:m.to_quaternion() for n,m in rest.items()}
target.animation_data_clear()
report={}
for clip in ['Gunplay','弓箭']:
    for b in target.pose.bones:b.matrix_basis=Matrix.Identity(4)
    before=set(scene.objects);bpy.ops.import_scene.fbx(filepath=str(PROJECT/'素材/07_动作源文件/Mixamo'/(clip+'.fbx')))
    imported=set(scene.objects)-before;source=next(o for o in imported if o.type=='ARMATURE');sa=source.animation_data.action
    first,last=(int(round(x)) for x in sa.frame_range);fps=scene.render.fps/scene.render.fps_base
    names={b.name.split(':')[-1]:b.name for b in source.data.bones};sr={n:source.matrix_world@source.data.bones[f].matrix_local for n,f in names.items()};sq={n:m.to_quaternion() for n,m in sr.items()}
    missing=set(rest)-{'Root'}-set(names);assert not missing,missing
    seg=[('LeftUpLeg','LeftLeg'),('LeftLeg','LeftFoot')];scale=sum((rest[a].translation-rest[b].translation).length for a,b in seg)/sum((sr[a].translation-sr[b].translation).length for a,b in seg)
    samples=[]
    for f in range(first,last+1):
        scene.frame_set(f);bpy.context.view_layer.update()
        rot={n:(source.matrix_world@source.pose.bones[full].matrix).to_quaternion() for n,full in names.items()}
        hips=(source.matrix_world@source.pose.bones[names['Hips']].matrix).translation.copy();samples.append((rot,hips))
    facing=(samples[-1][0]['Hips']@sq['Hips'].conjugated())@Vector((0,-1,0));yaw=-math.atan2(facing.x,-facing.y)
    yaw=0.0;align=Quaternion((0,0,1),yaw)
    end_height=samples[-1][1].z
    action=bpy.data.actions.new(clip);action.use_fake_user=True;target.animation_data_create();target.animation_data.action=action;prev={}
    for index,(rot,hips) in enumerate(samples):
        desired={'Root':rr['Root']}
        for b in target.data.bones:
            if b.name!='Root':desired[b.name]=align@rot[b.name]@sq[b.name].conjugated()@rr[b.name]
        for b in target.pose.bones:
            q=Quaternion();loc=Vector()
            if b.name!='Root':
                parent=b.parent.name;lr=rr[parent].conjugated()@rr[b.name];q=lr.conjugated()@desired[parent].conjugated()@desired[b.name];q.normalize()
                if b.name=='Hips':
                    height=rest['Hips'].translation.z+(hips.z-end_height)*scale
                    displacement=Vector((-rest['Hips'].translation.x,-rest['Hips'].translation.y,height-rest['Hips'].translation.z))
                    loc=rest['Hips'].to_3x3().inverted()@displacement
            if b.name in prev and q.dot(prev[b.name])<0:q.negate()
            prev[b.name]=q.copy();b.rotation_mode='QUATERNION';b.rotation_quaternion=q;b.location=loc;b.scale=(1,1,1)
            b.keyframe_insert('rotation_quaternion',frame=index+1)
            if b.name in ['Hips','Root']:b.keyframe_insert('location',frame=index+1)
    for layer in action.layers:
        for strip in layer.strips:
            for bag in strip.channelbags:
                for fc in bag.fcurves:
                    for key in fc.keyframe_points:key.interpolation='LINEAR'
    for o in imported:bpy.data.objects.remove(o,do_unlink=True)
    scene.render.fps=round(fps);scene.frame_start=1;scene.frame_end=len(samples);scene.frame_set(1);bpy.context.view_layer.update()
    slug='gunplay' if clip=='Gunplay' else 'bow'
    bpy.ops.object.select_all(action='DESELECT');target.select_set(True);body.select_set(True);bpy.context.view_layer.objects.active=target
    bpy.ops.export_scene.gltf(filepath=str(SRC/(slug+'.glb')),export_format='GLB',use_selection=True,export_animations=True,export_animation_mode='ACTIVE_ACTIONS',export_force_sampling=True,export_frame_range=False,export_anim_slide_to_zero=True)
    info={'source':clip+'.fbx','frames':len(samples),'duration':(len(samples)-1)/fps,'fps':fps,'retarget_scale':scale,'yaw_alignment_deg':math.degrees(yaw),'hips_seated_y':.78,'root_translation':[0,0,0],'global_hips_xz':[0,0],'landmarks_godot':{}}
    for f in [1,len(samples)//2,len(samples)]:
        scene.frame_set(f);bpy.context.view_layer.update()
        points={}
        for name in ['Hips','Head','LeftHand','RightHand','LeftFoot','RightFoot']:
            p=(target.matrix_world@target.pose.bones[name].matrix).translation;points[name]=[p.x,p.z,-p.y]
        info['landmarks_godot'][str(f)]=points
    report[clip]=info
target.animation_data.action=bpy.data.actions['弓箭'];scene.frame_set(1)
bpy.ops.wm.save_as_mainfile(filepath=str(SRC/'C01_狩猎动作_重定向.blend'))
(SRC/'retarget_report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
print('VEHICLE_RETARGET_COMPLETE '+json.dumps(report,ensure_ascii=False))

