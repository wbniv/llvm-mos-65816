from pathlib import Path
import subprocess,json,resource,shlex
resource.setrlimit(resource.RLIMIT_CORE,(0,0))
r=Path.cwd();e=r/'docs/defects/evidence/2026-09-25-aarch64-vector-asm';d=e/'forms';d.mkdir(exist_ok=True)
forms={
'input':'''define void @f(ptr %p) { %v = load TYPE, ptr %p
call void asm sideeffect "", "r"(TYPE %v)
ret void }''',
'output':'''define void @f(ptr %p) { %v = call TYPE asm sideeffect "", "=r"()
store TYPE %v, ptr %p
ret void }''',
'indirect':'''define void @f(ptr %p) { call void asm sideeffect "", "=*r"(ptr elementtype(TYPE) %p)
ret void }''',
 'tied':'''define void @f(ptr %p) { %v = load TYPE, ptr %p
%r = call TYPE asm sideeffect "", "=r,0"(TYPE %v)
store TYPE %r, ptr %p
ret void }''',
'callbr':'''define void @f(ptr %p) { %r = callbr TYPE asm sideeffect "", "=r,!i"() to label %fallthrough [label %indirect]
fallthrough: store TYPE %r, ptr %p
ret void
indirect: store TYPE %r, ptr %p
ret void }''',
'callbr-input':'''define i64 @f(ptr %p) { %v = load TYPE, ptr %p
%r = callbr i64 asm sideeffect "", "=r,r,!i"(TYPE %v) to label %fallthrough [label %indirect]
fallthrough: ret i64 %r
indirect: ret i64 %r }'''}
results=[]
for n,ty in [(64,'<64 x i64>'),(8,'<8 x i64>'),(2,'<2 x i64>')]:
 for form,source in forms.items():
  p=d/f'{form}-{n}.ll';p.write_text(source.replace('TYPE',ty)+'\n')
  for compiler in ['aarch64-asm-type-fix','selectiondag-vector-parts-fix']:
   for opt in ['O0','O2']:
    cmd=[str(r/'build'/compiler/'llc'),'-mtriple=aarch64','-global-isel=0','-'+opt,'-verify-machineinstrs',str(p),'-o','/dev/null']
    run=subprocess.run(cmd,capture_output=True,text=True)
    log=d/f'{form}-{n}-{compiler}-{opt}.log';log.write_text('$ '+shlex.join(cmd)+'\n'+run.stdout+run.stderr+'exit_code='+str(run.returncode)+'\n')
    res={'type':ty,'form':form,'compiler':compiler,'opt':opt,'exit':run.returncode,'diagnostics':run.stderr.splitlines()[:3]};results.append(res)
    print(compiler,opt,n,form,run.returncode,' | '.join(run.stderr.splitlines()[:2]),flush=True)
(e/'forms-summary.json').write_text(json.dumps(results,indent=2)+'\n')
