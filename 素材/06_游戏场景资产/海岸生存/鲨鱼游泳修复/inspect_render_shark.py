"""Read-only verification of the existing Shark.glb skin and swim action."""
import bpy,json,math
import numpy as np
from pathlib import Path
from mathutils import Vector
OUT=Path(__file__).resolve().parent
PROJECT=OUT.parents[3]
MODEL=PROJECT/'游戏/assets/fauna/marine/Shark.glb'
bpy.ops.wm.read_factory_settings(use_empty=True)
scene=bpy.context.scene;scene.render.fps=30
bpy.ops.import_scene.gltf(filepath=str(MODEL))
arm=next(o for o in scene.objects if o.type=='ARMATURE');body=next(o for o in scene.objects if o.type=='MESH')
action=arm.animation_data.action
first,last=action.frame_range;duration=(last-first)/30
report={'source':str(MODEL),'armature':arm.name,'mesh':body.name,'clip':action.name,'frame_range':[first,last],'duration_seconds':duration,'bones':{},'skinning_weights':{},'mesh_vertices':len(body.data.vertices),'samples':[]}
for vg in body.vertex_groups:
    weighted=[v.index for v in body.data.vertices if any(g.group==vg.index and g.weight>.001 for g in v.groups)]
    report['skinning_weights'][vg.name]=len(weighted)
for b in arm.data.bones:report['bones'][b.name]={'head':list(b.head_local),'tail':list(b.tail_local),'parent':b.parent.name if b.parent else None,'max_local_rotation_change_deg':0,'max_local_translation_change_m':0}
first_q={};first_t={};initial=None
for i in range(25):
    f=first+(last-first)*i/24;scene.frame_set(int(f),subframe=f-int(f));bpy.context.view_layer.update()
    for pb in arm.pose.bones:
        q=pb.matrix_basis.to_quaternion();t=pb.matrix_basis.translation
        if i==0:first_q[pb.name]=q.copy();first_t[pb.name]=t.copy()
        angle=math.degrees(first_q[pb.name].rotation_difference(q).angle)
        report['bones'][pb.name]['max_local_rotation_change_deg']=max(report['bones'][pb.name]['max_local_rotation_change_deg'],angle)
        report['bones'][pb.name]['max_local_translation_change_m']=max(report['bones'][pb.name]['max_local_translation_change_m'],(t-first_t[pb.name]).length)
    deps=bpy.context.evaluated_depsgraph_get();ob=body.evaluated_get(deps);me=ob.to_mesh()
    pts=np.array([list(ob.matrix_world@v.co) for v in me.vertices]);ob.to_mesh_clear()
    if initial is None:initial=pts.copy()
    a=initial-initial.mean(axis=0);b=pts-pts.mean(axis=0)
    u,s,vh=np.linalg.svd(a.T@b);rotation=u@vh
    if np.linalg.det(rotation)<0:u[:,-1]*=-1;rotation=u@vh
    residual=np.linalg.norm(a@rotation-b,axis=1)
    report['samples'].append({'time_seconds':(f-first)/30,'max_vertex_delta_m':float(np.linalg.norm(pts-initial,axis=1).max()),'rigid_fit_residual_rms_m':float(np.sqrt(np.mean(residual**2))),'rigid_fit_residual_max_m':float(residual.max())})
report['max_nonrigid_rms_m']=max(s['rigid_fit_residual_rms_m'] for s in report['samples'])
report['max_nonrigid_vertex_residual_m']=max(s['rigid_fit_residual_max_m'] for s in report['samples'])
report['loop_seam_nonrigid_rms_m']=report['samples'][-1]['rigid_fit_residual_rms_m']
report['has_real_deformation']=report['max_nonrigid_rms_m']>.001
(OUT/'shark_skin_animation_analysis.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
scene.frame_set(int(first));bpy.context.view_layer.update()
coords=[body.matrix_world@Vector(c) for c in body.bound_box];lo=Vector(tuple(min(v[i] for v in coords) for i in range(3)));hi=Vector(tuple(max(v[i] for v in coords) for i in range(3)));center=(lo+hi)*.5;size=hi-lo
report['bounds_min']=list(lo);report['bounds_size']=list(size)
(OUT/'shark_skin_animation_analysis.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'Shark_原骨骼动作核验.blend'))
world=bpy.data.worlds.new('Neutral studio');scene.world=world;world.use_nodes=True;world.node_tree.nodes['Background'].inputs[0].default_value=(.35,.45,.50,1);world.node_tree.nodes['Background'].inputs[1].default_value=.7
bpy.ops.object.light_add(type='AREA',location=center+Vector((2,-3,5))*max(size));bpy.context.object.data.energy=1100*max(size)**2;bpy.context.object.data.size=5*max(size)
bpy.ops.object.camera_add(location=center+Vector((3,-4,2.5))*max(size));cam=bpy.context.object;cam.rotation_euler=(center-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=max(size)*1.65;scene.camera=cam
scene.render.engine='CYCLES';scene.cycles.samples=8;scene.cycles.use_denoising=True;scene.render.resolution_x=640;scene.render.resolution_y=360;scene.render.resolution_percentage=100
frames=OUT/'frames';frames.mkdir(exist_ok=True)
count=max(24,min(72,round(duration*24)))
for i in range(count):
    f=first+(last-first)*i/count;scene.frame_set(int(f),subframe=f-int(f));scene.render.filepath=str(frames/(f'{i:03d}.png'));bpy.ops.render.render(write_still=True)
print('SHARK_DEFORMATION_VERIFIED '+json.dumps({'clip':action.name,'duration':duration,'bones':len(arm.data.bones),'nonrigid_rms_m':report['max_nonrigid_rms_m'],'frames':count}))
