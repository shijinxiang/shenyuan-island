"""Blender --background original.blend --python retarget_farming.py -- Harvest|Watering [Left|Right].
An optional side replaces the non-working arm with the character's Idle arm.
Outputs independent animation sources and review blends, never overwrites input.
"""
import json
import sys
import math
from pathlib import Path
import bpy
from mathutils import Matrix, Quaternion, Vector

args=sys.argv[sys.argv.index('--')+1:]
clip=args[0]
relax_side=args[1] if len(args)>1 else None
source_name={'Harvest':'Pick Fruit','Watering':'Watering'}[clip]
slug=clip.lower()
project=Path('D:/浪费GPT额度/小温的游戏')
output=Path(__file__).parent
scene=bpy.context.scene
target=bpy.data.objects['GeneralSkeleton']
body=bpy.data.objects['C01_Body']
rest={b.name:b.matrix_local.copy() for b in target.data.bones}
rest_rotation={n:m.to_quaternion() for n,m in rest.items()}

# Capture actual authored Idle local transforms, including fingers. The arm
# stays naturally down while its parent chest continues the picking motion.
target.animation_data_create()
target.animation_data.action=bpy.data.actions['Idle']
scene.frame_set(1)
bpy.context.view_layer.update()
idle={b.name:(b.matrix_basis.to_quaternion().copy(),b.location.copy()) for b in target.pose.bones}
idle_world_rotation={b.name:b.matrix.to_quaternion().copy() for b in target.pose.bones}
relaxed_bones={n for n in rest if relax_side and (n.startswith(relax_side+'Shoulder') or n.startswith(relax_side+'Arm') or n.startswith(relax_side+'ForeArm') or n.startswith(relax_side+'Hand'))}
target.animation_data_clear()
for b in target.pose.bones: b.matrix_basis=Matrix.Identity(4)
existing=set(scene.objects)
bpy.ops.import_scene.fbx(filepath=str(project/'素材/07_动作源文件/Mixamo'/f'{source_name}.fbx'))
imported=set(scene.objects)-existing
source=next(o for o in imported if o.type=='ARMATURE')
first,last=(int(round(v)) for v in source.animation_data.action.frame_range)
fps=scene.render.fps/scene.render.fps_base
source_names={b.name.split(':')[-1]:b.name for b in source.data.bones}
assert not (set(rest)-{'Root'}-set(source_names))
source_rest={n:source.matrix_world @ source.data.bones[full].matrix_local for n,full in source_names.items()}
source_rotation={n:m.to_quaternion() for n,m in source_rest.items()}
segments=[('LeftUpLeg','LeftLeg'),('LeftLeg','LeftFoot')]
scale=sum((rest[a].translation-rest[b].translation).length for a,b in segments)/sum((source_rest[a].translation-source_rest[b].translation).length for a,b in segments)
samples=[]
for frame in range(first,last+1):
    scene.frame_set(frame)
    bpy.context.view_layer.update()
    rotations={n:(source.matrix_world @ source.pose.bones[full].matrix).to_quaternion() for n,full in source_names.items()}
    hips=(source.matrix_world @ source.pose.bones[source_names['Hips']].matrix).translation.copy()
    samples.append((rotations,hips))
movement=samples[-1][1]-samples[0][1]
poses=[]
for index,(rotations,hips) in enumerate(samples):
    desired={'Root':rest_rotation['Root']}
    desired.update({n:rotations[n] @ source_rotation[n].conjugated() @ rest_rotation[n] for n in rest if n!='Root'})
    # Keep the non-picking arm directed down under gravity when the chest bends.
    # World-space Idle rotations prevent the relaxed arm from following the
    # crouching torso backwards; local rotations are solved against that torso.
    crouch_blend=min(1.0,max(0.0,(samples[0][1].z-hips.z)*scale/0.25))
    knee_clearance=Quaternion((1,0,0),math.radians(-25.0)*crouch_blend)
    desired.update({n:(idle_world_rotation[n] if n.endswith('Shoulder') else knee_clearance @ idle_world_rotation[n]) for n in relaxed_bones})
    pose={'Root':(Quaternion(),Vector())}
    for bone in target.pose.bones:
        n=bone.name
        if n=='Root':continue
        parent=bone.parent.name
        local_rest=rest_rotation[parent].conjugated() @ rest_rotation[n]
        rotation=local_rest.conjugated() @ desired[parent].conjugated() @ desired[n]
        rotation.normalize()
        location=Vector()
        if n=='Hips':
            baseline=samples[0][1]+movement*index/max(len(samples)-1,1)
            displacement=Vector(((hips.x-baseline.x)*scale,(hips.y-baseline.y)*scale,(hips.z-samples[0][1].z)*scale))
            location=rest['Hips'].to_3x3().inverted() @ displacement
        pose[n]=(rotation,location)
    poses.append(pose)
for o in imported:bpy.data.objects.remove(o,do_unlink=True)
action=bpy.data.actions.new(clip)
action.use_fake_user=True
target.animation_data_create()
target.animation_data.action=action
previous={}
floor_corrections=[]
hand_positions={side:[] for side in ['Left','Right']}
for index,pose in enumerate(poses):
    for b in target.pose.bones:
        rotation,location=pose[b.name]
        rotation=rotation.copy()
        if b.name in previous and rotation.dot(previous[b.name])<0:rotation.negate()
        previous[b.name]=rotation.copy()
        b.rotation_mode='QUATERNION'
        b.rotation_quaternion=rotation
        b.location=location
        b.scale=(1,1,1)
    bpy.context.view_layer.update()
    evaluated=body.evaluated_get(bpy.context.evaluated_depsgraph_get())
    min_z=min((evaluated.matrix_world @ v.co).z for v in evaluated.data.vertices)
    correction=-min_z
    target.pose.bones['Hips'].location+=rest['Hips'].to_3x3().inverted() @ Vector((0,0,correction))
    floor_corrections.append(correction)
    bpy.context.view_layer.update()
    for side in hand_positions:hand_positions[side].append(list(target.pose.bones[side+'Hand'].matrix.translation))
    for b in target.pose.bones:
        b.keyframe_insert('rotation_quaternion',frame=index+1)
        if b.name=='Hips':b.keyframe_insert('location',frame=index+1)
for layer in action.layers:
    for strip in layer.strips:
        for bag in strip.channelbags:
            for curve in bag.fcurves:
                for key in curve.keyframe_points:key.interpolation='LINEAR'
scene.render.fps=round(fps)
scene.frame_start=1
scene.frame_end=len(poses)
scene.frame_set(1)
bpy.context.view_layer.update()
bpy.ops.object.select_all(action='DESELECT')
target.select_set(True)
body.select_set(True)
bpy.context.view_layer.objects.active=target
bpy.ops.export_scene.gltf(filepath=str(output/f'C01_{slug}_source.glb'),export_format='GLB',use_selection=True,export_animations=True,export_animation_mode='ACTIVE_ACTIONS',export_force_sampling=True,export_frame_range=False)
report={'source':source_name+'.fbx','clip':clip,'source_frames':[first,last],'fps':fps,'duration_seconds':(len(poses)-1)/fps,'bones':len(target.pose.bones),'relaxed_side':relax_side,'relaxed_bones':sorted(relaxed_bones),'floor_correction_range':[min(floor_corrections),max(floor_corrections)],'hand_positions':hand_positions}
report['working_hand_bone']='RightHand'
if clip=='Harvest':
    report['recommended_contact_source_frames']=[55,90,134]
    report['recommended_contact_seconds']=[54/30,89/30,133/30]
    report['relaxed_arm_mode']='World-space Idle downward orientation with chest compensation and up to 25-degree forward knee clearance when crouched'
else:
    report['recommended_watering_window_seconds']=[1.0,4.6]
report['event_note']='Visual/kinematic synchronization recommendations; source FBX does not contain gameplay events.'
(output/f'{slug}_metadata.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
print('FARM_RETARGETED',json.dumps({k:v for k,v in report.items() if k!='hand_positions'},ensure_ascii=False))
bpy.ops.wm.save_as_mainfile(filepath=str(output/f'C01_{slug}_preview.blend'))
