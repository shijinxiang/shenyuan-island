import bpy,json,struct
from pathlib import Path
BASE=Path(__file__).resolve().parent.parent
results=[]
for name in ['B01_破旧木屋','B02_大型红色仓库','B03_白色灯塔']:
 root=BASE/(name+'_外部细节版');p=root/(name+'.glb');data=p.read_bytes();chunks=[];offset=12
 while offset<len(data):
  size,kind=struct.unpack_from('<II',data,offset);chunks.append((kind,data[offset+8:offset+8+size]));offset+=8+size
 doc=json.loads(chunks[0][1]);alpha=[]
 for m in doc.get('materials',[]):
  if m.get('name','').startswith(('Ivy |','Crack |')):
   m['alphaMode']='MASK';m['alphaCutoff']=.25 if m['name'].startswith('Ivy') else .10;m['doubleSided']=True;alpha.append(m['name'])
 j=json.dumps(doc,ensure_ascii=False,separators=(',',':')).encode();j+=b' '*((-len(j))%4);chunks[0]=(chunks[0][0],j)
 body=b''.join(struct.pack('<II',len(c),k)+c for k,c in chunks);p.write_bytes(struct.pack('<III',0x46546c67,2,len(body)+12)+body)
 expected=json.loads((root/'export_report.json').read_text(encoding='utf8'))['triangles']
 for ext in ['glb','fbx']:
  bpy.ops.wm.read_factory_settings(use_empty=True)
  if ext=='glb':bpy.ops.import_scene.gltf(filepath=str(p))
  else:bpy.ops.import_scene.fbx(filepath=str(root/(name+'.fbx')))
  obs=[o for o in bpy.context.scene.objects if o.type=='MESH'];n=0;zero=0;dups=0
  for o in obs:
   o.data.calc_loop_triangles();n+=len(o.data.loop_triangles);zero+=sum(t.area<1e-10 for t in o.data.loop_triangles)
   keys=[]
   for t in o.data.loop_triangles:keys.append(tuple(sorted(tuple(round(v,6) for v in o.data.vertices[i].co) for i in t.vertices)))
   dups+=len(keys)-len(set(keys))
  missing=[im.name for im in bpy.data.images if im.source=='FILE' and not im.packed_file and not Path(bpy.path.abspath(im.filepath)).exists()]
  row={'asset':name,'format':ext,'triangles':n,'expected':expected,'zero_area_triangles':zero,'duplicate_triangles':dups,'missing_images':missing,'alpha_materials':alpha}
  assert n==expected and n<=12000 and not missing and not zero and not dups,row
  results.append(row)
(BASE/'建筑外部细节/export_verification.json').write_text(json.dumps(results,ensure_ascii=False,indent=2),encoding='utf8');print('VERIFIED',json.dumps(results,ensure_ascii=False))
