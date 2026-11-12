from pathlib import Path
import urllib.request,concurrent.futures,time,hashlib
URL='https://raw.githubusercontent.com/notofonts/noto-cjk/main/Sans/SubsetOTF/SC/NotoSansSC-Regular.otf'
TOTAL=8331336
def get(part):
    a,b=part
    for trial in range(5):
        try:
            req=urllib.request.Request(URL,headers={'Range':f'bytes={a}-{b}','User-Agent':'ShenyuanIsland'})
            with urllib.request.urlopen(req,timeout=90) as r:
                if r.status!=206:raise RuntimeError(f'expected 206 got {r.status}')
                data=r.read()
            assert len(data)==b-a+1
            print('font',a,b,flush=True)
            return data
        except Exception:
            if trial==4:raise
            time.sleep(1)
parts=[(a,min(a+512*1024,TOTAL)-1) for a in range(0,TOTAL,512*1024)]
with concurrent.futures.ThreadPoolExecutor(max_workers=8) as pool:data=b''.join(pool.map(get,parts))
assert len(data)==TOTAL and data[:4]==b'OTTO'
p=Path(r'D:\浪费GPT额度\小温的游戏\游戏\assets\fonts\NotoSansSC-Regular.otf')
p.write_bytes(data)
print('FONT_DONE',len(data),hashlib.sha256(data).hexdigest(),flush=True)
