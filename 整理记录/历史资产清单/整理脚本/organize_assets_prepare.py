from pathlib import Path
import json,struct,hashlib,shutil
B=Path(r'D:\浪费GPT额度\小温的游戏\素材'); OLD=B/'Blender模型'
REC=B/'99_资产清单与整理记录';REC.mkdir(exist_ok=True)
def glbinfo(p):
 raw=p.read_bytes();magic,ver,total=struct.unpack_from('<III',raw);assert magic==0x46546c67 and total==len(raw)
 n,k=struct.unpack_from('<II',raw,12);d=json.loads(raw[20:20+n]);tri=0
 for m in d.get('meshes',[]):
  for pr in m['primitives']:
   if pr.get('mode',4)==4:tri+=d['accessors'][pr['indices']]['count']//3 if 'indices' in pr else d['accessors'][pr['attributes']['POSITION']]['count']//3
 return {'sha256':hashlib.sha256(raw).hexdigest(),'bytes':len(raw),'triangles':tri,'meshes':len(d.get('meshes',[])),'materials':len(d.get('materials',[])),'images':len(d.get('images',[])),'embedded_images':all('bufferView' in i for i in d.get('images',[]))}
cats={'B':'B_建筑','C':'C_飞鸟','P':'P_设施与摆件','R':'R_岩石','V':'V_植物','T':'T_地形与主山体','F':'F_远景'}
assets=[];newids=[];newfiles=[]
for p in sorted(B.glob('*.glb')):
 name='T00_北端主山体' if p.stem=='远处高山' else p.stem
 code=name[:3];newids.append(code);dest=B/'01_正式模型'/cats[name[0]]/name;dest.mkdir(parents=True,exist_ok=True)
 info=glbinfo(p);target=dest/(name+'.glb');assert not target.exists();shutil.copy2(p,target);assert glbinfo(target)['sha256']==info['sha256']
 row={'id':code,'name':name,'source':'用户新模型','model':str(target),'original_file':str(p),'status':'原样保留，不减面、不改材质',**info};assets.append(row);newfiles.append(p)
rocks=json.loads((OLD/'项目统筹/岩石岸壁远景_交付清单.json').read_text(encoding='utf8'))
retained=[]
for name in ['B01_破旧木屋','B02_大型红色仓库','B03_白色灯塔']:
 retained.append((name,OLD/(name+'_外部细节版')))
retained.append(('V03_直干棕榈树',OLD/'V03_直干棕榈树'))
for row in rocks['assets']:
 if row['id'] in ['T05','T06','T07','F01','F02']:retained.append((row['asset'],Path(row['paths']['directory'])))
for name,src in retained:
 dest=B/'01_正式模型'/cats[name[0]]/name;dest.mkdir(parents=True,exist_ok=True)
 selected=[]
 for p in src.iterdir():
  if p.is_file() and p.suffix.lower() in ['.blend','.glb','.fbx','.png']:
   target=dest/('预览' if p.suffix.lower()=='.png' else '')/p.name;target.parent.mkdir(exist_ok=True);shutil.copy2(p,target);selected.append(str(target))
  elif p.is_dir() and p.name in ['renders','textures']:
   shutil.copytree(p,dest/('预览' if p.name=='renders' else '贴图'),dirs_exist_ok=True)
 model=next((str(p) for p in dest.glob('*.glb')),None)
 assert model,(name,'missing GLB')
 info=glbinfo(Path(model));assets.append({'id':name[:3],'name':name,'source':'保留原有模型','model':model,'status':'原有质量状态保留；本次仅整理','files':selected,**info})
# Explicit paths only: the deletion executor independently checks their resolved scope.
deletes=[];moves=[]
replace_ids=set(newids)-{'T00'}
for p in OLD.iterdir():
 if p.is_dir():
  if p.name[:3] in replace_ids or p.name.startswith('T_北侧') or p.name.startswith('整岛灰模_'):
   deletes.append(str(p))
  elif p.name.startswith('岩石岸壁远景_') and '备份' in p.name:
   for child in p.iterdir():
    if child.name[:3] in replace_ids:deletes.append(str(child))
   moves.append({'src':str(p),'dst':str(B/'90_制作工程与原有版本'/'岩岸历史工程'/p.name)})
  elif p.name in ['共享材质_剩余资产','建筑外部细节']:
   moves.append({'src':str(p),'dst':str(B/'04_共享材质与贴图'/p.name)})
  elif p.name=='项目统筹':moves.append({'src':str(p),'dst':str(REC/'原制作记录')})
  else:moves.append({'src':str(p),'dst':str(B/'90_制作工程与原有版本'/p.name)})
 else:
  if p.name.startswith(('深渊岛_整岛布局灰模','T_北侧块状山体')) and p.suffix.lower()=='.zip':deletes.append(str(p))
  else:moves.append({'src':str(p),'dst':str(B/'90_制作工程与原有版本'/'脚本日志与旧交付包'/p.name)})
for name in ['元素提取PNG','参考资料','参考图历史备份']:
 moves.append({'src':str(B/name),'dst':str(B/'03_参考图与资料'/name)})
if (B/'整理前场景检查.json').exists():moves.append({'src':str(B/'整理前场景检查.json'),'dst':str(REC/'整理前场景检查.json')})
plan={'material_root':str(B),'old_root':str(OLD),'new_asset_ids':sorted(newids),'assets':assets,'delete_old_paths':deletes,'delete_original_new_files_after_hash_verification':[str(p) for p in newfiles],'moves':moves,'scene_source':str(OLD/'整岛灰模_v08_建筑细节/深渊岛_建筑细节_v08.blend')}
(REC/'整理计划.json').write_text(json.dumps(plan,ensure_ascii=False,indent=2),encoding='utf8')
(REC/'资产清单.json').write_text(json.dumps(assets,ensure_ascii=False,indent=2),encoding='utf8')
print(json.dumps({'new':len(newfiles),'retained':len(retained),'deletions':len(deletes),'moves':len(moves)},ensure_ascii=True))
