import bpy
from pathlib import Path
from mathutils import Vector
src=Path(__file__).resolve().parent
bpy.ops.wm.open_mainfile(filepath=str(src/'沙滩车_模型库.blend'))
scene=bpy.context.scene
with bpy.data.libraries.load(str(src/'C01_车辆动作_重定向.blend'),link=False) as (a,b):
    b.objects=['GeneralSkeleton','C01_Body']
for ob in b.objects:
    if ob:scene.collection.objects.link(ob)
rig=bpy.data.objects['GeneralSkeleton'];body=bpy.data.objects['C01_Body'];rig.location=(0,.25,0)
rig.animation_data.action=bpy.data.actions.get('Driving');scene.frame_set(1)
bpy.ops.mesh.primitive_plane_add(size=200);bpy.context.object.location.z=-.005
m=bpy.data.materials.new('Sand backdrop');m.diffuse_color=(.38,.35,.28,1);bpy.context.object.data.materials.append(m)
w=bpy.data.worlds.new('Daylight');scene.world=w;w.use_nodes=True;w.node_tree.nodes['Background'].inputs[1].default_value=.55
bpy.ops.object.light_add(type='AREA',location=(-3,-4,6));bpy.context.object.data.energy=1100;bpy.context.object.data.size=5
bpy.ops.object.camera_add(location=(3.7,-4.5,2.9));cam=bpy.context.object;cam.rotation_euler=(Vector((0,0,.80))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=3.7;scene.camera=cam
scene.render.engine='CYCLES';scene.cycles.samples=24;scene.render.resolution_x=1400;scene.render.resolution_y=1100;scene.render.resolution_percentage=100
scene.render.filepath=str(src/'沙滩车_驾驶姿态核验.png');bpy.ops.render.render(write_still=True)
cam.location=(4,0,1.8);cam.rotation_euler=(Vector((0,0,.8))-cam.location).to_track_quat('-Z','Y').to_euler();scene.render.filepath=str(src/'沙滩车_驾驶侧视核验.png');bpy.ops.render.render(write_still=True)
bpy.ops.wm.save_as_mainfile(filepath=str(src/'沙滩车_人物驾驶核验.blend'))
