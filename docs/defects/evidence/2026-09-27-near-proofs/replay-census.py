import json,pathlib,subprocess,concurrent.futures,hashlib
r=pathlib.Path('/work');out=r/'build/near-proof-recovery/final-census';out.mkdir(exist_ok=True)
rows=json.loads((r/'build/near-proof-recovery/census/report.json').read_text())
tool=r/'build/near-proof-recovery/final/bin'
def run(x):
 cmd=x['after']['command'][:];cmd[0]=str(tool/'clang');o=out/pathlib.Path(cmd[cmd.index('-o')+1]).name;cmd[cmd.index('-o')+1]=str(o)
 try:p=subprocess.run(cmd,capture_output=True,text=True,timeout=120)
 except subprocess.TimeoutExpired:return dict(source=x['source'],mode=x['mode'],matches='error' in x['after'],error='timeout')
 o.with_suffix('.log').write_text(p.stdout+p.stderr)
 data=dict(source=x['source'],mode=x['mode'],exit_code=p.returncode)
 if p.returncode==0:
  dis=subprocess.check_output([str(r/'build/llvm-mos/bin/llvm-objdump'),'-dr',str(o)],text=True)
  data['code_sha256']=hashlib.sha256('\n'.join(dis.splitlines()[3:]).encode()).hexdigest()
  data['matches']=data['code_sha256']==x['after'].get('code_sha256')
 else:data['matches']=p.returncode==x['after'].get('exit_code')
 return data
with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:
 results=[]
 for i,x in enumerate(pool.map(run,rows),1):
  results.append(x)
  if not x['matches']:print('DIFFERENT',x,flush=True)
  if i%100==0:print(i,'/',len(rows),flush=True)
(out/'results.json').write_text(json.dumps(results,indent=2)+'\n')
print('MATCH',sum(x['matches'] for x in results),'/',len(results),flush=True)
