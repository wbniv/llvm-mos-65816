import subprocess,json,concurrent.futures,pathlib,hashlib
r=pathlib.Path('/work');out=r/'build/near-proof-recovery/corpus-runtime-final';out.mkdir(exist_ok=True)
rows=json.loads((r/'build/near-proof-recovery/census/report.json').read_text())
changed={x['source'] for x in rows if '/corpus/' in x['source'] and all('text' in x[a] for a in ['before','after']) and x['before']['code_sha256']!=x['after']['code_sha256']}
expected={ 'examples/snes/'+p[0]:p[2] for line in (r/'examples/snes/corpus/expected.tsv').read_text().splitlines() if (p:=line.split()) and not line.startswith('#') and len(p)>=3}
cc=r/'build/near-proof-recovery/final/bin/clang'
identity={n:hashlib.sha256((cc.parent/n).read_bytes()).hexdigest() for n in ['clang','ld.lld']}
(out/'identity.json').write_text(json.dumps(identity,indent=2)+'\n')
def run(case):
 src,mode,features=case;stem=out/(pathlib.Path(src).stem+'-'+mode)
 cmd=[str(cc),'--config',str(r/'build/install/bin/mos-snes.cfg'),'-mcpu=mosw65816','-Os','-fno-lto','-mllvm','-verify-machineinstrs']
 for f in features:cmd+=['-Xclang','-target-feature','-Xclang',f]
 cmd+=['-Wl,-Map='+str(stem)+'.map',str(r/src),'-o',str(stem)+'.sfc']
 with stem.with_suffix('.log').open('w') as log:
  def call(c):
   print('COMMAND:', ' '.join(c),file=log,flush=True);p=subprocess.run(c,stdout=log,stderr=subprocess.STDOUT); print('EXIT:',p.returncode,file=log,flush=True);return p.returncode
  code=call(cmd)
  if not code:
   call(['python3',str(r/'tools/snes-checksum.py'),str(stem)+'.sfc'])
   addr=next(l.split()[0] for l in pathlib.Path(str(stem)+'.map').read_text().splitlines() if l.split() and l.split()[-1]=='corpus_result')
   code=call([str(r/'build/jgxcheck'),str(stem)+'.sfc',str(r/'vendor/bsnes-jg/Database'),'0x'+addr,'2',expected[src],'1000'])
 return dict(source=src,mode=mode,exit_code=code,expected=expected[src])
cases=[(s,m,f) for s in sorted(changed&expected.keys()) for m,f in [('default',[]),('a16',['+mos-a16']),('xy16',['+mos-a16','+mos-xy16'])]]
with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:
 results=[]
 for item in pool.map(run,cases):results.append(item); print(item,flush=True)
(out/'results.json').write_text(json.dumps(results,indent=2)+'\n')
print('PASS',sum(x['exit_code']==0 for x in results),'/',len(results),flush=True)
