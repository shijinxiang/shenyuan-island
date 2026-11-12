import bpy
from pathlib import Path
from mathutils import Matrix,Vector
p=Path(__file__).parent;s=bpy.context.scene;a=bpy.data.objects['GeneralSkeleton']
before=set(s.objects)
bpy.ops.import_scene.gltf(filepath='D:/浪费GPT额度/小温的游戏/游戏/assets/farming/axe.glb')
meshes=[o for o in set(s.objects)-before if o.type=='MESH']
original={o:o.matrix_world.copy() for o in meshes}
for o in meshes:o.parent=None
s.render.engine='BLENDER_WORKBENCH';s.display.shading.light='STUDIO';s.display.shading.color_type='TEXTURE'
s.display.shading.show_shadows=True;s.display.shading.show_cavity=True;s.display.shading.cavity_type='BOTH'
s.display.shading.background_type='WORLD'
if s.world is None:s.world=bpy.data.worlds.new('AxeDirectionWorld')
s.world.color=(.14,.17,.19)
s.render.resolution_x=640;s.render.resolution_y=720;s.render.resolution_percentage=100
cam_data=bpy.data.cameras.new('AxeDirectionCamera');cam=bpy.data.objects.new('AxeDirectionCamera',cam_data);s.collection.objects.link(cam);s.camera=cam
cam_data.type='ORTHO';cam_data.ortho_scale=2.8
cam.location=(3.4,-5,2.3);cam.rotation_euler=(Vector((0,0,.95))-cam.location).to_track_quat('-Z','Y').to_euler()
for frame in [1,28,31,34,35,36]:
    s.frame_set(frame);bpy.context.view_layer.update()
    right=a.pose.bones['RightHand'].matrix.translation.lerp(a.pose.bones['RightHandMiddle1'].matrix.translation,.65)
    left=a.pose.bones['LeftHand'].matrix.translation.lerp(a.pose.bones['LeftHandMiddle1'].matrix.translation,.65)
    axis=(right-left).normalized()
    side=(Vector((1,0,0))-axis*axis.x).normalized()
    for label,edge in [('before',side),('after',-side)]:
        basis=Matrix((edge,-edge.cross(axis),axis)).transposed()
        transform=basis.to_4x4();transform.translation=right-basis @ Vector((0,0,.32))
        for o in meshes:o.matrix_world=transform @ original[o]
        s.render.filepath=str(p/f'axe_direction_{label}_{frame:03d}.png')
        bpy.ops.render.render(write_still=True)
print('AXE_DIRECTION_PREVIEWED')
