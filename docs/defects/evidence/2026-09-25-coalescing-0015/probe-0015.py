from pathlib import Path
import subprocess,shutil,json,hashlib,shlex,resource,gzip
resource.setrlimit(resource.RLIMIT_CORE,(0,0));r=Path.cwd();e=r/'docs/defects/evidence/2026-09-25-coalescing-0015';e.mkdir(exist_ok=True)
src=e/'original/coalesce-rc-undef.mir';patch=(r/'patches/llvm-mos/0015-321-coalesce-rc-undef.patch').read_text();part=patch.split('diff --git a/llvm/test/CodeGen/MOS/coalesce-rc-undef.mir')[1];src.write_text(''.join(x[1:]+'\n' for x in part.splitlines() if x.startswith('+') and not x.startswith('+++')))
shutil.copy2(r/'examples/65816/rcundef.c',e/'original/rcundef.c')
(e/'MOSRegisterInfo.vendor-before.cpp.gz').write_bytes(gzip.compress((r/'vendor/llvm-mos/llvm/lib/Target/MOS/MOSRegisterInfo.cpp').read_bytes(),mtime=0))
compilers={'upstream':r/'build/upstream-reference/742d554bf08042b8df93d791c335260fadd16643/bin/llc','upstream-assert':r/'build/0030-claude-review/llc-pristine-assert','fork':r/'build/llvm-mos/bin/llc'}
identities={k:{'path':str(p),'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'version':subprocess.check_output([str(p),'--version'],text=True)} for k,p in compilers.items()};(e/'initial-tool-identities.json').write_text(json.dumps(identities,indent=2)+'\n')
results=[]
for name,llc in compilers.items():
 for cpu in ['mos6502','mosw65816']:
  for passes in ['register-coalescer','register-coalescer,greedy,virtregrewriter']:
   stem=f'{name}-{cpu}-{passes.replace(",","_")}'
   cmd=[str(llc),'-mtriple=mos','-mcpu='+cpu,'-run-pass='+passes,'-verify-machineinstrs',str(src),'-o',str(e/(stem+'.mir'))];p=subprocess.run(cmd,capture_output=True,text=True)
   (e/(stem+'.log')).write_text('$ '+shlex.join(cmd)+'\n'+p.stdout+p.stderr+'exit_code='+str(p.returncode)+'\n')
   results.append({'compiler':name,'cpu':cpu,'passes':passes,'exit':p.returncode,'first_diagnostic':p.stderr[:200]})
   print(name,cpu,passes,p.returncode,p.stderr[:100],flush=True)
(e/'original-mir-runs.json').write_text(json.dumps(results,indent=2)+'\n')
