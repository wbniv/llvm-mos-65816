from pathlib import Path
import shlex,subprocess,shutil
r=Path('/work');b=r/'build/coalescing-0015-contrast';build=r/'build/llvm-mos';e=r/'docs/defects/evidence/2026-09-25-coalescing-0015'
with (e/'link-contrasts.log').open('w') as f:
 def run(cmd,cwd):
  f.write('$ '+shlex.join(cmd)+'\n');f.flush();subprocess.run(cmd,cwd=cwd,stdout=f,stderr=subprocess.STDOUT,check=True)
 shutil.copy2(build/'lib/libLLVMCodeGen.a',b/'libLLVMCodeGen.no0028.a')
 run(['/usr/bin/ar','r',str(b/'libLLVMCodeGen.no0028.a'),str(r/'build/historical-bitboard-reconstruction/VirtRegMap.cpp.o')],b)
 line=subprocess.check_output(['ninja','-C',str(build),'-t','commands','bin/llc'],text=True).splitlines()[-1]
 args=shlex.split(line);assert args[:2]==[':', '&&'] and args[-2:]==['&&', ':'];args=args[2:-2]
 for name,guard in [('llc-guard-no0028',True),('llc-noguard-no0028',False)]:
  argv=args.copy();argv[argv.index('-o')+1]=str(b/name);argv=[str(b/'libLLVMCodeGen.no0028.a') if a=='lib/libLLVMCodeGen.a' else a for a in argv]
  if not guard:argv=[str(b/'libLLVMMOSCodeGen.a') if a=='lib/libLLVMMOSCodeGen.a' else a for a in argv]
  run(argv,build)
print('Linked two isolated 0015/0028 contrasts')
