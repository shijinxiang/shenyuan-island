import bpy,json
from pathlib import Path
from mathutils import Matrix,Vector
output=Path(__file__).parent
scene=bpy.context.scene
target=bpy.data.objects['GeneralSkeleton']
body=bpy.data.objects['C01_Body']
before=set(scene.objects)
bpy.ops.import_scene.gltf(filepath='D:/浪费GPT额度/小温的游戏/游戏/assets/farming/watering_can.glb')
can_meshes=[o for o in set(scene.objects)-before if o.type=='MESH']
can_matrices={o:o.matrix_world.copy() for o in can_meshes}
for o in can_meshes:o.parent=None
grip=Vector(json.loads((output/'watering_grip_calibration.json').read_text())['hand_local_grip_center'])
# Blender can X->-hand X, Y->-hand Z, Z->-hand Y.
godot_calibration=Matrix(json.loads((output/'watering_grip_calibration.json').read_text())['calibration_godot_columns']).transposed()
calibration=godot_calibration @ Matrix(((1,0,0),(0,0,1),(0,-1,0)))
can_grip=Vector((0,0,.55))
scene.render.engine='BLENDER_WORKBENCH'
scene.display.shading.light='STUDIO';scene.display.shading.color_type='TEXTURE'
scene.display.shading.show_shadows=True;scene.display.shading.show_cavity=True
scene.display.shading.cavity_type='BOTH'
scene.display.shading.background_type='WORLD'
if scene.world is None:scene.world=bpy.data.worlds.new('GripWorld')
scene.world.color=(.14,.17,.19)
scene.render.resolution_x=720;scene.render.resolution_y=720
scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG'
cam_data=bpy.data.cameras.new('GripReviewCamera')
cam=bpy.data.objects.new('GripReviewCamera',cam_data);scene.collection.objects.link(cam)
cam_data.type='ORTHO';scene.camera=cam
for frame in range(1,170):
    scene.frame_set(frame);bpy.context.view_layer.update()
    hand=target.matrix_world @ target.pose.bones['RightHand'].matrix
    basis=hand.to_3x3() @ calibration
    transform=basis.to_4x4();transform.translation=hand @ grip-basis @ can_grip
    for o in can_meshes:
        o.rotation_mode='QUATERNION'
        o.matrix_world=transform @ can_matrices[o]
        o.keyframe_insert('location',frame=frame)
        o.keyframe_insert('rotation_quaternion',frame=frame)
frames=list(range(1,170,6))
for frame in frames:
    scene.frame_set(frame);bpy.context.view_layer.update()
    hand=target.matrix_world @ target.pose.bones['RightHand'].matrix
    basis=hand.to_3x3() @ calibration
    center=hand @ grip
    transform=basis.to_4x4();transform.translation=center-basis @ can_grip
    for o in can_meshes:o.matrix_world=transform @ can_matrices[o]
    for label,local_view in [('grip',Vector((-.22,.24,-.22))),('back',Vector((-.22,-.12,.30)))]:
        cam.location=center+hand.to_3x3() @ local_view
        cam.rotation_euler=(center-cam.location).to_track_quat('-Z','Y').to_euler()
        cam_data.ortho_scale=.38
        scene.render.filepath=str(output/f'watering_{label}_{frame:03d}.png')
        bpy.ops.render.render(write_still=True)
    cam.location=(3.4,-5.0,2.3)
    cam.rotation_euler=(Vector((0,0,.95))-cam.location).to_track_quat('-Z','Y').to_euler()
    cam_data.ortho_scale=2.8
    scene.render.filepath=str(output/f'watering_held_{frame:03d}.png')
    bpy.ops.render.render(write_still=True)
scene.frame_set(64)
bpy.ops.wm.save_as_mainfile(filepath=str(output/'C01_watering_held_review.blend'))
print('COMBINED_GRIP_RENDERED',frames)
