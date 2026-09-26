from pathlib import Path
import json,shlex,subprocess,shutil
r=Path('/work');b=r/'build/coalescing-0015-contrast';build=r/'build/llvm-mos';e=r/'docs/defects/evidence/2026-09-25-coalescing-0015'
entry=next(x for x in json.loads((build/'compile_commands.json').read_text()) if x['file'].endswith('/MOS/MOSRegisterInfo.cpp'))
cmd=shlex.split(entry['command']);cmd[cmd.index('-o')+1]=str(b/'MOSRegisterInfo.cpp.o');cmd[-1]=str(b/'MOSRegisterInfo.cpp')
with (e/'build-guard-disabled.log').open('w') as f:
 def run(args,cwd):
  f.write('$ '+shlex.join(args)+'\n');f.flush();subprocess.run(args,cwd=cwd,stdout=f,stderr=subprocess.STDOUT,check=True)
 run(cmd,entry['directory'])
 shutil.copy2(build/'lib/libLLVMMOSCodeGen.a',b/'libLLVMMOSCodeGen.a')
 run(['/usr/bin/ar','r',str(b/'libLLVMMOSCodeGen.a'),str(b/'MOSRegisterInfo.cpp.o')],b)
 line=subprocess.check_output(['ninja','-C',str(build),'-t','commands','bin/llc'],text=True).splitlines()[-1]
 argv=shlex.split(line);assert argv[:2]==[':', '&&'] and argv[-2:]==['&&', ':'];argv=argv[2:-2]
 argv[argv.index('-o')+1]=str(b/'llc');argv=[str(b/'libLLVMMOSCodeGen.a') if a=='lib/libLLVMMOSCodeGen.a' else a for a in argv]
 run(argv,build)
print('Built guard-disabled diagnostic contrast; installed compiler unchanged')
