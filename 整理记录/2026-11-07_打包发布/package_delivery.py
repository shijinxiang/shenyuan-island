from pathlib import Path
import os,sys,json,zipfile,hashlib,csv,io,re,time

PROJECT=Path(r'D:\浪费GPT额度\小温的游戏')
DELIVERY=Path(r'D:\浪费GPT额度\深渊岛_交付_2026-11-07')
RECORD=PROJECT/'整理记录/2026-11-07_打包发布'
UTF8='utf-8'
def portable_settings(s):
    s=re.sub(r'(?m)^_mcp_game_helper=.*\r?\n','',s)
    s=re.sub(r'(?m)^enabled=PackedStringArray\([^\r\n]*\)','enabled=PackedStringArray()',s)
    if 'config/use_custom_user_dir=' not in s:
        s=s.replace('config/name="深渊岛"','config/name="深渊岛"\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="ShenyuanIsland"')
    return s

def launcher(editor=False):
    return ('@echo off\r\nchcp 65001 >nul\r\ncd /d "%~dp0"\r\nstart "" "%~dp0工具\\Godot_4.7.2\\Godot_v4.7.2-stable_win64.exe" '+('--editor ' if editor else '')+'--path "%~dp0游戏"\r\n').encode(UTF8)

def skip(rel):
    p=rel.parts
    if any(x in {'.godot','__pycache__','.git','.godot_ai_update','_build','发布'} for x in p):return True
    if rel.name.startswith('~$') or rel.suffix.lower() in {'.pyc','.tmp','.dmp'}:return True
    if rel.name in {'.env','export_credentials.cfg','Thumbs.db','.DS_Store'} or rel.name.startswith('.env.'):return True
    if rel.suffix.lower() in {'.pfx','.pem','.key'}:return True
    if str(rel).replace('\\','/').startswith('整理记录/2026-11-07_打包发布/') and rel.name in {'打包结果.json','来源文件快照.json','打包进度.txt'}:return True
    return False

ALREADY_COMPRESSED={'.zip','.7z','.rar','.tpz','.png','.jpg','.jpeg','.mp4','.pdf','.docx','.xlsx','.webp','.ogg'}
def write_package(target,top,files,overrides=None):
    overrides=overrides or {}
    seen=set();manifest=[];last=time.monotonic()
    with zipfile.ZipFile(target,'w',allowZip64=True,compression=zipfile.ZIP_DEFLATED,compresslevel=1) as z:
        all_entries=[(str(rel).replace('\\','/'),p) for rel,p in files]
        for rel,_ in all_entries:seen.add(rel)
        all_entries += [(rel,None) for rel in overrides if rel not in seen]
        total=len(all_entries)
        for index,(rel,path) in enumerate(all_entries,1):
            digest=hashlib.sha256();count=0
            info=zipfile.ZipInfo(top+'/'+rel)
            info.flag_bits|=0x800
            if path:
                stamp=time.localtime(path.stat().st_mtime)[:6];info.date_time=stamp
                info.file_size=path.stat().st_size
            info.compress_type=zipfile.ZIP_STORED if Path(rel).suffix.lower() in ALREADY_COMPRESSED else zipfile.ZIP_DEFLATED
            info._compresslevel=1
            if rel in overrides:
                data=overrides[rel];digest.update(data);count=len(data);z.writestr(info,data)
            else:
                with path.open('rb') as source,z.open(info,'w',force_zip64=True) as dest:
                    while data:=source.read(4*1024*1024):digest.update(data);count+=len(data);dest.write(data)
            manifest.append({'path':rel,'bytes':count,'sha256':digest.hexdigest(),'package_override':rel in overrides})
            if time.monotonic()-last>10:
                print(target.name,index,'/',total,'written',sum(x['bytes'] for x in manifest)//1048576,'MiB',flush=True);last=time.monotonic()
        text=io.StringIO();writer=csv.writer(text);writer.writerow(['相对路径','字节','SHA256','交付版配置调整'])
        for m in manifest:writer.writerow([m['path'],m['bytes'],m['sha256'],'是' if m['package_override'] else ''])
        z.writestr(top+'/文件清单_SHA256.csv','\ufeff'+text.getvalue())
    # 一次完整性检查 读回ZIP所有成员并核对CRC
    print('checking CRC',target.name,flush=True)
    with zipfile.ZipFile(target) as z:
        problem=z.testzip()
        if problem:raise RuntimeError('ZIP CRC failed '+problem)
    h=hashlib.sha256()
    with target.open('rb') as f:
        while b:=f.read(8*1024*1024):h.update(b)
    return {'file':target.name,'bytes':target.stat().st_size,'uncompressed_bytes':sum(x['bytes'] for x in manifest),'files':len(manifest),'sha256':h.hexdigest(),'zip_crc_verified':True,'manifest':manifest}

def main():
    mode=sys.argv[1] if len(sys.argv)>1 else 'all'
    results=[]
    if mode in ('all','game'):
        folder=DELIVERY/'Windows独立游戏'
        files=[(p.relative_to(folder),p) for p in sorted(folder.rglob('*')) if p.is_file() and p.name!='.gdignore']
        assert (folder/'ShenyuanIsland.exe').stat().st_size>1000000
        assert (folder/'ShenyuanIsland.pck').stat().st_size>1000000
        results.append(write_package(DELIVERY/'深渊岛_Windows独立游戏.zip','深渊岛_Windows独立游戏',files))
    if mode in ('all','source'):
        files=[];excluded=[]
        for p in sorted(PROJECT.rglob('*')):
            if not p.is_file():continue
            rel=p.relative_to(PROJECT)
            if skip(rel):excluded.append(str(rel));continue
            files.append((rel,p))
        overrides={
            '游戏/project.godot':portable_settings((PROJECT/'游戏/project.godot').read_text(encoding='utf-8-sig')).encode(UTF8),
            '运行游戏.cmd':launcher(False),
            '打开Godot编辑器.cmd':launcher(True),
            '00_从这里开始.txt':(PROJECT/'协作与交付说明.txt').read_bytes(),
        }
        results.append(write_package(DELIVERY/'深渊岛_全部资源与可编辑工程.zip','深渊岛_完整可编辑工程',files,overrides))
        (RECORD/'排除的可重建文件.txt').write_text('\n'.join(excluded),encoding=UTF8)
    result_path=RECORD/'打包结果.json'
    old=json.loads(result_path.read_text(encoding=UTF8)) if result_path.exists() else []
    for r in results:
        old=[x for x in old if x['file']!=r['file']]+[r]
    result_path.write_text(json.dumps(old,ensure_ascii=False,indent=2),encoding=UTF8)
    (DELIVERY/'SHA256校验.txt').write_text('\n'.join(r['sha256']+'  '+r['file'] for r in old)+'\n',encoding=UTF8)
    print(json.dumps([{k:v for k,v in r.items() if k!='manifest'} for r in results],ensure_ascii=False,indent=2),flush=True)

if __name__=='__main__':main()
