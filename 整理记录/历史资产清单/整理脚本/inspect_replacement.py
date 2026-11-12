import bpy,json
from pathlib import Path
from mathutils import Vector
b=Path(r'D:\浪费GPT额度\小温的游戏\素材')
bpy.ops.wm.open_mainfile(filepath=str(b/'Blender模型/整岛灰模_v08_建筑细节/深渊岛_建筑细节_v08.blend'))
rows=[]
for o in bpy.context.scene.objects:
 if o.type in {'MESH','EMPTY'}:
  pts=[o.matrix_world@Vector(c) for c in o.bound_box] if o.type=='MESH' else []
  rows.append({'name':o.name,'type':o.type,'parent':o.parent.name if o.parent else None,'cols':[c.name for c in o.users_collection],'loc':list(o.location),'rot':list(o.rotation_euler),'dims':list(o.dimensions),'bounds':[[min(p[i] for p in pts),max(p[i] for p in pts)] for i in range(3)] if pts else None})
out=b/'整理前场景检查.json';out.write_text(json.dumps(rows,ensure_ascii=False,indent=2),encoding='utf8')
print('SCENE_REPORT',str(out));print('TARGETS',json.dumps([r for r in rows if any(k in r['name'] for k in ['P01','P02','B02','massif','mountain','Mountain','proxy','船','码头'])],ensure_ascii=False))
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.gltf(filepath=str(b/'远处高山.glb'))
for o in bpy.context.scene.objects:
 if o.type=='MESH':print('NEW_MOUNTAIN',o.name,list(o.dimensions),[list(o.matrix_world@Vector(v)) for v in o.bound_box])
