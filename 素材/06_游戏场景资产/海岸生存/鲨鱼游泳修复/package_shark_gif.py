from PIL import Image,ImageDraw
from pathlib import Path
import json
p=Path(__file__).resolve().parent
report=json.loads((p/'shark_skin_animation_analysis.json').read_text())
files=sorted((p/'frames').glob('*.png'));frames=[];total=round(report['duration_seconds']*1000)
for i,path in enumerate(files):
    im=Image.open(path).convert('RGB');d=ImageDraw.Draw(im);d.rounded_rectangle((8,8,370,44),radius=5,fill=(28,40,46));d.text((16,15),'Original Shark | ArmatureAction | actual skin deformation',fill=(235,242,244));d.text((16,29),f'{i*total/len(files)/1000:.2f}s / 4.167s | no model changes',fill=(190,218,228));frames.append(im.quantize(colors=128))
durations=[round((i+1)*total/len(files)/10)*10-round(i*total/len(files)/10)*10 for i in range(len(files))]
frames[0].save(p/'Shark_原骨骼游泳_actual.gif',save_all=True,append_images=frames[1:],duration=durations,loop=0,optimize=False,disposal=2)
sheet=Image.new('RGB',(1280,720),(28,40,46))
for j,i in enumerate([0,18,36,54]):sheet.paste(Image.open(files[i]),((j%2)*640,(j//2)*360))
sheet.save(p/'Shark_四阶段摆尾验证.png')
print('SHARK_GIF_SAVED',len(frames),sum(durations))
