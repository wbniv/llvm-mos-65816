from pathlib import Path
import hashlib,json,re,resource,shlex,subprocess
r=Path.cwd();e=r/'docs/defects/evidence/2026-09-25-shift-inlineasm-fixes';old=r/'docs/defects/evidence/2026-09-25-historical-recovery';b=r/'build/shift-inlineasm-validation';resource.setrlimit(resource.RLIMIT_CORE,(0,0))
clang=r/'build/defect-baselines/2026-09-25-historical-recovery/bin/clang';runs=[]
def run(cmd,name,expected=0):
 cmd=list(map(str,cmd));p=subprocess.run(cmd,text=True,capture_output=True);log=e/(name+'.log');log.write_text('$ '+shlex.join(cmd)+'\n'+p.stdout+p.stderr+'\nexit_code='+str(p.returncode)+'\n');row=dict(name=name,command=cmd,exit_code=p.returncode);runs.append(row);print(name,p.returncode,flush=True)
 if expected is not None:assert p.returncode==expected,(name,p.stderr[-2000:])
 return p
for mode,features in [('default',[]),('a16',['+mos-a16']),('xy16',['+mos-a16','+mos-xy16'])]:
 flags=[x for f in features for x in ['-Xclang','-target-feature','-Xclang',f]];objects=[]
 for kind,src in [('probe',old/'shift-stage/examples/65816/bitboard64-probe.c'),('harness',e/'bitboard-probe-runtime.c')]:
  obj=e/('lto-'+mode+'-'+kind+'.bc');run([clang,'--target=mos','-mcpu=mosw65816',*flags,'-Os','-flto','-c',src,'-o',obj],'lto-'+mode+'-'+kind);objects.append(obj)
 link=[clang,'--config='+str(r/'build/install/bin/mos-snes.cfg'),'-mcpu=mosw65816','-Os','-flto',*objects,'-Wl,--mllvm=-verify-machineinstrs']
 if mode=='a16':
  p=run([*link,'-fuse-ld='+str(r/'build/inlineasm-bounds-fix/lld-before-0055'),'-o',b/'lto-baseline.sfc'],'lto-a16-baseline',None)
  runs[-1]['same_failure_signature']='G_ANYEXT' in p.stderr and 'unable to legalize instruction' in p.stderr
 rom=b/('lto-'+mode+'.sfc');mp=rom.with_suffix('.map')
 run([*link,'-fuse-ld='+str(r/'build/llvm-mos/bin/ld.lld'),'-Wl,-Map='+str(mp),'-o',rom],'lto-'+mode+'-candidate')
 addr,size=re.search(r'^\s*([0-9a-fA-F]+)\s+[0-9a-fA-F]+\s+([0-9a-fA-F]+)\s+1\s+corpus_result\s*$',mp.read_text(),re.M).groups()
 run([r/'build/jgxcheck',rom,r/'vendor/bsnes-jg/Database','0x'+addr,str(int(size,16)),'0x479E','480'],'lto-'+mode+'-runtime')
 runs[-1].update(rom_sha256=hashlib.sha256(rom.read_bytes()).hexdigest(),map_sha256=hashlib.sha256(mp.read_bytes()).hexdigest())
(e/'lto-runs.json').write_text(json.dumps({'runs':runs,'lld_hashes':{str(p.relative_to(r)):hashlib.sha256(p.read_bytes()).hexdigest() for p in [r/'build/inlineasm-bounds-fix/lld-before-0055',r/'build/llvm-mos/bin/ld.lld']}},indent=2)+'\n')
