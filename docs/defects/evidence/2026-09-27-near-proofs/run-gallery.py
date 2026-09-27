import argparse,subprocess,json,hashlib,pathlib,sys,os
p=argparse.ArgumentParser();p.add_argument('side');p.add_argument('kind');p.add_argument('--non-lto',action='store_true');a=p.parse_args()
r=pathlib.Path('/work');out=r/'build/near-proof-recovery'/a.side;out.mkdir(exist_ok=True);tag=a.kind+('-nonlto' if a.non_lto else '');o=out/tag
cc=r/'build/llvm-mos/bin/clang'
if a.kind=='gallery':src=r/'docs/defects/evidence/2026-09-26-dpy-near-y/lzss-gallery.c.txt';cfg='mos-snes-gallery.cfg';frames=30000;defs=['-DGALLERY_BENCH_ONLY=1','-I/work/examples/snes']
else:src=r/'build/near-y-fix/near-decode.c';cfg='mos-snes.cfg';frames=180;defs=[]
cmd=[str(cc),'--config',str(r/'build/install/bin'/cfg),'-mcpu=mosw65816','-Xclang','-target-feature','-Xclang','+mos-a16','-Xclang','-target-feature','-Xclang','+mos-xy16','-Oz',*defs]
if a.non_lto:cmd+=['-fno-lto']
log=open(str(o)+'.log','w')
def run(c):
 print('COMMAND:', ' '.join(c),file=log,flush=True)
 q=subprocess.run(c,stdout=log,stderr=subprocess.STDOUT);print('EXIT:',q.returncode,file=log,flush=True);return q.returncode
for ext,flags in [('i',['-E']),('ll',['-S','-emit-llvm']),('s',['-S','-fno-lto'])]:
 if run(cmd+flags+['-x','c',str(src),'-o',str(o)+'.'+ext]):sys.exit(2)
q=run(cmd+['-Wl,--save-temps','-Wl,-Map='+str(o)+'.map','-x','c',str(src),'-o',str(o)+'.sfc'])
if q:sys.exit(q)
run(['python3',str(r/'tools/snes-checksum.py'),str(o)+'.sfc'])
addr=next(l.split()[0] for l in pathlib.Path(str(o)+'.map').read_text().splitlines() if l.split() and l.split()[-1]=='corpus_result')
q=run([str(r/'build/jgxcheck'),str(o)+'.sfc',str(r/'vendor/bsnes-jg/Database'),'0x'+addr,'2','0x5CF0',str(frames)])
h=lambda f:hashlib.sha256(pathlib.Path(f).read_bytes()).hexdigest()
pathlib.Path(str(o)+'.json').write_text(json.dumps(dict(command=cmd,input=str(src),input_sha256=h(src),compiler_sha256=h(cc),linker_sha256=h(cc.parent/'ld.lld'),rom_sha256=h(str(o)+'.sfc'),exit=q),indent=2)+'\n')
print(a.side,tag,'exit',q);sys.exit(q)
