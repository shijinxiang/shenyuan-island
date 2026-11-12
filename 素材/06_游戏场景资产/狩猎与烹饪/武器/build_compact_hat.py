import bpy,bmesh
from pathlib import Path
from mathutils import Vector
P=Path(r'D:/浪费GPT额度/小温的游戏/游戏');S=Path(r'D:/浪费GPT额度/小温的游戏/素材/06_游戏场景资产/狩猎与烹饪/武器')
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(P/'assets/characters/C01_locomotion.glb'))
body=next(o for o in bpy.context.scene.objects if o.type=='MESH');rig=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE')
# Find the original disconnected hat using a welded temporary copy; retain original UVs and weights.
bm=bmesh.new();bm.from_mesh(body.data);bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=.0001);bm.verts.ensure_lookup_table();seen=set();hat_set=set()
for v in bm.verts:
 if v in seen:continue
 stack=[v];seen.add(v);island=[]
 while stack:
  w=stack.pop();island.append(w)
  for e in w.link_edges:
   j=e.other_vert(w)
   if j not in seen:seen.add(j);stack.append(j)
 vs=[body.matrix_world@w.co for w in island]
 if max(v.x for v in vs)-min(v.x for v in vs)>.7 and min(v.z for v in vs)>1.4:
  hat_set.update(tuple(round(c,5) for c in w.co) for w in island)
bm.free();assert len(hat_set)>1000,len(hat_set)

count=0
for v in body.data.vertices:
 if tuple(round(c,5) for c in v.co) not in hat_set:continue
 p=body.matrix_world@v.co
 r=(p.x*p.x+p.y*p.y)**.5
 if r>.16:
  new_r=.16+(r-.16)*.005
  factor=new_r/r;p.x*=factor;p.y*=factor
  blend=min(1.,max(0.,(r-.16)/.035));p.z=p.z*(1-blend)+(1.64+(p.z-1.64)*.10)*blend
  v.co=body.matrix_world.inverted()@p;count+=1
rig.animation_data_clear()
for b in rig.pose.bones:b.matrix_basis.identity()
bpy.ops.object.select_all(action='DESELECT');body.select_set(True);rig.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(P/'assets/hunting/C01_bow_hat.glb'),export_format='GLB',use_selection=True,export_animations=False)
bpy.ops.wm.save_as_mainfile(filepath=str(S/'C01_弓姿窄帽檐变体.blend'))
print('BRIM_VERTICES_NARROWED',count)




