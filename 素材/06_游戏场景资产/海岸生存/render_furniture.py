import bpy
from pathlib import Path
from mathutils import Vector
src=Path(__file__).resolve().parent
bpy.ops.wm.open_mainfile(filepath=str(src/'海岸生存_模型与动画.blend'))
scene=bpy.context.scene
for c in scene.collection.children:
    for o in c.objects:o.hide_render=c.name not in ['bed','chest','cabin_lamp','food_bundle','medical_kit']
positions={'bed':(-1.1,.35,0),'chest':(.85,.4,0),'cabin_lamp':(.9,-.60,0),'food_bundle':(1.55,-.4,0),'medical_kit':(1.65,.2,0)}
for name,pos in positions.items():
    for ob in bpy.data.collections[name].objects:
        if ob.parent is None:ob.location+=Vector(pos)
lid=bpy.data.objects['LidPivot'];lid.rotation_euler.x=-1.3
bpy.ops.mesh.primitive_plane_add(size=200);bpy.context.object.location.z=-.005
mat=bpy.data.materials.new('Neutral sand');mat.diffuse_color=(.42,.39,.31,1);bpy.context.object.data.materials.append(mat)
w=bpy.data.worlds.new('Studio');scene.world=w;w.use_nodes=True;w.node_tree.nodes['Background'].inputs[1].default_value=.5
bpy.ops.object.light_add(type='AREA',location=(-3,-4,5));bpy.context.object.data.energy=800;bpy.context.object.data.size=5
bpy.ops.object.camera_add(location=(4,-6,4));cam=bpy.context.object;cam.rotation_euler=(Vector((0,.1,.3))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=4.5;scene.camera=cam
scene.render.engine='CYCLES';scene.cycles.samples=24;scene.render.resolution_x=1400;scene.render.resolution_y=1000;scene.render.resolution_percentage=100
scene.render.filepath=str(src/'家具与补给_模型总览.png');bpy.ops.render.render(write_still=True)
