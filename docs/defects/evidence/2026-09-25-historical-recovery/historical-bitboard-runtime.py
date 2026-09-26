from pathlib import Path
import subprocess,shlex,re,json,hashlib,shutil,resource
resource.setrlimit(resource.RLIMIT_CORE,(0,0));r=Path.cwd();e=r/'docs/defects/evidence/2026-09-25-historical-recovery';o=e/'replay';b=r/'build/historical-bitboard-runtime';b.mkdir(exist_ok=True);tools=r/'build/defect-baselines/2026-09-25-historical-recovery/bin'
with (e/'bitboard-probe-runtime.log').open('w') as f:
 def run(cmd):
  f.write('$ '+shlex.join(map(str,cmd))+'\n');f.flush();p=subprocess.run(list(map(str,cmd)),capture_output=True,text=True);f.write(p.stdout+p.stderr+f'\nexit_code={p.returncode}\n');f.flush();assert p.returncode==0;return p.stdout
 run(['cc','-O2','-DHOST_MAIN',e/'inline-stage/examples/65816/bitboard64-probe.c',e/'bitboard-probe-runtime.c','-o',b/'host'])
 want=run([b/'host']).strip();print('Host:',want,flush=True)
 roms=[]
 for mode,feat in [('a16','+mos-a16'),('xy16','+mos-a16,+mos-xy16')]:
  obj=b/f'{mode}.o';rom=b/f'{mode}.sfc';mp=b/f'{mode}.map'
  run([tools/'llc','-mcpu=mosw65816','-mattr='+feat,'-O2','-verify-machineinstrs','-filetype=obj',o/'inline-stage.ll','-o',obj])
  run([tools/'clang','--config='+str(r/'build/install/bin/mos-snes.cfg'),'-fuse-ld='+str(r/'build/llvm-mos/bin/ld.lld'),'-mcpu=mosw65816','-Os','-fno-lto',e/'bitboard-probe-runtime.c',obj,'-Wl,-Map='+str(mp),'-o',rom])
  addr,size=re.search(r'^\s*([0-9a-fA-F]+)\s+[0-9a-fA-F]+\s+([0-9a-fA-F]+)\s+1\s+corpus_result\s*$',mp.read_text(),re.M).groups()
  run([r/'build/jgxcheck',rom,r/'vendor/bsnes-jg/Database','0x'+addr,str(int(size,16)),want,'480'])
  roms.append({'mode':mode,'expected':want,'rom_sha256':hashlib.sha256(rom.read_bytes()).hexdigest(),'map_sha256':hashlib.sha256(mp.read_bytes()).hexdigest()});print(mode,'PASS',flush=True)
(e/'bitboard-probe-runtime.json').write_text(json.dumps(roms,indent=2)+'\n')
