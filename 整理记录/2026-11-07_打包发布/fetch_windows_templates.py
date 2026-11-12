from pathlib import Path
import io,urllib.request,zipfile,struct,zlib,concurrent.futures,hashlib,json,time

ROOT=Path(r'D:\浪费GPT额度\小温的游戏')
DEST=ROOT/'工具/Godot_4.7.2/export_templates/4.7.2.stable'
DEST.mkdir(parents=True,exist_ok=True)
URL='https://github.com/godotengine/godot-builds/releases/download/4.7.2-stable/Godot_v4.7.2-stable_export_templates.tpz'
TOTAL=1281349702
def fetch(a,b):
    for attempt in range(4):
        try:
            req=urllib.request.Request(URL,headers={'Range':f'bytes={a}-{b}','User-Agent':'ShenyuanIsland-packager'})
            with urllib.request.urlopen(req,timeout=90) as r:
                if r.status!=206:raise RuntimeError(f'range request returned {r.status}')
                data=r.read()
            if len(data)!=b-a+1:raise RuntimeError('range size mismatch')
            return data
        except Exception:
            if attempt==3:raise
            time.sleep(attempt+1)
class Remote(io.RawIOBase):
    def __init__(self):self.pos=0
    def seekable(self):return True
    def readable(self):return True
    def tell(self):return self.pos
    def seek(self,n,whence=0):
        self.pos=n if whence==0 else self.pos+n if whence==1 else TOTAL+n
        return self.pos
    def read(self,n=-1):
        if n<0:n=TOTAL-self.pos
        n=min(n,TOTAL-self.pos)
        if n<=0:return b''
        result=fetch(self.pos,self.pos+n-1);self.pos+=n;return result

with zipfile.ZipFile(Remote()) as z:
    entries=z.infolist()
    (DEST/'官方模板目录.txt').write_text('\n'.join(f'{i.filename}\t{i.file_size}' for i in entries),encoding='utf-8')
    chosen=[i for i in entries if 'windows' in i.filename.lower() and ('x86_64' in i.filename.lower() or i.filename.lower().endswith('.dll'))]
    print('chosen',[(i.filename,i.file_size,i.compress_size) for i in chosen],flush=True)
    records=[]
    for i in chosen:
        target=DEST/Path(i.filename).name
        if target.exists() and target.stat().st_size==i.file_size:
            existing=target.read_bytes()
            if zlib.crc32(existing)&0xffffffff==i.CRC:
                records.append({'file':target.name,'bytes':len(existing),'crc32':f'{i.CRC:08x}','sha256':hashlib.sha256(existing).hexdigest()});continue
        hdr=fetch(i.header_offset,i.header_offset+29)
        name_len,extra_len=struct.unpack_from('<HH',hdr,26)
        start=i.header_offset+30+name_len+extra_len
        chunks=[(a,min(a+4*1024*1024,start+i.compress_size)-1) for a in range(start,start+i.compress_size,4*1024*1024)]
        print('downloading',i.filename,'chunks',len(chunks),flush=True)
        with concurrent.futures.ThreadPoolExecutor(max_workers=8) as pool:
            packed=b''.join(pool.map(lambda p:fetch(*p),chunks))
        data=zlib.decompress(packed,-15) if i.compress_type==8 else packed
        assert len(data)==i.file_size and zlib.crc32(data)&0xffffffff==i.CRC
        target.write_bytes(data)
        record={'file':target.name,'bytes':len(data),'crc32':f'{i.CRC:08x}','sha256':hashlib.sha256(data).hexdigest()};records.append(record)
        print('saved',target.name,len(data),flush=True)
    version=next(x for x in entries if x.filename.endswith('/version.txt'))
    # version is a small ZIP member
    z.extract(version,DEST/'_metadata')
    (DEST/'version.txt').write_bytes((DEST/'_metadata'/version.filename).read_bytes())
(DEST/'模板来源与校验.json').write_text(json.dumps({'url':URL,'official_archive_sha256':'f298490b8d44d934be425a5a65a51bf15f422428b229a06a6e11d9ffea248011','download_method':'HTTP range only Windows members; member CRC32 verified against official ZIP central directory','files':records},ensure_ascii=False,indent=2),encoding='utf-8')
print('DONE',flush=True)
