"""Run on the last gripped C01_watering_preview.blend, before direction fix.
Preserve all 15 grip quaternions and anchor. Correct wrist pour direction for
the forward-facing can calibration; minimally flex forearm to avoid >80deg wrist.
"""
import bpy,json,math
from pathlib import Path
from mathutils import Vector,Matrix,Quaternion
p=Path(__file__).parent;s=bpy.context.scene;a=bpy.data.objects['GeneralSkeleton'];body=bpy.data.objects['C01_Body']
rest={b.name:b.matrix_local.to_quaternion() for b in a.data.bones}
calibration=Matrix(((1,0,0),(0,0,-1),(0,1,0)))
samples=[]
for f in range(1,170):
    s.frame_set(f);bpy.context.view_layer.update()
    samples.append({n:a.pose.bones[n].matrix.copy() for n in ['Hips','RightArm','RightForeArm','RightHand']})
records=[]
def smooth(v):
    v=min(1,max(0,v));return v*v*(3-2*v)
for f,source in enumerate(samples,1):
    s.frame_set(f);bpy.context.view_layer.update()
    t=(f-1)/30
    blend=smooth((t-.1)/.9)*smooth((5.5-t)/.9)
    delta=source['RightHand'].translation-source['Hips'].translation
    yaw=max(math.radians(-45),min(math.radians(45),math.atan2(delta.x*.65,max(.3,-delta.y))))
    horizontal=Vector((math.sin(yaw),-math.cos(yaw),0))
    pitch=math.radians(55)
    forward=horizontal*math.cos(pitch)-Vector((0,0,1))*math.sin(pitch)
    up=horizontal*math.sin(pitch)+Vector((0,0,1))*math.cos(pitch)
    axis_x=-forward
    axis_y=up.cross(axis_x).normalized()
    can_basis=Matrix((axis_x,axis_y,up)).transposed()
    desired=(can_basis @ calibration.transposed()).to_quaternion()
    hand_rotation=source['RightHand'].to_quaternion().slerp(desired,blend)
    fore_rotation=source['RightForeArm'].to_quaternion()
    fore_direction=fore_rotation @ Vector((0,1,0))
    hand_direction=hand_rotation @ Vector((0,1,0))
    angle=fore_direction.angle(hand_direction)
    correction=max(0,angle-math.radians(80))
    if correction>0:
        turn=Quaternion().slerp(fore_direction.rotation_difference(hand_direction),correction/angle)
        fore_rotation=turn @ fore_rotation
    fore=a.pose.bones['RightForeArm']
    parent=fore.parent.name
    local_rest=rest[parent].conjugated() @ rest[fore.name]
    fore.rotation_quaternion=(local_rest.conjugated() @ source['RightArm'].to_quaternion().conjugated() @ fore_rotation).normalized()
    fore.keyframe_insert('rotation_quaternion',frame=f)
    bpy.context.view_layer.update()
    hand=a.pose.bones['RightHand']
    local_rest=rest['RightForeArm'].conjugated() @ rest['RightHand']
    hand.rotation_quaternion=(local_rest.conjugated() @ fore_rotation.conjugated() @ hand_rotation).normalized()
    hand.keyframe_insert('rotation_quaternion',frame=f)
    bpy.context.view_layer.update()
    records.append({'frame':f,'blend':blend,'forearm_correction_deg':math.degrees(correction),'wrist_bend_deg':math.degrees(min(angle,math.radians(80))),'wrist_displacement_m':(hand.matrix.translation-source['RightHand'].translation).length})
for layer in a.animation_data.action.layers:
    for strip in layer.strips:
        for bag in strip.channelbags:
            for curve in bag.fcurves:
                for key in curve.keyframe_points:key.interpolation='LINEAR'
s.frame_set(1)
bpy.ops.object.select_all(action='DESELECT');a.select_set(True);body.select_set(True);bpy.context.view_layer.objects.active=a
bpy.ops.export_scene.gltf(filepath=str(p/'C01_watering_forward_source.glb'),export_format='GLB',use_selection=True,export_animations=True,export_animation_mode='ACTIVE_ACTIONS',export_force_sampling=True,export_frame_range=False)
bpy.ops.wm.save_as_mainfile(filepath=str(p/'C01_watering_forward_preview.blend'))
data=json.loads((p/'watering_grip_calibration.json').read_text())
data['calibration_godot_columns']=[[1,0,0],[0,-1,0],[0,0,-1]]
data['hand_local_calibration_quaternion_godot_xyzw']=[1,0,0,0]
data['pour_direction']='Character +Z / outward; can forward pitched down 55 degrees, nozzle down 10 degrees during 1.0-4.6s'
(p/'watering_grip_calibration.json').write_text(json.dumps(data,indent=2),encoding='utf8')
(p/'watering_direction_validation_blender.json').write_text(json.dumps(records,indent=2),encoding='utf8')
print('DIRECTION_FIXED max forearm degrees',max(x['forearm_correction_deg'] for x in records),'max wrist displacement',max(x['wrist_displacement_m'] for x in records))
