from pathlib import Path
import json,subprocess,shlex,shutil,hashlib
r=Path('/work');d=r/'build/historical-bitboard-reconstruction';d.mkdir(exist_ok=True);e=r/'docs/defects/evidence/2026-09-25-historical-recovery';log=e/'reconstruction-build.log';src=d/'VirtRegMap.cpp'
src.write_bytes(subprocess.check_output(['git','-c','safe.directory=/work/vendor/llvm-mos','-C',str(r/'vendor/llvm-mos'),'show','HEAD:llvm/lib/CodeGen/VirtRegMap.cpp']))
commands=json.loads((r/'build/llvm-mos/compile_commands.json').read_text());entry=next(x for x in commands if x['file'].endswith('/VirtRegMap.cpp'));cmd=shlex.split(entry['command']);cmd[cmd.index('-o')+1]=str(d/'VirtRegMap.cpp.o');cmd[-1]=str(src)
with log.open('w') as f:
 def run(args,cwd):
  f.write('$ '+shlex.join(args)+'\n');f.flush();subprocess.run(args,cwd=cwd,stdout=f,stderr=subprocess.STDOUT,check=True)
 run(cmd,entry['directory'])
 shutil.copy2(r/'build/llvm-mos/lib/libLLVMCodeGen.a',d/'libLLVMCodeGen.a')
 run(['/usr/bin/ar','r',str(d/'libLLVMCodeGen.a'),str(d/'VirtRegMap.cpp.o')],d)
 line=subprocess.check_output(['ninja','-C',str(r/'build/llvm-mos'),'-t','commands','bin/llc'],text=True).splitlines()[-1]
 argv=shlex.split(line);assert argv[:2]==[':', '&&'] and argv[-2:]==['&&', ':'];argv=argv[2:-2]
 argv[argv.index('-o')+1]=str(d/'llc-pinned-vreg-rewriter');argv=[str(d/'libLLVMCodeGen.a') if a=='lib/libLLVMCodeGen.a' else a for a in argv]
 run(argv,r/'build/llvm-mos')
manifest={'description':'Current fork libraries with only VirtRegMap.cpp replaced by pristine source at pinned 8be0546; this is a reconstructed comparison, not the original August compiler.','sha256':{str(p.relative_to(r)):hashlib.sha256(p.read_bytes()).hexdigest() for p in [src,d/'VirtRegMap.cpp.o',d/'libLLVMCodeGen.a',d/'llc-pinned-vreg-rewriter']}}
(e/'reconstruction-identity.json').write_text(json.dumps(manifest,indent=2)+'\n')
print('Reconstructed pinned virtual-register rewriter comparison built')
