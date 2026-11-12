import zipfile,pathlib,json
root=pathlib.Path(r'D:\浪费GPT额度\小温的游戏\素材'); out=root/'99_资产清单与整理记录'/'新增资源盘点_2026-11-05'; dest=out/'检查用解包'
for group,name in [('草地','stylizedGrassMeshes.zip'),('草地','shaderSTYLIZEDGRASS.zip'),('鱼','FolderToUpload.zip')]:
 with zipfile.ZipFile(root/group/name) as z:
  print(name, 'bad=',z.testzip())
  for i in z.infolist():
   if i.is_dir():continue
   # Keep copies only for actual inspection, and record all entries separately.
   if name=='FolderToUpload.zip' and i.filename not in ['FolderToUpload/fbx/ClownFish.fbx','FolderToUpload/fbx/TunaFish.fbx','FolderToUpload/fbx/DoryFish.fbx','FolderToUpload/fbx/BrownFish.fbx','FolderToUpload/fbx/Rock.fbx','FolderToUpload/fbx/SeaWeed.fbx']: continue
   p=dest/name/i.filename;p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(z.read(i))
   if i.filename.endswith('license.txt'): print('LICENSE',z.read(i).decode('utf-8',errors='replace'))
