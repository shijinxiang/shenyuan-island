"""Run Blender with the original complete-action character blend, background mode.
Retarget the opening first strike of the supplied Mixamo Baseball Hit action.
Never saves over the input blend or locomotion GLB.
"""
import json
from pathlib import Path
import bpy
from mathutils import Matrix, Quaternion, Vector

project = Path('D:/浪费GPT额度/小温的游戏')
output = Path(__file__).parent
scene = bpy.context.scene
target = bpy.data.objects['GeneralSkeleton']
body = bpy.data.objects['C01_Body']
rest = {bone.name: bone.matrix_local.copy() for bone in target.data.bones}
rest_rotation = {name: matrix.to_quaternion() for name, matrix in rest.items()}
target.animation_data_clear()
for bone in target.pose.bones:
    bone.matrix_basis = Matrix.Identity(4)
existing = set(scene.objects)
bpy.ops.import_scene.fbx(filepath=str(project / '素材/07_动作源文件/Mixamo/Baseball Hit.fbx'))
imported = set(scene.objects) - existing
source = next(obj for obj in imported if obj.type == 'ARMATURE')
source_action = source.animation_data.action
first, full_last = (int(round(value)) for value in source_action.frame_range)
last = 36  # Opening strike including contact; omit recovery/reset.
fps = scene.render.fps / scene.render.fps_base
source_names = {bone.name.split(':')[-1]: bone.name for bone in source.data.bones}
assert not (set(rest) - {'Root'} - set(source_names))
source_rest = {name: source.matrix_world @ source.data.bones[full].matrix_local for name, full in source_names.items()}
source_rotation = {name: matrix.to_quaternion() for name, matrix in source_rest.items()}
segments = [('LeftUpLeg', 'LeftLeg'), ('LeftLeg', 'LeftFoot')]
scale = sum((rest[a].translation-rest[b].translation).length for a,b in segments) / sum((source_rest[a].translation-source_rest[b].translation).length for a,b in segments)
samples=[]
for frame in range(first,last+1):
    scene.frame_set(frame)
    bpy.context.view_layer.update()
    rotations = {name: (source.matrix_world @ source.pose.bones[full].matrix).to_quaternion() for name,full in source_names.items()}
    hips = (source.matrix_world @ source.pose.bones[source_names['Hips']].matrix).translation.copy()
    samples.append((rotations,hips))
movement=samples[-1][1]-samples[0][1]
poses=[]
for index,(rotations,hips) in enumerate(samples):
    desired={'Root':rest_rotation['Root']}
    for bone in target.data.bones:
        if bone.name!='Root':
            desired[bone.name]=rotations[bone.name] @ source_rotation[bone.name].conjugated() @ rest_rotation[bone.name]
    pose={'Root':(Quaternion(),Vector())}
    for bone in target.pose.bones:
        if bone.name=='Root': continue
        parent=bone.parent.name
        local_rest=rest_rotation[parent].conjugated() @ rest_rotation[bone.name]
        rotation=local_rest.conjugated() @ desired[parent].conjugated() @ desired[bone.name]
        rotation.normalize()
        location=Vector()
        if bone.name=='Hips':
            baseline=samples[0][1]+movement*index/max(len(samples)-1,1)
            displacement=Vector(((hips.x-baseline.x)*scale,(hips.y-baseline.y)*scale,(hips.z-samples[0][1].z)*scale))
            location=rest['Hips'].to_3x3().inverted() @ displacement
        pose[bone.name]=(rotation,location)
    poses.append(pose)

# Clear source actions before posing target and deriving contact with the floor.
for obj in imported: bpy.data.objects.remove(obj,do_unlink=True)
action=bpy.data.actions.new('Chop')
action.use_fake_user=True
target.animation_data_create()
target.animation_data.action=action
previous={}
floor_corrections=[]
hand_positions=[]
for index,pose in enumerate(poses):
    # Do not advance the scene: existing keys must not overwrite the fresh pose.
    for bone in target.pose.bones:
        rotation,location=pose[bone.name]
        if bone.name in previous and rotation.dot(previous[bone.name])<0: rotation.negate()
        previous[bone.name]=rotation.copy()
        bone.rotation_mode='QUATERNION'
        bone.rotation_quaternion=rotation
        bone.location=location
        bone.scale=(1,1,1)
    bpy.context.view_layer.update()
    evaluated=body.evaluated_get(bpy.context.evaluated_depsgraph_get())
    min_z=min((evaluated.matrix_world @ v.co).z for v in evaluated.data.vertices)
    # A grounded baseball swing always has a support foot. Match the actual
    # skinned sole to z=0; no swimming pelvis offset or synthetic loop blending.
    correction=-min_z
    target.pose.bones['Hips'].location += rest['Hips'].to_3x3().inverted() @ Vector((0,0,correction))
    floor_corrections.append(correction)
    bpy.context.view_layer.update()
    hand_positions.append(list(target.pose.bones['RightHand'].matrix.translation))
    for bone in target.pose.bones:
        bone.keyframe_insert('rotation_quaternion',frame=index+1)
        if bone.name=='Hips': bone.keyframe_insert('location',frame=index+1)
for layer in action.layers:
    for strip in layer.strips:
        for bag in strip.channelbags:
            for curve in bag.fcurves:
                for key in curve.keyframe_points: key.interpolation='LINEAR'
scene.render.fps=round(fps)
scene.frame_start=1
scene.frame_end=len(poses)
scene.frame_set(1)
bpy.context.view_layer.update()
bpy.ops.object.select_all(action='DESELECT')
target.select_set(True)
body.select_set(True)
bpy.context.view_layer.objects.active=target
bpy.ops.export_scene.gltf(filepath=str(output/'C01_chop_source.glb'),export_format='GLB',use_selection=True,export_animations=True,export_animation_mode='ACTIVE_ACTIONS',export_force_sampling=True,export_frame_range=False)
speeds=[(Vector(hand_positions[i])-Vector(hand_positions[i-1])).length*fps for i in range(1,len(poses))]
peak_index=max(range(len(speeds)),key=lambda i:speeds[i])+1
report={'source':'Baseball Hit.fbx','full_source_frames':[first,full_last],'used_source_frames':[first,last],'clip_frames':[1,len(poses)],'fps':fps,'duration_seconds':(len(poses)-1)/fps,'bones':len(target.pose.bones),'floor_correction_range': [min(floor_corrections),max(floor_corrections)],'max_hand_speed_seconds':peak_index/fps,'max_hand_speed_source_frame':first+peak_index,'hand_positions':hand_positions}
(output/'chop_metadata.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
print('CHOP_RETARGETED',json.dumps({k:v for k,v in report.items() if k!='hand_positions'},ensure_ascii=False))

# Save a separate review scene, never the source character file.
bpy.ops.wm.save_as_mainfile(filepath=str(output/'C01_挥砍预览.blend'))
