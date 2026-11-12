from pathlib import Path
import json, zipfile
from PIL import Image, ImageDraw, ImageFont
from docx import Document

ROOT=Path(r'D:\浪费GPT额度\小温的游戏')
WORK=ROOT/'整理记录/开发文档编制_2026-11-07'
IMG=WORK/'证据图片'
IMG.mkdir(exist_ok=True)
font=ImageFont.truetype(r'C:\Windows\Fonts\msyh.ttc',18)
sources=[]
for i,p in enumerate(sorted((ROOT/'资料/制作流程').glob('*.png')),1):
    im=Image.open(p)
    sources.append({'id':f'P{i:02}', 'name':p.name,'path':str(p),'size':im.size,'kind':'制作流程截图'})

archive=ROOT/'归档/03_制作过程脚本与数据.zip'
select=['实时模型背包.png','商人首次交谈.png','序章漂流.png','斜俯视修复.png','展开藏宝卷轴.png','闻舟对话框.png','进入小屋.png','脚边扑腾的鱼.png','第三人称划船.png','加长船桨.png','持竿走动.png']
with zipfile.ZipFile(archive) as z:
    for name in select:
        hits=[n for n in z.namelist() if n.endswith('/'+name)]
        if hits:
            n=hits[0]; p=IMG/name; p.write_bytes(z.read(n))
            sources.append({'id':f'A{len([s for s in sources if s["kind"]=="归档实机截图"])+1:02}', 'name':name,'path':str(p),'size':Image.open(p).size,'kind':'归档实机截图','archive_entry':n})
    reports=[n for n in z.namelist() if n.endswith('.json') and any(x in n for x in ['检查结果','运行检查','修复运行结果','散布核验','运行结果','统计','性能'])]
    records=[]
    for n in reports:
        if z.getinfo(n).file_size<80000:
            try: records.append({'entry':n,'data':json.loads(z.read(n).decode('utf-8-sig'))})
            except Exception: pass
    (WORK/'归档核验摘录.json').write_text(json.dumps(records,ensure_ascii=False,indent=2),encoding='utf-8')
    (WORK/'归档文件目录.txt').write_text('\n'.join(z.namelist()),encoding='utf-8')

(WORK/'图片索引.json').write_text(json.dumps(sources,ensure_ascii=False,indent=2),encoding='utf-8')
for start in range(0,len(sources),8):
    group=sources[start:start+8]
    sheet=Image.new('RGB',(1600,1160),'#eeeeee'); d=ImageDraw.Draw(sheet)
    for j,s in enumerate(group):
        im=Image.open(s['path']).convert('RGB'); im.thumbnail((760,225))
        x=(j%2)*800+20; y=(j//2)*290+10
        sheet.paste(im,(x+(760-im.width)//2,y))
        title=f"{s['id']} {s['name']}"
        for k in range(0,len(title),37): d.text((x,y+230+(k//37)*24),title[k:k+37],font=font,fill='black')
    sheet.save(WORK/f'contact_{start//8+1}.jpg',quality=90)

doc=Document(ROOT/'需求/深渊岛_游戏需求规格说明书_v1.0.docx')
(WORK/'初版需求文字.txt').write_text('\n'.join(p.text for p in doc.paragraphs)+'\n'+'\n'.join(' | '.join(c.text for c in r.cells) for t in doc.tables for r in t.rows),encoding='utf-8')
print(json.dumps(sources,ensure_ascii=False,indent=1))
print('reports',len(records))
