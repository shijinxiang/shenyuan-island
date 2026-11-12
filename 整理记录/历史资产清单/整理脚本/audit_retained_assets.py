import bpy,json,hashlib
from pathlib import Path
B=Path(r'D:\浪费GPT额度\小温的游戏\素材');REC=B/'99_资产清单与整理记录';assets=json.loads((REC/'资产清单.json').read_text(encoding='utf8'));rows=[]
bpy.context.preferences.filepaths.save_version=0
for a in assets:
 if a['source']!='保留原有模型':continue
 for p in Path(a['model']).parent.glob('*.blend'):
  bpy.ops.wm.open_mainfile(filepath=str(p));issues=[];images=[];changed=False
  for im in bpy.data.images:
   if im.source!='FILE' or not im.users:continue
   if not im.packed_file:
    if not im.has_data:
     try:im.reload()
     except Exception:pass
    if im.has_data:
     try:im.pack();changed=True
     except Exception as e:issues.append(im.name+': '+str(e))
    else:issues.append(im.name+': missing image')
   images.append({'name':im.name,'packed':bool(im.packed_file),'size':list(im.size)})
  assert not issues,(str(p),issues)
  if changed:bpy.ops.wm.save_as_mainfile(filepath=str(p))
  rows.append({'asset':a['id'],'blend':str(p),'images':images,'missing_images':issues})
(REC/'保留模型贴图检查.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2),encoding='utf8');print('VERIFIED_RETAINED',len(rows))
