from pathlib import Path
import csv,json,os
ROOT=Path(__file__).resolve().parents[2]
rows=[]
for folder,dirs,files in os.walk(ROOT,followlinks=False):
    dirs[:]=[name for name in dirs if not os.path.islink(Path(folder)/name) and not (hasattr(os.path,'isjunction') and os.path.isjunction(Path(folder)/name))]
    for name in files:
        path=Path(folder)/name
        rows.append({'path':path.relative_to(ROOT).as_posix(),'size':path.stat().st_size})
report=ROOT/'整理记录/运行诊断'
report.mkdir(parents=True,exist_ok=True)
(report/'当前文件清单.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2),encoding='utf8')
with (ROOT/'素材/模型清单.csv').open('w',encoding='utf-8-sig',newline='') as stream:
    writer=csv.writer(stream);writer.writerow(['用途','名称','当前相对路径','大小_MiB'])
    for row in sorted(rows,key=lambda value:value['path']):
        path=row['path']
        if '/.godot/' in path or Path(path).suffix.lower() not in ['.blend','.glb','.fbx','.gltf']:continue
        if path.startswith('游戏/assets/'):purpose='Godot资源及动态加载资源组'
        elif path.startswith('素材/06_'):purpose='当前制作工程与导出'
        elif path.startswith('素材/07_'):purpose='动作源文件'
        elif path.startswith('素材/'):purpose='基础模型源文件'
        else:continue
        writer.writerow([purpose,Path(path).name,path,round(row['size']/1048576,3)])
print(json.dumps({'files':len(rows),'total_bytes':sum(row['size'] for row in rows)},ensure_ascii=False))
