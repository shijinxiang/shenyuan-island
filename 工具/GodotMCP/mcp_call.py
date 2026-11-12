"""Call the configured Godot AI MCP stdio bridge; writes evidence locally."""
import asyncio,json,os,sys,tomllib,base64,inspect
import importlib.util
import importlib.metadata
from pathlib import Path
from datetime import timedelta
from mcp import ClientSession,StdioServerParameters
from mcp.client.stdio import stdio_client
ROOT=Path(__file__).resolve().parent
OUTPUT=ROOT.parents[1]/"整理记录"/"MCP操作记录"
OUTPUT.mkdir(parents=True,exist_ok=True)
async def main():
 cfg=tomllib.loads((Path(os.environ['USERPROFILE'])/'.codex/config.toml').read_text(encoding='utf8'))['mcp_servers']['godot-ai']
 command = cfg['command']
 arguments = cfg['args']
 expected_package = next((arg for arg in arguments if arg.startswith('godot-ai==')), '')
 if importlib.util.find_spec('godot_ai') and expected_package == 'godot-ai==' + importlib.metadata.version('godot-ai'):
  command = sys.executable
  arguments = ['-m', 'godot_ai', *arguments[arguments.index('attach'):]]
 params=StdioServerParameters(command=command,args=arguments,env={**os.environ,**cfg.get('env',{})})
 async with stdio_client(params) as (read,write):
  async with ClientSession(read,write,read_timeout_seconds=360.0 if "float" in str(inspect.signature(ClientSession).parameters["read_timeout_seconds"].annotation) else timedelta(seconds=360)) as session:
   init=await session.initialize()
   if len(sys.argv)>2 and sys.argv[1]=='--sequence':
    jobs=json.loads(Path(sys.argv[2]).read_text(encoding='utf-8-sig'))
    for i,job in enumerate(jobs):
     result=await session.call_tool(job['tool'],job.get('args',{}));data=result.model_dump(mode='json',by_alias=True)
     for ci,c in enumerate(data.get('content',[])):
      if c.get('type')=='image':
       filename=Path(job.get('output_name',job['tool']+f'_{ci}.png')).name
       image_path=OUTPUT/'截图'/filename;image_path.parent.mkdir(exist_ok=True)
       image_path.write_bytes(base64.b64decode(c.pop('data')));c['saved_image']=str(image_path)
     (OUTPUT/(f'sequence_{i}_'+job['tool']+'_result.json')).write_text(json.dumps(data,ensure_ascii=False,indent=2),encoding='utf8')
     print(json.dumps({'tool':job['tool'],'isError':data.get('isError'),'result':data.get('structuredContent') or data.get('content')},ensure_ascii=True),flush=True)
     if data.get('isError'):raise RuntimeError(job['tool']+' failed')
    return
   if len(sys.argv)<2 or sys.argv[1]=='--list':
    result=await session.list_tools();data=result.model_dump(mode='json',by_alias=True);(ROOT/'mcp_tools.json').write_text(json.dumps(data,ensure_ascii=False,indent=2),encoding='utf8')
    print(json.dumps({'server':init.model_dump(mode='json',by_alias=True).get('serverInfo'),'tools':[t.name for t in result.tools]},ensure_ascii=True));return
   name=sys.argv[1];args=json.loads(Path(sys.argv[2]).read_text(encoding='utf-8-sig')) if len(sys.argv)>2 else {}
   result=await session.call_tool(name,args);data=result.model_dump(mode='json',by_alias=True)
   for i,c in enumerate(data.get('content',[])):
    if c.get('type')=='image':
     p=OUTPUT/(name+f'_{i}.png');p.write_bytes(base64.b64decode(c.pop('data')));c['saved_image']=str(p)
   (OUTPUT/(name+'_result.json')).write_text(json.dumps(data,ensure_ascii=False,indent=2),encoding='utf8')
   print(json.dumps(data,ensure_ascii=True))
   if data.get('isError'):raise RuntimeError('MCP tool returned error')
asyncio.run(main())
