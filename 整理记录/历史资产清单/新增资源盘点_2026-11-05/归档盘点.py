import pathlib,hashlib,shutil,json,csv,zipfile,collections,datetime
root=pathlib.Path(r'D:\浪费GPT额度\小温的游戏\素材').resolve(); out=root/'99_资产清单与整理记录'/'新增资源盘点_2026-11-05'; dest=root/'05_待选资源库'; groups=['草地','石头合集','树合集','鱼']
def sha(p):
 h=hashlib.sha256()
 with p.open('rb') as f:
  for b in iter(lambda:f.read(1048576),b''):h.update(b)
 return h.hexdigest()
def within(p): return p.resolve().is_relative_to(root)
assert within(dest) and not dest.exists()
for g in groups:
 s=root/g; assert s.is_dir() and within(s) and not s.is_symlink()
 assert all(not p.is_symlink() and within(p) for p in s.rglob('*'))
files=[p for g in groups for p in (root/g).rglob('*') if p.is_file()]
before={str(p.relative_to(root)): {'size':p.stat().st_size,'sha256':sha(p)} for p in files}
dest.mkdir()
for g in groups: shutil.move(str(root/g),str(dest/g))
results=[]
for old,meta in before.items():
 new=dest/old; assert within(new) and new.is_file()
 aft=sha(new);results.append({'原相对路径':old,'归档相对路径':str(new.relative_to(root)),'字节数':meta['size'],'移动前SHA256':meta['sha256'],'移动后SHA256':aft,'一致':aft==meta['sha256']})
assert all(x['一致'] for x in results)
archive={'日期':'2026-11-05','文件数量':len(results),'总字节数':sum(x['字节数'] for x in results),'逐文件核验全部一致':True,'文件':results}
(out/'归档核验.json').write_text(json.dumps(archive,ensure_ascii=False,indent=2),encoding='utf8')
rows=[]
for x in results:
 p=root/x['归档相对路径']; ext=p.suffix.lower(); group=p.relative_to(dest).parts[0]
 license='压缩包内 MIT License，Copyright (c) 2023 StayAtHomeDev' if group=='草地' else '未发现许可文件'
 rows.append({'类型':'原始文件','组':group,'位置':str(p.relative_to(root)),'包内路径':'','字节':x['字节数'],'SHA256':x['移动后SHA256'],'许可':license,'备注':'原件，未修改'})
 if ext=='.zip':
  with zipfile.ZipFile(p) as z:
   for i in z.infolist():
    if not i.is_dir(): rows.append({'类型':'ZIP成员','组':group,'位置':str(p.relative_to(root)),'包内路径':i.filename,'字节':i.file_size,'SHA256':hashlib.sha256(z.read(i)).hexdigest(),'许可':license,'备注':'ZIP CRC完整性通过'})
 if ext=='.rar':
  unpack=out/'检查用解包'/'FishBundleLowPoly.rar'
  for m in unpack.rglob('*'):
   if m.is_file(): rows.append({'类型':'RAR成员','组':group,'位置':str(p.relative_to(root)),'包内路径':str(m.relative_to(unpack)),'字节':m.stat().st_size,'SHA256':sha(m),'许可':license,'备注':'tar解包成功'})
counts=collections.Counter(r['SHA256'] for r in rows)
for row in rows:
 if counts[row['SHA256']]>1: row['备注']+='；SHA256与其他条目相同'
with (out/'清单.csv').open('w',encoding='utf-8-sig',newline='') as f:
 w=csv.DictWriter(f,fieldnames=['类型','组','位置','包内路径','字节','SHA256','许可','备注']);w.writeheader();w.writerows(rows)
readme=root/'00_从这里开始.txt'
with readme.open('a',encoding='utf8') as f:f.write('\n2026-11-05 新增待选资源：草地、石头合集、树合集、鱼原件位于05_待选资源库；逐文件清单、许可与使用建议、归档核验见99_资产清单与整理记录/新增资源盘点_2026-11-05。未导入Godot场景。\n')
print('original',len(results),'bytes',sum(x['字节数'] for x in results),'manifest',len(rows),'duplicate entries',sum(counts[r['SHA256']]>1 for r in rows))
