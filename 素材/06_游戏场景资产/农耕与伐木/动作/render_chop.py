import json
from pathlib import Path
import bpy
from mathutils import Vector

output=Path(__file__).parent
scene=bpy.context.scene
target=bpy.data.objects['GeneralSkeleton']
body=bpy.data.objects['C01_Body']
scene.render.engine='BLENDER_WORKBENCH'
scene.display.shading.light='STUDIO'
scene.display.shading.studiolight_rotate_z=0.4
scene.display.shading.color_type='TEXTURE'
scene.display.shading.show_shadows=True
scene.display.shading.show_cavity=True
scene.display.shading.cavity_type='BOTH'
scene.display.shading.background_type='WORLD'
if scene.world is None: scene.world=bpy.data.worlds.new('ReviewWorld')
scene.world.color=(0.12,0.15,0.18)
scene.render.resolution_x=480
scene.render.resolution_y=640
scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG'
cam_data=bpy.data.cameras.new('ChopReviewCamera')
cam=bpy.data.objects.new('ChopReviewCamera',cam_data)
scene.collection.objects.link(cam)
cam.location=(3.4,-5.0,2.3)
cam.rotation_euler=(Vector((0,0,0.95))-cam.location).to_track_quat('-Z','Y').to_euler()
cam_data.type='ORTHO'
cam_data.ortho_scale=2.8
scene.camera=cam
bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-0.008))
floor=bpy.context.object
floor.name='PreviewFloor'
floor.color=(0.34,0.40,0.42,1)
floor.data.materials.clear()
floor_mat=bpy.data.materials.new('Floor')
floor_mat.diffuse_color=(0.34,0.40,0.42,1)
floor.data.materials.append(floor_mat)
measurements=[]
for frame in range(1,scene.frame_end+1):
    scene.frame_set(frame)
    bpy.context.view_layer.update()
    evaluated=body.evaluated_get(bpy.context.evaluated_depsgraph_get())
    low=min((evaluated.matrix_world @ v.co).z for v in evaluated.data.vertices)
    measurements.append(low)
    if frame in [1,4,7,10,13,16,19,22,25,28,30,31,32,33,34,35,36]:
        scene.render.filepath=str(output/f'chop_frame_{frame:02d}.png')
        bpy.ops.render.render(write_still=True)
validation={'sampled_frames':scene.frame_end,'min_sole_z':min(measurements),'max_sole_z':max(measurements),'per_frame_sole_z':measurements}
(output/'floor_validation.json').write_text(json.dumps(validation,indent=2),encoding='utf-8')
print('FLOOR_VALIDATED',validation)
