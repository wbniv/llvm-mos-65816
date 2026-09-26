from pathlib import Path
import json,shlex,subprocess,shutil
r=Path('/work');b=r/'build/selectiondag-vector-parts-fix';build=r/'build/newton-postra-build';log=r/'docs/defects/evidence/2026-09-25-aarch64-vector-asm/candidate-build.log'
commands=json.loads((build/'compile_commands.json').read_text());entry=next(x for x in commands if x['file'].endswith('/SelectionDAG/SelectionDAGBuilder.cpp'))
cmd=shlex.split(entry['command']);cmd[cmd.index('-o')+1]=str(b/'SelectionDAGBuilder.cpp.o');cmd[-1]=str(b/'SelectionDAGBuilder.cpp')
with log.open('w') as f:
 def run(args,cwd):
  f.write('$ '+shlex.join(args)+'\n');f.flush();subprocess.run(args,cwd=cwd,stdout=f,stderr=subprocess.STDOUT,check=True)
 run(cmd,entry['directory'])
 shutil.copy2(build/'lib/libLLVMSelectionDAG.a',b/'libLLVMSelectionDAG.a')
 run(['/usr/bin/ar','r',str(b/'libLLVMSelectionDAG.a'),str(b/'SelectionDAGBuilder.cpp.o')],b)
 line=subprocess.check_output(['ninja','-C',str(build),'-t','commands','bin/llc'],text=True).splitlines()[-1]
 argv=shlex.split(line);assert argv[:2]==[':', '&&'] and argv[-2:]==['&&', ':'];argv=argv[2:-2]
 argv[argv.index('-o')+1]=str(b/'llc');argv=[str(b/'libLLVMSelectionDAG.a') if a=='lib/libLLVMSelectionDAG.a' else a for a in argv]
 argv=['/tmp/aarch64-asm-type-fix/libLLVMAArch64CodeGen.a' if a=='lib/libLLVMAArch64CodeGen.a' else a for a in argv]
 argv=[('-Wl,--dependency-file='+str(b/'llc-link.d')) if a.startswith('-Wl,--dependency-file=') else ('--dependency-file='+str(b/'llc-link.d')) if a.startswith('--dependency-file=') else a for a in argv]
 run(argv,build)
print('Built isolated assertion-enabled cross-target candidate')
