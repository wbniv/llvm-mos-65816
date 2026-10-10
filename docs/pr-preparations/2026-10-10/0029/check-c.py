import hashlib,json,subprocess
from pathlib import Path
out=Path('/work/docs/pr-preparations/2026-10-10/0029/evidence')
bin=Path('/work/build/repin/20261010T033430Z-ardhs7qy/build-source-3rl8r2dw/bin')
base=Path('/work/build/0029-20261010/baseline/bin/llc')
clang=bin/'clang';source=out/'mixed-width-call.c';rows=[]
def run(name,args):
 p=subprocess.run([str(x) for x in args],capture_output=True)
 (out/(name+'.log')).write_bytes(p.stdout+p.stderr)
 rows.append({'name':name,'command':[str(x) for x in args],'exit_code':p.returncode})
 return p.returncode
run('current-preprocess',[clang,'--target=mos','-mcpu=mos6502','-E',source,'-o',out/'mixed-width-call.i'])
for cpu in ['mos6502','mosw65816']:
 for level in ['0','1','2','3','s','z']:
  stem=f'c-{cpu}-O{level}';ir=out/(stem+'.ll')
  if run(stem+'-emit-ir',[clang,'--target=mos','-mcpu='+cpu,'-O'+level,'-S','-emit-llvm',source,'-o',ir]):continue
  backend='2' if level in ['s','z'] else level
  for tag,compiler in [('baseline',base),('candidate',bin/'llc')]:
   for verifier in [False,True]:
    name=stem+'-'+tag+('-verify' if verifier else '-normal')
    args=[compiler,'-mtriple=mos','-mcpu='+cpu,'-O'+backend,'-filetype=obj']
    if verifier:args+=['-verify-machineinstrs']
    run(name,args+[ir,'-o',out/(name+'.o')])
  for verifier in [False,True]:
   name=stem+'-driver'+('-verify' if verifier else '-normal')
   args=[clang,'--target=mos','-mcpu='+cpu,'-O'+level]
   if verifier:args+=['-mllvm','-verify-machineinstrs']
   run(name,args+['-c',source,'-o',out/(name+'.o')])
identity={'source_base':'0f031168a7cc8e81b7b40c0ec0b1f7b3c90b8a63','compiler_commit':'367513ea6a79','clang_static_analyzer':False,'baseline_pipeline':'Candidate frontend (unchanged by 0029) emits each input once, then both preserved current-base backends compile those identical bytes. This is not a separate pristine Clang driver build.','clang_version':subprocess.check_output([clang,'--version']).decode(),'binary_sha256':{str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in [clang,bin/'llc',base]},'input_sha256':{str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in out.glob('c-*.ll')},'runs':rows}
(out/'current-c-matrix.json').write_text(json.dumps(identity,indent=2)+'\n')
print(json.dumps([(r['name'],r['exit_code']) for r in rows]),flush=True)
