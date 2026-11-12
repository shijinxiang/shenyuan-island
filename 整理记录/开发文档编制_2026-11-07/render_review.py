from pathlib import Path
import importlib.util,json,re
from PIL import Image,ImageDraw,ImageFont
import pypdfium2 as pdfium

W=Path(__file__).parent
canonical=Path(r'C:\Users\SHIJINXIANG\.codex\plugins\cache\openai-primary-runtime\documents\26.1103.10131\skills\documents\render_docx.py')
spec=importlib.util.spec_from_file_location('canonical_render',canonical)
renderer=importlib.util.module_from_spec(spec);spec.loader.exec_module(renderer)
reports=json.loads((W/'Word导出记录.json').read_text(encoding='utf-8-sig'))
all_records=[]
for report in reports:
    pdf=Path(report['PDF']);out=pdf.parent/'页面';out.mkdir(exist_ok=True)
    # Windows无LibreOffice 仅替换转换阶段 仍用技能的标准PDF光栅化流程
    renderer.convert_to_pdf=lambda *a, _pdf=str(pdf), **kw: (_pdf,'Microsoft Word COM fallback')
    pages=renderer.rasterize(str(pdf),str(out),130,False,False)
    doc=pdfium.PdfDocument(str(pdf));pageinfo=[]
    for n,page in enumerate(doc):
        tp=page.get_textpage();txt=tp.get_text_range();pageinfo.append({'page':n+1,'chars':len(txt),'text':txt})
        tp.close();page.close()
    doc.close()
    (pdf.parent/'页面文字.json').write_text(json.dumps(pageinfo,ensure_ascii=False,indent=2),encoding='utf-8')
    f=ImageFont.truetype(r'C:\Windows\Fonts\msyh.ttc',18)
    for start in range(0,len(pages),8):
        sheet=Image.new('RGB',(1600,1110),'#dce2e4');d=ImageDraw.Draw(sheet)
        for j,p in enumerate(pages[start:start+8]):
            im=Image.open(p).convert('RGB');im.thumbnail((380,495))
            x=(j%4)*400+10;y=(j//4)*555+10;sheet.paste(im,(x,y))
            d.text((x,y+505),f'第{start+j+1}页',font=f,fill='black')
        sheet.save(pdf.parent/f'总览-{start//8+1}.jpg',quality=91)
    all_records.append({'doc':report['Name'],'pages':len(pages),'sparse_pages':[p['page'] for p in pageinfo if p['chars']<100],'pdf':str(pdf)})
(W/'页面检查清单.json').write_text(json.dumps(all_records,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps(all_records,ensure_ascii=False,indent=2))
