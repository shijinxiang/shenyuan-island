import bpy,json
from pathlib import Path
from mathutils import Vector
R=Path(__file__).resolve().parent
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(R/'V03_直干棕榈树.glb'));bpy.context.view_layer.update()
obs=[o for o in bpy.context.scene.objects if o.type=='MESH'];n=0
for o in obs:o.data.calc_loop_triangles();n+=len(o.data.loop_triangles)
images=[{'name':im.name,'size':list(im.size),'loaded':im.has_data,'packed':bool(im.packed_file)} for im in bpy.data.images if im.source=='FILE']
assert images and all(im['loaded'] for im in images)
report={'triangles':n,'meshes':len(obs),'all_have_uv':all(len(o.data.uv_layers)>0 for o in obs),'images':images,'geometry_and_materials_modified':False}
meta=json.loads((R/'新模型信息.json').read_text(encoding='utf8'));assert n==meta['triangles']
points=[o.matrix_world@Vector(c) for o in obs for c in o.bound_box];lo=Vector([min(p[i] for p in points) for i in range(3)]);hi=Vector([max(p[i] for p in points) for i in range(3)]);center=(hi+lo)/2;size=max(hi-lo)
report['dimensions']=list(hi-lo)
sc=bpy.context.scene;sc.world=bpy.data.worlds.new('Review');sc.world.use_nodes=True;sc.world.node_tree.nodes['Background'].inputs[0].default_value=(.18,.15,.20,1);sc.world.node_tree.nodes['Background'].inputs[1].default_value=.5
for loc,power in [((2,-3,4),120),((-3,-1,2),70)]:
 bpy.ops.object.light_add(type='AREA',location=center+Vector(loc)*size);l=bpy.context.object;l.data.energy=power*size*size;l.data.size=size*3;l.rotation_euler=(center-l.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.object.camera_add(location=center+Vector((2,-4,1.6))*size);cam=bpy.context.object;cam.rotation_euler=(center-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=size*1.3;sc.camera=cam
sc.render.engine='CYCLES';sc.cycles.samples=16;sc.cycles.use_denoising=True
try:
 p=bpy.context.preferences.addons['cycles'].preferences;p.compute_device_type='OPTIX';p.get_devices()
 for d in p.devices:d.use=d.type=='OPTIX'
 sc.cycles.device='GPU'
except Exception:pass
sc.render.resolution_x=1000;sc.render.resolution_y=1200;sc.render.resolution_percentage=100;sc.render.image_settings.file_format='PNG';sc.render.filepath=str(R/'新模型预览.png')
bpy.ops.render.render(write_still=True)
(R/'导入检查.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf8');print('V03_VERIFIED',report)
