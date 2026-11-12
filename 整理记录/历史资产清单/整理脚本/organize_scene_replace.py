import bpy,json,math,hashlib
import numpy as np
from pathlib import Path
from mathutils import Vector
B=Path(r'D:\浪费GPT额度\小温的游戏\素材');REC=B/'99_资产清单与整理记录'
plan=json.loads((REC/'整理计划.json').read_text(encoding='utf8'));files={a['id']:a['model'] for a in plan['assets']}
OUT=B/'02_整岛场景';OUT.mkdir(exist_ok=True);(OUT/'预览').mkdir(exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=plan['scene_source']);sc=bpy.context.scene;bpy.context.preferences.filepaths.save_version=0
def signature(o):
 v=np.empty(len(o.data.vertices)*3,dtype=np.float32);o.data.vertices.foreach_get('co',v)
 return hashlib.sha256(v.tobytes()).hexdigest()
terrain=[o for o in sc.objects if o.type=='MESH' and o.name.startswith('TERRAIN |')];assert len(terrain)==1
terrain_hash=signature(terrain[0]);original_keep={o.name:signature(o) for o in sc.objects if o.type=='MESH' and o.name.startswith(('B01_','B02_','B03_'))}
def bounds(obs):
 pts=[o.matrix_world@Vector(c) for o in obs if o.type=='MESH' for c in o.bound_box]
 lo=Vector(tuple(min(p[i] for p in pts) for i in range(3)));hi=Vector(tuple(max(p[i] for p in pts) for i in range(3)))
 return lo,hi
old_mount=[o for o in sc.objects if o.type=='MESH' and o.name=='T_MountainRange_SurroundingPeaks_12K'];assert len(old_mount)==1
ml,mh=bounds(old_mount);pier=bpy.data.objects['P01 proxy | pier deck'];ploc=pier.location.copy();yaw=pier.rotation_euler.z
boat=bpy.data.objects['P02 proxy | moored boat volume'];bloc=boat.location.copy()
remove=[o for o in sc.objects if o.name.startswith(('P01 proxy |','P02 proxy |'))]+old_mount
removed=[o.name for o in remove]
for o in remove:bpy.data.objects.remove(o,do_unlink=True)
collection=bpy.data.collections.new('09_用户新模型_原始网格');sc.collection.children.link(collection)
report={'removed_objects':removed,'terrain_vertices_sha256_before':terrain_hash,'placements':[]}
def import_asset(code):
 before=set(bpy.data.objects);bpy.ops.import_scene.gltf(filepath=files[code]);obs=[o for o in bpy.data.objects if o not in before]
 root=bpy.data.objects.new(code+'_用户原模',None);collection.objects.link(root)
 for o in obs:
  if o.parent is None:o.parent=root
  for c in list(o.users_collection):c.objects.unlink(o)
  collection.objects.link(o);o.name=code+'_'+o.name
 bpy.context.view_layer.update();return root,obs
def place(code,target,scale,angle=0):
 root,obs=import_asset(code);lo,hi=bounds(obs);dim=hi-lo
 s=scale(dim);root.scale=(s,s,s);root.rotation_euler.z=angle(dim);bpy.context.view_layer.update();lo2,hi2=bounds(obs)
 dest=target(lo2,hi2,obs);root.location=Vector(dest);bpy.context.view_layer.update()
 lo3,hi3=bounds(obs);tri=0
 for o in obs:
  if o.type=='MESH':o.data.calc_loop_triangles();tri+=len(o.data.loop_triangles)
 report['placements'].append({'id':code,'triangles':tri,'uniform_scale':s,'bounds':[list(lo3),list(hi3)],'mesh_unchanged':True,'material_unchanged':True})
 return root
place('T00',lambda l,h,obs:((ml.x+mh.x-l.x-h.x)/2,(ml.y+mh.y-l.y-h.y)/2,ml.z-l.z),lambda d:(mh.x-ml.x)/d.x,lambda d:0)
def pier_target(l,h,obs):
 vals=[]
 for o in obs:
  if o.type=='MESH':
   co=np.empty(len(o.data.vertices)*3,dtype=np.float32);o.data.vertices.foreach_get('co',co);co=co.reshape(-1,3);m=np.array(o.matrix_world);z=co@m[2,:3]+m[2,3];vals.append(z)
 z=np.concatenate(vals);hist,edges=np.histogram(z,bins=120);i=int(np.argmax(hist));deck=float((edges[i]+edges[i+1])/2)
 return (ploc.x-(l.x+h.x)/2,ploc.y-(l.y+h.y)/2,2.16-deck)
place('P01',pier_target,lambda d:24/max(d.x,d.y),lambda d:yaw+(math.pi/2 if d.x>d.y else 0))
place('P02',lambda l,h,obs:(bloc.x-(l.x+h.x)/2,bloc.y-(l.y+h.y)/2,.1-l.z),lambda d:6/max(d.x,d.y),lambda d:yaw+(math.pi/2 if d.x>d.y else 0))
# Relocate existing retained resources without re-authoring their geometry or materials.
assert signature(terrain[0])==terrain_hash
assert all(signature(bpy.data.objects[n])==sig for n,sig in original_keep.items())
report['terrain_and_building_geometry_unchanged']=True
for o in sc.objects:o.select_set(False)
bpy.ops.file.pack_all();sc['asset_library']='../01_正式模型';sc['replacement_note']='User meshes preserved; only instance translation, rotation and uniform scale changed.'
sc.camera=bpy.data.objects['Camera | main reference'];sc.render.resolution_x=1400;sc.render.resolution_y=1050;sc.render.resolution_percentage=100;sc.render.image_settings.file_format='PNG';sc.render.engine='CYCLES';sc.cycles.samples=16;sc.cycles.use_denoising=True
try:
 pref=bpy.context.preferences.addons['cycles'].preferences;pref.compute_device_type='OPTIX';pref.get_devices()
 for d in pref.devices:d.use=d.type=='OPTIX'
 sc.cycles.device='GPU'
except Exception:pass
bpy.ops.outliner.orphans_purge(do_recursive=True)
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'深渊岛_当前场景.blend'))
for cam,label in [('Camera | main reference','整岛替换预览'),('Camera | landing detail','新码头与船')]:
 sc.camera=bpy.data.objects[cam];sc.render.filepath=str(OUT/'预览'/(label+'.png'));bpy.ops.render.render(write_still=True)
sc.camera=bpy.data.objects['Camera | main reference']
for o in sc.objects:
 if o.type in {'MESH','EMPTY','CURVE'} and not o.hide_render and not any('STUDIO' in c.name or 'LABEL' in c.name for c in o.users_collection):o.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(OUT/'深渊岛_当前场景.glb'),export_format='GLB',use_selection=True,export_apply=True,export_animations=False,export_cameras=False,export_lights=False)
(REC/'整岛替换检查.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf8');print('SCENE_REPLACED',json.dumps(report,ensure_ascii=False))
