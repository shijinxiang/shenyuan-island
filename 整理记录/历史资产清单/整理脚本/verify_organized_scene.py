import bpy,json
from pathlib import Path
b=Path(r'D:\浪费GPT额度\小温的游戏\素材');bpy.ops.wm.open_mainfile(filepath=str(b/'02_整岛场景/深渊岛_当前场景.blend'))
missing=[im.name for im in bpy.data.images if im.source=='FILE' and im.users and not im.packed_file and not Path(bpy.path.abspath(im.filepath)).exists()]
old=[o.name for o in bpy.context.scene.objects if o.name.startswith(('P01 proxy |','P02 proxy |','T_MountainRange_'))]
actual={}
for prefix in ['T00_','P01_','P02_']:
 n=0
 for o in bpy.context.scene.objects:
  if o.type=='MESH' and o.name.startswith(prefix):o.data.calc_loop_triangles();n+=len(o.data.loop_triangles)
 actual[prefix]=n
assert not missing and not old,(missing,old)
assert actual=={'T00_':1499942,'P01_':1500000,'P02_':999868},actual
r={'reopened_after_relocation':True,'missing_images':missing,'obsolete_objects':old,'user_model_triangles_in_scene':actual}
(b/'99_资产清单与整理记录/最终场景打开检查.json').write_text(json.dumps(r,ensure_ascii=False,indent=2),encoding='utf8');print('FINAL_SCENE_VERIFIED',r)
