#!/usr/bin/env python3
"""Replay frozen post-LTO IR on extracted backends and the existing SDK."""
import argparse, hashlib, json, os, re, shutil, subprocess, time
from pathlib import Path

ap=argparse.ArgumentParser(description=__doc__)
ap.add_argument('--root',type=Path,required=True)
ap.add_argument('--work',type=Path,help='directory holding pre0070/llc, candidate/llc and build/bin (default: build/far-word-upstream)')
a=ap.parse_args();root=a.root.resolve();work=a.work.resolve() if a.work else root/'build/far-word-upstream';out=work/'runtime';out.mkdir(exist_ok=True)
old=root/'.scratch/far-word-policy';clang=old/'baseline/bin/mos-clang';objdump=work/'build/bin/llvm-objdump';probe=root/'.scratch/carry-timing/jgxcycles-verified'
commands=[];results=[]
def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def run(cmd,stem,env=None,ok=True):
 cmd=list(map(str,cmd));start=time.monotonic();p=subprocess.run(cmd,capture_output=True,text=True,env=env,timeout=180)
 (out/(stem+'.log')).write_text(p.stdout+p.stderr);commands.append(dict(command=cmd,exit_code=p.returncode,seconds=time.monotonic()-start,log=stem+'.log'))
 (out/'commands.json').write_text(json.dumps(commands,indent=2)+'\n')
 if ok and p.returncode:raise RuntimeError(stem+' '+p.stderr[-1000:])
 return p
identity={'method':'Identical captured post-LTO IR, llc object generation, existing SDK/linker; no new frontend or LTO run','binaries':{str(p.relative_to(root)):digest(p) for p in [clang,objdump,probe,work/'pre0070/llc',work/'candidate/llc']},'inputs':{}}
for fixture in ['farblit','bounds','farblit_press']:
 expected={'farblit':0x1e56ee65,'bounds':0xc9276f1e,'farblit_press':0xd695}[fixture]
 for mode in ['a16','xy16']:
  for opt in ['Os','Oz','O2']+(['O3'] if fixture=='farblit' else []):
   stem='-'.join([fixture,mode,opt]);ir=old/'runs'/('baseline-'+stem+'.sfc.0.5.precodegen.bc')
   identity['inputs'][str(ir.relative_to(root))]=digest(ir)
   (out/'identity.json').write_text(json.dumps(identity,indent=2)+'\n')
   for variant in ['baseline','default','all'] if opt!='O3' else ['baseline','default']:
    name=variant+'-'+stem;llc=work/('pre0070' if variant=='baseline' else 'candidate')/'llc';obj=out/(name+'.o');rom=out/(name+'.sfc');mapfile=out/(name+'.map')
    args=[llc,'-mtriple=mos','-mcpu=mosw65816','-mattr='+('+mos-a16,+mos-xy16' if mode=='xy16' else '+mos-a16'),'-verify-machineinstrs','-disable-spill-hoist','-O3' if opt=='O3' else '-O2','-filetype=obj']
    if variant=='all':args+=['-mos-far-word-index=all']
    run(args+[ir,'-o',obj],name+'-compile')
    config='mos-snes.cfg' if fixture=='farblit_press' else 'mos-snes-hirom.cfg'
    table=[] if fixture=='farblit_press' else [root/'build/farblit_tbl.s']
    run([clang,'--config',root/'build/install/bin'/config,'-mcpu=mosw65816','-fno-lto',obj,*table,'-Wl,-Map='+str(mapfile),'-o',rom],name+'-link')
    run(['python3',root/'tools/snes-checksum.py',*(['--hirom'] if table else []),rom],name+'-checksum')
    sym=run([objdump,'-t',str(rom)+'.elf'],name+'-symbols').stdout
    syms={p[-1]:(int(p[0],16),int(p[-2],16)) for l in sym.splitlines() if len(p:=l.split())>=5 and re.fullmatch('[0-9a-f]{8}',p[0])}
    start,size=syms['main'];addr,length=syms['corpus_result']
    cmd=[probe,rom,root/'vendor/bsnes-jg/Database',hex(start),hex(start+size),'0xffffffff',hex(addr),length,hex(expected),1500,1]
    m=json.loads(run(cmd,name+'-bsnes').stdout);repeat=json.loads(run(cmd,name+'-bsnes-repeat').stdout)
    if not m['pass'] or m!=repeat:raise RuntimeError(name+' bsnes oracle/repeat failure')
    scratch=out/'mame-config';scratch.mkdir(exist_ok=True)
    env=dict(os.environ,SDL_VIDEODRIVER='offscreen',SDL_AUDIODRIVER='dummy',SMOKE_ADDR=hex(0x7e0000+addr),SMOKE_WANT=hex(expected),SMOKE_LEN=str(length),SMOKE_SETTLE='1200')
    cmd=['/usr/games/mame','snes','-cart',rom,'-rompath',root/'dev/roms','-autoboot_script',root/'dev/smoke.lua','-skip_gameinfo','-video','none','-sound','none','-nothrottle','-seconds_to_run','23','-cfg_directory',scratch,'-nvram_directory',scratch]
    mm=run(cmd,name+'-mame',env,False);match=re.search(r'SMOKE:.*got=0x([0-9A-Fa-f]+)',mm.stdout)
    got=int(match[1],16) if match else None
    if got!=expected:raise RuntimeError(name+' MAME oracle failure '+mm.stdout[-600:])
    results.append(dict(fixture=fixture,mode=mode,opt=opt,variant=variant,main_bytes=size,exclusive_master_clocks=m['exclusive_master_clocks'],sample_clocks=m['samples'],expected=expected,bsnes=m['got'],mame=got,repeat_equal=True,object_sha256=digest(obj),rom_sha256=digest(rom)))
    (out/'results.json').write_text(json.dumps(results,indent=2)+'\n');print(name,size,m['exclusive_master_clocks'],'PASS',flush=True)
