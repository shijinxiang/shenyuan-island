from pathlib import Path
import zipfile,json,subprocess
P=Path(r'D:\浪费GPT额度\小温的游戏')
D=Path(r'D:\浪费GPT额度\深渊岛_交付_2026-11-07')
F=D/'深渊岛_全部资源与可编辑工程.zip'
T=D/'_打包工作/可编辑工程迁移核验'
T.mkdir(parents=True,exist_ok=True)
prefix='深渊岛_完整可编辑工程/'
with zipfile.ZipFile(F) as z:
    for n in z.namelist():
        if not n.startswith(prefix):continue
        r=n[len(prefix):]
        if r.startswith('游戏/') or (r.startswith('工具/Godot_4.7.2/') and r.endswith('.exe') and '/export_templates/' not in r) or r in ['打开Godot编辑器.cmd','运行游戏.cmd']:
            target=T/r;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(z.read(n))
    settings=z.read(prefix+'游戏/project.godot').decode('utf-8-sig')
    assert '_mcp_game_helper=' not in settings and 'enabled=PackedStringArray()' in settings
    assert 'config/use_custom_user_dir=true' in settings
    assert z.read(prefix+'工具/打包发布/一键导出Windows.ps1').startswith(b'\xef\xbb\xbf')
    assert not any('/.godot/' in n for n in z.namelist())
print('source extracted without caches, MCP disabled',flush=True)
exe=T/'工具/Godot_4.7.2/Godot_v4.7.2-stable_win64_console.exe'
log=P/'整理记录/2026-11-07_打包发布/迁移工程首次导入.log'
console=P/'整理记录/2026-11-07_打包发布/迁移导入控制台.log'
with console.open('w',encoding='utf-8') as out:
    p=subprocess.run([str(exe),'--headless','--path',str(T/'游戏'),'--import','--log-file',str(log)],stdout=out,stderr=subprocess.STDOUT)
text=log.read_text(encoding='utf-8-sig')
errors=[x for x in text.splitlines() if x.startswith(('ERROR:','SCRIPT ERROR:'))]
result={'source_zip':F.name,'relocated_project':str(T),'initial_cache_present':False,'exit_code':p.returncode,'errors':errors,'passed':p.returncode==0 and not errors}
(P/'整理记录/2026-11-07_打包发布/迁移工程核验.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps(result,ensure_ascii=False,indent=2),flush=True)
if not result['passed']:raise SystemExit(1)
