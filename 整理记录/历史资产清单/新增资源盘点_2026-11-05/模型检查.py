import bpy, sys, json, pathlib, traceback
root=pathlib.Path(r'D:\浪费GPT额度\小温的游戏\素材'); out=root/'99_资产清单与整理记录'/'新增资源盘点_2026-11-05'; extra=out/'检查用解包'
archive=root/'05_待选资源库'
paths=[archive/'石头合集'/'LowPolyRockPack.blend',archive/'树合集'/'LowPolyTreePack.blend']+list((archive/'鱼').glob('*.fbx'))+list(extra.rglob('*.glb'))+list(extra.rglob('*.gltf'))+list(extra.rglob('*.fbx'))
result=[]
for p in paths:
 try:
  bpy.ops.wm.read_factory_settings(use_empty=True)
  if p.suffix=='.blend': bpy.ops.wm.open_mainfile(filepath=str(p),load_ui=False)
  elif p.suffix=='.fbx': bpy.ops.import_scene.fbx(filepath=str(p),use_anim=True)
  else: bpy.ops.import_scene.gltf(filepath=str(p))
  meshes=[]
  for o in bpy.data.objects:
   if o.type=='MESH':
    m=o.data;m.calc_loop_triangles()
    meshes.append({'name':o.name,'vertices':len(m.vertices),'faces':len(m.polygons),'triangles':len(m.loop_triangles),'materials':[x.name for x in m.materials if x],'modifiers':[x.type for x in o.modifiers]})
  result.append({'path':str(p.relative_to(root)),'current_path':str(p.relative_to(root)),'meshes':meshes,'actions':[{'name':a.name,'frames':list(a.frame_range)} for a in bpy.data.actions],'images':[{'name':i.name,'path':i.filepath,'packed':bool(i.packed_file)} for i in bpy.data.images if i.source=='FILE'],'objects':len(bpy.data.objects)})
 except Exception as e: result.append({'path':str(p),'error':str(e)})
(out/'模型检查.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')
