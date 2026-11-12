"""Render 24fps previews from the actual exported rig's source actions."""
import bpy, math, json, sys
from pathlib import Path
from mathutils import Vector
src=Path(__file__).resolve().parent
bpy.ops.wm.open_mainfile(filepath=str(src/'海岸生存_模型与动画.blend'))
scene=bpy.context.scene
for c in scene.collection.children:
    for o in c.objects:o.hide_render=c.name!='saltwater_crocodile'
arm=bpy.data.objects['CrocodileRig']
bpy.ops.mesh.primitive_plane_add(size=200);floor=bpy.context.object;floor.location.z=-.012
mat=bpy.data.materials.new('Neutral grey');mat.diffuse_color=(.32,.33,.34,1);floor.data.materials.append(mat)
w=bpy.data.worlds.new('Grey studio');scene.world=w;w.use_nodes=True;w.node_tree.nodes['Background'].inputs[0].default_value=(.65,.68,.72,1);w.node_tree.nodes['Background'].inputs[1].default_value=.7
bpy.ops.object.light_add(type='AREA',location=(-3,-4,5));bpy.context.object.data.energy=900;bpy.context.object.data.size=6
bpy.ops.object.camera_add(location=(3.9,-3.4,2.1));cam=bpy.context.object;cam.rotation_euler=(Vector((0,.05,.26))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=3.7;scene.camera=cam
scene.render.engine='CYCLES';scene.cycles.samples=8;scene.cycles.use_denoising=True
scene.render.resolution_x=640;scene.render.resolution_y=360;scene.render.resolution_percentage=100;scene.view_settings.view_transform='AgX'
scene.render.image_settings.file_format='PNG'
report=json.loads((src/'animation_preview_validation.json').read_text()) if (src/'animation_preview_validation.json').exists() else {}
only=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
for name,seconds in [('Crawl',1.2),('Swim',1.6),('Attack',.9)]:
    if only and name not in only:continue
    folder=src/'animation_frames'/name;folder.mkdir(parents=True,exist_ok=True)
    arm.animation_data.action=bpy.data.actions[name]
    frames=round(seconds*24)
    samples=[]
    for i in range(frames):
        time=seconds*i/frames;frame=1+time*30;scene.frame_set(int(frame),subframe=frame-int(frame));bpy.context.view_layer.update()
        if name=='Crawl':
            # Front-left ankle must track the planted-phase target without vertical slip.
            foot=arm.pose.bones['FrontLToes'];p=foot.matrix.translation.copy()
            phase=time/1.2
            samples.append({'time':time,'phase':phase,'ankle':list(p),'ground_phase':phase<.60})
        scene.render.filepath=str(folder/(f'{i:03d}.png'));bpy.ops.render.render(write_still=True)
    report[name]={'seconds':seconds,'frames':frames,'fps_approx':frames/seconds}
    if samples:
        contact=[s for s in samples if s['ground_phase']]
        report[name]['ankle_contact_y_range']=[min(s['ankle'][2] for s in contact),max(s['ankle'][2] for s in contact)]
        report[name]['stance_expected_height']=.055
        report[name]['max_contact_height_error']=max(abs(s['ankle'][2]-.055) for s in contact)
        report[name]['foot_samples']=samples
(src/'animation_preview_validation.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print('ANIMATION_PREVIEWS_RENDERED')
