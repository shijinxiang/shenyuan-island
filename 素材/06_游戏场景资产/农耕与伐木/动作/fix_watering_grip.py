"""Run on C01_watering_preview.blend after retarget_farming.py.
Build a constant, anatomically opposing power grip around the actual can arch.
The arm animation remains untouched; the wrist only cants during start/end
lowering to clear the thigh. Export only the independent clip.
"""
import bpy,math,json
from pathlib import Path
from mathutils import Vector,Matrix,Quaternion

output=Path(__file__).parent
scene=bpy.context.scene
target=bpy.data.objects['GeneralSkeleton']
body=bpy.data.objects['C01_Body']
scene.frame_set(68)
bpy.context.view_layer.update()
hand=target.pose.bones['RightHand']
hand_matrix=hand.matrix.copy()
hand_inverse=hand_matrix.inverted()
reference={b.name:hand_inverse @ b.matrix for b in target.pose.bones if b.name.startswith('RightHand')}
grip=Vector((0,.090,-.048))
desired={}
joint_positions={}

# Fingers follow arcs around the top handle's X-axis (radius .026 m).
# Joint centers stay outside that radius plus the character's finger thickness.
for finger,spread in [('Index',-.008),('Middle',-.003),('Ring',.006),('Pinky',.010)]:
    name='RightHand'+finger+'1'
    head=reference[name].translation.copy()
    radius=math.hypot(head.y-grip.y,head.z-grip.z)
    theta=math.atan2(head.z-grip.z,head.y-grip.y)
    for segment in range(1,4):
        name='RightHand'+finger+str(segment)
        bone=target.pose.bones[name]
        length=bone.bone.length
        dx=spread if segment==1 else 0
        chord=math.sqrt(max(0,length*length-dx*dx))
        theta-=2*math.asin(min(1,chord/(2*radius)))
        tail=Vector((head.x+dx,grip.y+radius*math.cos(theta),grip.z+radius*math.sin(theta)))
        ref_rotation=reference[name].to_quaternion()
        ref_direction=ref_rotation @ Vector((0,1,0))
        desired[name]=ref_direction.rotation_difference((tail-head).normalized()) @ ref_rotation
        joint_positions[name]={'head':list(head),'tail':list(tail),'radius':radius}
        head=tail

# Thumb crosses the wrist-facing side, opposing the four curled fingers.
# Its three lengths are preserved; all segment centers avoid the handle core.
head=reference['RightHandThumb1'].translation.copy()
thumb_directions=[Vector((-.023,-.005,-.027)),Vector((.018,-.002,-.014)),Vector((.017,.001,0))]
for segment,direction in enumerate(thumb_directions,1):
    name='RightHandThumb'+str(segment)
    bone=target.pose.bones[name]
    tail=head+direction.normalized()*bone.bone.length
    ref_rotation=reference[name].to_quaternion()
    desired[name]=(ref_rotation @ Vector((0,1,0))).rotation_difference((tail-head).normalized()) @ ref_rotation
    joint_positions[name]={'head':list(head),'tail':list(tail)}
    head=tail

# Solve rotations against each bone's static local rest frame. Since the grip
# is hand-local, the resulting finger quaternions are constant for every frame.
rest_rot={b.name:b.matrix_local.to_quaternion() for b in target.data.bones}
local_rotations={}
for name,rotation in desired.items():
    parent=target.pose.bones[name].parent.name
    parent_rotation=Quaternion() if parent=='RightHand' else desired[parent]
    local_rest=rest_rot[parent].conjugated() @ rest_rot[name]
    local_rotations[name]=(local_rest.conjugated() @ parent_rotation.conjugated() @ rotation).normalized()
for frame in range(1,170):
    scene.frame_set(frame)
    bpy.context.view_layer.update()
    # A small resting wrist cant keeps the suspended can clear of the thigh;
    # it fades out before pouring and returns only during the final lowering.
    t=(frame-1)/30
    wrist_blend=max(0.0,1-t/.9,(t-4.7)/.9)
    wrist_blend=min(1.0,wrist_blend)
    wrist_blend=wrist_blend*wrist_blend*(3-2*wrist_blend)
    current_hand=target.pose.bones['RightHand']
    desired_wrist=Quaternion((0,1,0),math.radians(18)*wrist_blend) @ current_hand.matrix.to_quaternion()
    parent=current_hand.parent.name
    local_rest=rest_rot[parent].conjugated() @ rest_rot['RightHand']
    current_hand.rotation_quaternion=(local_rest.conjugated() @ current_hand.parent.matrix.to_quaternion().conjugated() @ desired_wrist).normalized()
    current_hand.keyframe_insert('rotation_quaternion',frame=frame)
    for name,rotation in local_rotations.items():
        bone=target.pose.bones[name]
        bone.rotation_mode='QUATERNION'
        bone.rotation_quaternion=rotation
        bone.keyframe_insert('rotation_quaternion',frame=frame)
for layer in target.animation_data.action.layers:
    for strip in layer.strips:
        for bag in strip.channelbags:
            for curve in bag.fcurves:
                for key in curve.keyframe_points:key.interpolation='LINEAR'
scene.frame_set(1)
bpy.context.view_layer.update()
bpy.ops.object.select_all(action='DESELECT')
target.select_set(True);body.select_set(True)
bpy.context.view_layer.objects.active=target
bpy.ops.export_scene.gltf(filepath=str(output/'C01_watering_source.glb'),export_format='GLB',use_selection=True,export_animations=True,export_animation_mode='ACTIVE_ACTIONS',export_force_sampling=True,export_frame_range=False)
bpy.ops.wm.save_as_mainfile(filepath=str(output/'C01_watering_preview.blend'))
report={'clip':'Watering','duration':5.6,'frames':[1,169],'hand':'RightHand','can_grip_godot':[0,.55,0],'hand_local_grip_center':list(grip),'calibration_godot_columns':[[-1,0,0],[0,-1,0],[0,0,1]],'hand_local_calibration_quaternion_godot_xyzw':[0,0,1,0],'finger_local_quaternions_wxyz':{n:list(q) for n,q in local_rotations.items()},'finger_joints_handlocal':joint_positions}
(output/'watering_grip_calibration.json').write_text(json.dumps(report,indent=2),encoding='utf8')
print('WATERING_GRIP_SAVED')
