from pathlib import Path
import hashlib,json,re,resource,shlex,shutil,subprocess,sys
r=Path.cwd();e=r/'docs/defects/evidence/2026-09-25-shift-inlineasm-fixes';old=r/'docs/defects/evidence/2026-09-25-historical-recovery';b=r/'build/shift-inlineasm-validation';b.mkdir(exist_ok=True)
resource.setrlimit(resource.RLIMIT_CORE,(0,0));clang=r/'build/llvm-mos/bin/clang';llc=r/'build/llvm-mos/bin/llc';cross=r/'build/inlineasm-bounds-fix/llc';runs=[]
def run(cmd,name,expected=0):
 cmd=list(map(str,cmd));p=subprocess.run(cmd,text=True,capture_output=True);log=e/(name+'.log');log.write_text('$ '+shlex.join(cmd)+'\n'+p.stdout+p.stderr+'\nexit_code='+str(p.returncode)+'\n');runs.append(dict(name=name,command=cmd,exit_code=p.returncode,expected=expected,log=str(log.relative_to(r))));print(name,p.returncode,flush=True)
 assert p.returncode==expected,(name,p.stderr[-3000:]);return p.stdout
phase=sys.argv[1]
if phase=='compile':
 baseline=json.loads((r/'docs/defects/shift64-narrow-count.json').read_text())['baseline']
 run(shlex.split(baseline['command']),'shift-baseline-replay',1)
 command=shlex.split(baseline['command']);command[0]=clang;run(command,'shift-candidate-matching-input')
 inp=old/'replay/shift-stage.ll';run([llc,'-mcpu=mosw65816','-mattr=+mos-a16','-O2','-verify-machineinstrs',inp,'-o','/dev/null'],'shift-retained-ir-candidate')
 mir=r/'vendor/llvm-mos/llvm/test/CodeGen/MOS/anyext-wide.mir';shutil.copy2(mir,e/'anyext-wide.mir')
 run([r/'build/defect-baselines/2026-09-25-historical-recovery/bin/llc','-mtriple=mos','-mcpu=mosw65816','-mattr=+mos-a16','-run-pass=legalizer','-verify-machineinstrs',mir,'-o','/dev/null'],'anyext-wide-control-baseline')
 for mode,features in [('default',[]),('a16',['+mos-a16']),('xy16',['+mos-a16','+mos-xy16'])]:
  for opt in ['O0','O1','O2','O3','Os','Oz']:
   for stage in ['shift','inline']:
    flags=[str(x) for f in features for x in ['-Xclang','-target-feature','-Xclang',f]]
    run([clang,'--target=mos','-mcpu=mosw65816',*flags,'-'+opt,'-fno-lto','-mllvm','-verify-machineinstrs','-x','cpp-output','-c',old/('replay/'+stage+'-stage.i'),'-o','/dev/null'],stage+'-'+mode+'-'+opt)
 for name,tool,expected in [('baseline',r/'build/0041-inlineasm-build/llc-0041',1),('candidate',cross,0)]:
  run(['python3',r/'dev/check-inlineasm-register-diagnostic.py','--llc',tool],'inlineasm-'+name+'-runner',expected)
 test=r/'vendor/llvm-mos/llvm/test/CodeGen/AArch64/GlobalISel/inline-asm-physreg-exhaustion.ll';shutil.copy2(test,e/test.name)
 for opt in ['O0','O2']:
  for abort in ['0','1']:
   out=run([cross,'-mtriple=aarch64','-global-isel','-global-isel-abort='+abort,'-'+opt,'-verify-machineinstrs',test,'-o','/dev/null'],'inlineasm-'+opt+'-abort'+abort,1)
 for reg in ['x28','x30','xzr']:
  run([cross,'-mtriple=aarch64','-global-isel','-global-isel-abort=1','-O0','-verify-machineinstrs',e/('asm-'+reg+'.ll'),'-o','/dev/null'],'inlineasm-valid-'+reg)
elif phase=='runtime':
 for name in ['shift-runtime.c','shift-narrow.h']:shutil.copy2(r/'build/older-defect-recheck'/name,e/name)
 shutil.copy2(old/'bitboard-probe-runtime.c',e/'bitboard-probe-runtime.c')
 for test in ['shift-runtime','bitboard-probe-runtime']:
  src=e/(test+'.c');extra=[old/'shift-stage/examples/65816/bitboard64-probe.c'] if test.startswith('bitboard') else []
  run(['cc','-O2','-DHOST_MAIN',src,*extra,'-o',b/(test+'-host')],test+'-host-build')
  expected=run([b/(test+'-host')],test+'-host').strip()
  for mode,features in [('default',[]),('a16',['+mos-a16']),('xy16',['+mos-a16','+mos-xy16'])]:
   rom=b/(test+'-'+mode+'.sfc');mp=rom.with_suffix('.map');flags=[str(x) for f in features for x in ['-Xclang','-target-feature','-Xclang',f]]
   run([clang,'--config='+str(r/'build/install/bin/mos-snes.cfg'),'-fuse-ld='+str(r/'build/llvm-mos/bin/ld.lld'),'-mcpu=mosw65816',*flags,'-Os','-fno-lto','-mllvm','-verify-machineinstrs',src,*extra,'-Wl,-Map='+str(mp),'-o',rom],test+'-'+mode+'-build')
   address,size=re.search(r'^\s*([0-9a-fA-F]+)\s+[0-9a-fA-F]+\s+([0-9a-fA-F]+)\s+1\s+corpus_result\s*$',mp.read_text(),re.M).groups()
   run([r/'build/jgxcheck',rom,r/'vendor/bsnes-jg/Database','0x'+address,str(int(size,16)),expected,'480'],test+'-'+mode+'-runtime')
   runs[-1].update(expected_value=expected,rom_sha256=hashlib.sha256(rom.read_bytes()).hexdigest(),map_sha256=hashlib.sha256(mp.read_bytes()).hexdigest())
(e/(phase+'-runs.json')).write_text(json.dumps(runs,indent=2)+'\n')
