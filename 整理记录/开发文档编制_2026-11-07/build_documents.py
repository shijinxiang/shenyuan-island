from pathlib import Path
import re,json,math
from PIL import Image,ImageDraw,ImageFont
from docx import Document
from docx.shared import Inches,Pt,RGBColor
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.enum.table import WD_TABLE_ALIGNMENT,WD_CELL_VERTICAL_ALIGNMENT
from docx.oxml import OxmlElement
from docx.oxml.ns import qn

W=Path(__file__).parent
ROOT=W.parent.parent
OUT=ROOT/'需求/开发过程文档'
SOURCES={x['id']:x for x in json.loads((W/'图片索引.json').read_text(encoding='utf-8'))}
FLOWS={
'overall':('开发流程与反馈循环',[
('需求和视觉目标','确定环形海岛与首次游玩内容'),('资产拆分和参考','母图 视图 组件 预算'),('建模与资源筛选','Blender 生成模型 免费素材'),('Godot局部样板','码头 沙滩 小屋 比例与碰撞'),('动态世界与玩法','水体 天气 生物 动作 交互'),('反馈修复与交付','问题复现 版本替换 工程归档')],'后续画面和运行问题会返回前一阶段修改'),
'water':('海浪从输入到画面的处理',[
('地形与障碍输入','海床高度 码头立柱 岸线'),('风向与边界强迫','外海统一主方向 内湖弱浪'),('浅水数值推进','全局域与局部域更新水位和流动'),('接岸与耗散','浅水破碎 接触障碍 生成泡沫'),('水面渲染','位移 法线 深度颜色 短寿命白沫'),('角色与船采样','水面高度 浮动 游泳状态')],'这是游戏浅水近似 渲染特效与数值求解分层'),
'ecology':('生物更新与交互关系',[
('资源与栖息地','鱼种 朝向 动作 湖或海 水深'),('群游和独游','凝聚 对齐 分离与个体扰动'),('环境避让','海床 石块 玩家与活动边界'),('身体动画','尾鳍 鸟翼 跳步与觅食'),('交互行为','接近逃飞 钓鱼吸引 徒手捕捉'),('危险行为','鲨鱼访问浅海 追击与受击')],'群体位置与身体动作一起更新'),
'states':('人物在陆地水面与钓鱼之间转换',[
('陆地或浅岸站立','海床仍可站 短时波峰不切状态'),('持续深水判断','水深滤波 进入阈值与持续时间'),('清理钓鱼并找安全位','释放鱼目标 检查游泳胶囊'),('深水游泳或踩水','Floating运动模式 保留移动意图'),('浅水站立判断','退出阈值 持续时间 空间检测'),('恢复陆地控制','站立胶囊 Walk 视觉高度渐变')],'进入与退出采用不同阈值 防止浪峰反复切换'),
'gameplay':('当前原型的生活循环',[
('苏醒和进屋','找到鱼竿 阅读岑安来信'),('探索与捕鱼','岸钓 游泳徒手捕捉或划船'),('收取实物渔获','鱼落脚边扑腾 按E拾取'),('整理模型背包','查看鱼种 重量和获得物品'),('清晨找闻舟','交换种子 鱼叉与船只升级'),('扩展岛上生活','简单种植 更远航行 更多鱼获')],'昼夜天气与时间倍率贯穿循环'),
'team':('三人责任与交接',[
('组员二确定用途','玩法规则 动线 生态区 交互条件'),('组员一准备资源','参考 组件 模型 材质 骨骼动作'),('交接资产与说明','编号 尺寸 朝向 挂点 导出文件'),('组员三运行接入','Godot场景 碰撞 shader 行为UI'),('共同观察反馈','对照需求 复现问题 判断原因'),('各自修复和归档','内容规则 模型结构或接入逻辑')],'按问题原因回到相应负责人 不只交一张效果图'),
'fishing':('钓鱼流程和退出条件',[
('持竿与选水面','F准备 鼠标选择有效落点'),('抛竿和等待','鱼线随竿梢 关联水域目标鱼'),('咬钩与提竿','在窗口内响应 进入收线'),('收线和移动','控制张力 上身持竿 下肢可动'),('鱼实体落脚边','拉出水面 甩落 翻身扑腾'),('拾取和保存','E拾取 背包模型预览 原子存档')],'取消 入深水或死亡时释放鱼目标与临时状态'),
}

def font(sz,bold=False):return ImageFont.truetype(r'C:\Windows\Fonts\msyhbd.ttc' if bold else r'C:\Windows\Fonts\msyh.ttc',sz)
def wrap(draw,text,f,width):
    lines=[];line=''
    for c in text:
        if draw.textlength(line+c,font=f)>width:
            lines.append(line);line=c
        else:line+=c
    if line:lines.append(line)
    return lines
def flow_image(key):
    title,nodes,note=FLOWS[key]
    im=Image.new('RGB',(1800,850),'white'); d=ImageDraw.Draw(im)
    d.text((52,30),title,font=font(43,True),fill='black')
    coords=[(50+600*i,145) for i in range(3)]+[(1250-600*i,460) for i in range(3)]
    for i,((head,body),(x,y)) in enumerate(zip(nodes,coords)):
        d.rounded_rectangle((x,y,x+500,y+210),radius=12,fill='#f2f6f4',outline='#628678',width=3)
        d.text((x+24,y+18),f'{i+1}',font=font(32,True),fill='#32665c')
        for j,line in enumerate(wrap(d,head,font(31,True),420)):d.text((x+62,y+19+42*j),line,font=font(31,True),fill='black')
        for j,line in enumerate(wrap(d,body,font(26),445)):d.text((x+24,y+100+38*j),line,font=font(26),fill='#30453e')
    for i in range(5):
        x,y=coords[i]; xx,yy=coords[i+1]
        if y==yy:
            a=(x+515,y+105) if xx>x else (x-15,y+105)
            b=(xx-16,yy+105) if xx>x else (xx+516,yy+105)
        else:a=(x+250,y+225);b=(xx+250,yy-20)
        d.line((a,b),fill='#426c60',width=5)
        angle=math.atan2(b[1]-a[1],b[0]-a[0]);l=18
        d.polygon([b,(b[0]-l*math.cos(angle-.5),b[1]-l*math.sin(angle-.5)),(b[0]-l*math.cos(angle+.5),b[1]-l*math.sin(angle+.5))],fill='#426c60')
    d.text((52,755),note,font=font(28),fill='#40554d')
    p=W/'证据图片'/f'流程图_{key}.png';im.save(p);return p

def set_font(style,name,size,bold=None,color='000000'):
    style.font.name=name;style.font.size=Pt(size);style.font.color.rgb=RGBColor.from_string(color)
    if bold is not None:style.font.bold=bold
    el=style.element.get_or_add_rPr();rf=el.rFonts
    if rf is None:rf=OxmlElement('w:rFonts');el.insert(0,rf)
    for k in ['eastAsia','ascii','hAnsi']:rf.set(qn('w:'+k),name)
    for k in ['asciiTheme','hAnsiTheme','eastAsiaTheme','cstheme']:rf.attrib.pop(qn('w:'+k),None)
    for node in list(el):
        if node.tag==qn('w:color'):
            for key in ['themeColor','themeTint','themeShade']:node.attrib.pop(qn('w:'+key),None)

def setup(title):
    d=Document();sec=d.sections[0]
    for border in list(d.styles.element.xpath('.//w:pBdr')):border.getparent().remove(border)
    sec.page_width=Inches(8.5);sec.page_height=Inches(11)
    sec.top_margin=Inches(.72);sec.bottom_margin=Inches(.7);sec.left_margin=Inches(.85);sec.right_margin=Inches(.85)
    sec.header_distance=Inches(.3);sec.footer_distance=Inches(.3)
    normal=d.styles['Normal'];set_font(normal,'宋体',11.5)
    normal.paragraph_format.line_spacing=1.3;normal.paragraph_format.space_after=Pt(6)
    normal.paragraph_format.first_line_indent=Pt(23)
    normal.paragraph_format.widow_control=True
    for name,sz in [('Title',27),('Subtitle',14),('Heading 1',17),('Heading 2',13.5),('Heading 3',12)]:
        s=d.styles[name];set_font(s,'微软雅黑',sz,True if name!='Subtitle' else False)
        s.font.italic=False
        s.paragraph_format.first_line_indent=Pt(0)
        s.paragraph_format.space_before=Pt(15 if name.startswith('Heading') else 0)
        s.paragraph_format.space_after=Pt(8)
        s.paragraph_format.keep_with_next=name.startswith('Heading')
    for name in ['Caption','Header','Footer']:
        set_font(d.styles[name],'宋体',9)
        d.styles[name].paragraph_format.first_line_indent=Pt(0)
    d.styles['Caption'].paragraph_format.space_after=Pt(8)
    header=sec.header.paragraphs[0];header.text='深渊岛  开发记录' if '完整' in title else '深渊岛  三人分工'
    header.alignment=WD_ALIGN_PARAGRAPH.RIGHT
    footer=sec.footer.paragraphs[0];footer.alignment=WD_ALIGN_PARAGRAPH.CENTER
    footer.add_run('第 ');fld=OxmlElement('w:fldSimple');fld.set(qn('w:instr'),'PAGE');footer._p.append(fld)
    footer.add_run(' 页')
    d.core_properties.title=title;d.core_properties.subject='深渊岛游戏开发过程';d.core_properties.author='小温的游戏项目'
    update=OxmlElement('w:updateFields');update.set(qn('w:val'),'true');d.settings.element.append(update)
    return d

def figure(d,path,caption,number,source=None,diagram=False):
    im=Image.open(path);w,h=im.size
    maxw=6.65;maxh=3.45 if w>=h else 4.4
    width=min(maxw,maxh*w/h)
    p=d.add_paragraph();p.alignment=WD_ALIGN_PARAGRAPH.CENTER;p.paragraph_format.first_line_indent=Pt(0)
    p.paragraph_format.space_before=Pt(5);p.paragraph_format.space_after=Pt(4);p.paragraph_format.keep_with_next=True
    r=p.add_run();r.add_picture(str(path),width=Inches(width))
    pic=r._r.xpath('.//wp:docPr')[0];pic.set('descr',caption)
    c=d.add_paragraph(f'图{number}  {caption}' if number else caption,style='Caption');c.alignment=WD_ALIGN_PARAGRAPH.CENTER
    if source:
        c.add_run('\n原图 '+source).font.size=Pt(8)
    return 1

def table(d,rows,compact=False,ratios=None):
    n=len(rows[0]);t=d.add_table(rows=1,cols=n);t.alignment=WD_TABLE_ALIGNMENT.CENTER;t.autofit=False
    ratios=ratios or {2:[.31,.69],3:[.24,.34,.42],4:[.20,.27,.27,.26],5:[.16,.22,.19,.22,.21]}.get(n,[1/n]*n)
    total=6.7
    for col,ratio in zip(t.columns,ratios):col.width=Inches(total*ratio)
    for ri,row in enumerate(rows):
        cells=t.rows[0].cells if ri==0 else t.add_row().cells
        for ci,cell in enumerate(cells):
            cell.width=Inches(total*ratios[ci]);cell.vertical_alignment=WD_CELL_VERTICAL_ALIGNMENT.CENTER
            cell.text=row[ci] if ci<len(row) else ''
            for p in cell.paragraphs:
                p.paragraph_format.first_line_indent=Pt(0);p.paragraph_format.space_after=Pt(1 if compact else 3);p.paragraph_format.space_before=Pt(1 if compact else 3);p.paragraph_format.line_spacing=1.1 if compact else 1.15
                p.paragraph_format.keep_with_next=ri<2
                if ci==0 and len(cell.text)<18:p.alignment=WD_ALIGN_PARAGRAPH.CENTER
                for r in p.runs:
                    r.font.name='宋体';r.font.size=Pt(9.5 if compact else (10 if n>=4 else 10.5));r.font.color.rgb=RGBColor.from_string('FFFFFF' if ri==0 else '000000');r.bold=ri==0
                    r._element.get_or_add_rPr().rFonts.set(qn('w:eastAsia'),'宋体')
            pr=cell._tc.get_or_add_tcPr()
            shade=OxmlElement('w:shd');shade.set(qn('w:fill'),'355B66' if ri==0 else ('F2F5F6' if ri%2==0 else 'FFFFFF'));pr.append(shade)
            borders=OxmlElement('w:tcBorders')
            for edge in ['top','left','bottom','right']:
                b=OxmlElement('w:'+edge);b.set(qn('w:val'),'single');b.set(qn('w:sz'),'5');b.set(qn('w:color'),'D9D9D9');borders.append(b)
            pr.append(borders)
            mar=OxmlElement('w:tcMar')
            for side,val in [('top','30' if compact else '65'),('bottom','30' if compact else '65'),('left','90'),('right','90')]:
                e=OxmlElement('w:'+side);e.set(qn('w:w'),val);e.set(qn('w:type'),'dxa');mar.append(e)
            pr.append(mar)
        trpr=t.rows[ri]._tr.get_or_add_trPr();ns=OxmlElement('w:cantSplit');trpr.append(ns)
        if ri==0:
            repeat=OxmlElement('w:tblHeader');trpr.append(repeat)
    p=d.add_paragraph();p.paragraph_format.space_after=Pt(2);p.paragraph_format.space_before=Pt(0);p.paragraph_format.line_spacing=1;p.add_run().font.size=Pt(2)

def make(source,outname,hero):
    text=source.read_text(encoding='utf-8');lines=text.splitlines();title=lines[0][2:]
    d=setup(title)
    p=d.add_paragraph();p.paragraph_format.space_after=Pt(28)
    p=d.add_paragraph(title,style='Title')
    d.add_paragraph(lines[2],style='Subtitle')
    d.add_paragraph('')
    # 封面使用实机过程图 不能用理想目标图充当成果
    figure(d,SOURCES[hero]['path'],'阶段实机画面',0,diagram=False)
    body_start=next(n for n,s in enumerate(lines) if s.startswith('## '))
    for s in [s for s in lines[4:body_start] if s.strip()]:
        p=d.add_paragraph(s);p.paragraph_format.first_line_indent=Pt(0);p.paragraph_format.space_before=Pt(9)
    p=d.add_paragraph('项目根目录  D:\\浪费GPT额度\\小温的游戏');p.paragraph_format.first_line_indent=Pt(0)
    d.add_page_break()
    i=body_start;figcount=0;tables=0;figlist=[];compact_next=False
    while i<len(lines):
        line=lines[i].strip();i+=1
        if not line:continue
        if line=='[TOC]':
            d.add_page_break();toc_head=d.add_paragraph('目录')
            toc_head.paragraph_format.first_line_indent=Pt(0);toc_head.runs[0].bold=True;toc_head.runs[0].font.size=Pt(17)
            p=d.add_paragraph();p.paragraph_format.first_line_indent=Pt(0)
            fld=OxmlElement('w:fldSimple');fld.set(qn('w:instr'),'TOC \\o "1-2" \\h \\z \\u')
            r=OxmlElement('w:r');tt=OxmlElement('w:t');tt.text='目录更新中';r.append(tt);fld.append(r);p._p.append(fld)
            d.add_page_break();continue
        if line.startswith('[FIG '):
            m=re.fullmatch(r'\[FIG (\w+) (.+)\]',line);key,cap=m.groups();figcount+=1
            s=SOURCES[key];figure(d,s['path'],cap,figcount,s['name']);figlist.append({'number':figcount,'source':key,'caption':cap});continue
        if line.startswith('[FLOW '):
            key=line[6:-1];figcount+=1;path=flow_image(key)
            figure(d,path,FLOWS[key][0],figcount,diagram=True);figlist.append({'number':figcount,'source':'flow_'+key,'caption':FLOWS[key][0]});continue
        if line=='[IMAGE_INDEX]':
            rows=[['编号','原图文件名']]+[[s['id'],s['name']] for s in SOURCES.values() if s['id'].startswith('P')]
            table(d,rows,compact=True,ratios=[.12,.88]);tables+=1;continue
        if line.startswith('|'):
            rows=[]
            while True:
                row=[c.strip() for c in line.strip('|').split('|')]
                if not all(re.fullmatch(r':?-+:?',c) for c in row):rows.append(row)
                if i>=len(lines) or not lines[i].strip().startswith('|'):break
                line=lines[i].strip();i+=1
            table(d,rows,compact=compact_next,ratios=[.22,.43,.35] if compact_next and len(rows[0])==3 else None);tables+=1;compact_next=False;continue
        if line.startswith('#'):
            marks=len(line)-len(line.lstrip('#'));head=line.lstrip('#').strip()
            # 层级编号来自章节结构 小节标题保留纯文字
            if marks>=3:head=re.sub(r'^\d+(?:\.\d+)*\s+','',head)
            if head.startswith(('第一部分','第二部分','第三部分','附录A','附录B')):d.add_page_break()
            if head.startswith('附录 分工与代码定位'):compact_next=True
            d.add_paragraph(head,style=f'Heading {min(marks-1,3)}');continue
        if line.startswith('>'):
            content=line[1:].strip()
            if content:
                p=d.add_paragraph(content);p.paragraph_format.left_indent=Pt(23);p.paragraph_format.right_indent=Pt(15);p.paragraph_format.first_line_indent=Pt(0)
            continue
        d.add_paragraph(line)
    path=OUT/outname;d.save(path)
    report={'file':str(path),'source':source.name,'chars':len(text),'figures':figcount,'tables':tables,'figure_list':figlist}
    return report

reports=[make(W/'完整开发过程.md','深渊岛_完整开发过程.docx','P05'),make(W/'三人分工开发记录.md','深渊岛_三人分工开发文档.docx','A07')]
(W/'编制清单.json').write_text(json.dumps(reports,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps([{k:v for k,v in r.items() if k!='figure_list'} for r in reports],ensure_ascii=False,indent=2))
