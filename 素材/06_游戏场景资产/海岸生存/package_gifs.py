from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
src=Path(__file__).resolve().parent
for name,ms in [('Crawl',1200),('Swim',1600),('Attack',900)]:
    frames=[]
    files=sorted((src/'animation_frames'/name).glob('*.png'))
    for i,file in enumerate(files):
        image=Image.open(file).convert('RGB')
        draw=ImageDraw.Draw(image)
        draw.rounded_rectangle((10,10,280,52),radius=7,fill=(34,39,40))
        draw.text((20,17),f'{name} | actual rig animation',fill=(235,234,219))
        draw.text((20,33),f'{i*ms/len(files)/1000:.2f}s / {ms/1000:.2f}s | +Z forward',fill=(190,202,185))
        frames.append(image.quantize(colors=128))
    durations=[round((i+1)*ms/len(frames)/10)*10-round(i*ms/len(frames)/10)*10 for i in range(len(frames))]
    if name=='Attack':frames.append(frames[-1].copy());durations.append(600)
    frames[0].save(src/(name+'_actual.gif'),save_all=True,append_images=frames[1:],duration=durations,loop=0,optimize=False,disposal=2)
    print(name,len(frames),sum(durations))
