from pathlib import Path
import subprocess,json,sys,re,shutil,time,hashlib
root=Path.cwd();w=root/'.scratch/far-word-policy';variant=sys.argv[1];tool=w/('baseline' if variant=='baseline' else 'policy' if variant=='default' else 'candidate')/'bin';policy=[] if variant in ['baseline','default'] else ['-mllvm','-mos-far-word-index='+variant];lpolicy=[] if variant in ['baseline','default'] else ['-Wl,--mllvm=-mos-far-word-index='+variant];out=w/'runs';records=json.loads((w/(variant+'-o3-sweep.json')).read_text()) if (w/(variant+'-o3-sweep.json')).exists() else [];commands=json.loads((w/(variant+'-o3-commands.json')).read_text()) if (w/(variant+'-o3-commands.json')).exists() else []
def run(cmd,name,allow=False,timeout=300):
 cmd=list(map(str,cmd));begin=time.monotonic();p=subprocess.run(cmd,text=True,capture_output=True,timeout=timeout)
 (out/(name+'.log')).write_text(p.stdout+p.stderr);commands.append(dict(command=cmd,status=p.returncode,seconds=time.monotonic()-begin,log=name+'.log'))
 (w/(variant+'-o3-commands.json')).write_text(json.dumps(commands,indent=2)+'\n')
 if not allow and p.returncode:raise RuntimeError(name+'\n'+p.stderr[-4000:])
 return p
fixtures=['farblit']
for fixture in fixtures:
 source=w/'source'/(fixture+'.c')
 if not source.exists():
  original=root/'examples/65816'/(fixture+'.c') if fixture!='bounds' else root/'.scratch/farblit-payoff/source/bounds.c'
  shutil.copy2(original,source)
 for mode in ['a16','xy16']:
  flags=['-Xclang','-target-feature','-Xclang','+mos-a16']
  if mode=='xy16':flags+=['-Xclang','-target-feature','-Xclang','+mos-xy16']
  for opt in ['O3']:
   name='-'.join([variant,fixture,mode,opt]);obj=out/(name+'.o')
   prior=next((r for r in records if (r['fixture'],r['mode'],r['opt'])==(fixture,mode,opt)),None)
   if prior and (prior.get('measurement') or (fixture not in ['farblit','farblit_press','bounds'] and prior['compile_status']==0)):continue
   if prior:records.remove(prior)
   args=[tool/'mos-clang','--config',root/'build/install/bin/mos-snes-hirom.cfg','-mcpu=mosw65816',*flags,'-'+opt,*policy,'-mllvm','-verify-machineinstrs']
   p=run([*args,'-fno-lto','-I',root/'examples/65816','-c',source,'-o',obj],name+'-compile',True)
   rec=dict(variant=variant,fixture=fixture,mode=mode,opt=opt,compile_status=p.returncode)
   if p.returncode==0:
    syms=run([tool/'llvm-objdump','-t',obj],name+'-symbols').stdout
    rec['function_bytes']=sum(int(parts[-2],16) for line in syms.splitlines() if len(parts:=line.split())>=6 and parts[2]=='F')
    rec['object_sha256']=hashlib.sha256(obj.read_bytes()).hexdigest()
   records.append(rec);(w/(variant+'-o3-sweep.json')).write_text(json.dumps(records,indent=2)+'\n')
   if fixture not in ['farblit','farblit_press','bounds'] or p.returncode:continue
   expected={'farblit':0x1e56ee65,'farblit_press':0xd695,'bounds':0xc9276f1e}[fixture]
   if opt=='Os' and mode=='a16':
    run(['cc','-DHOST','-O2','-I',root/'examples/65816',source,'-o',out/(variant+'-'+variant+'-'+fixture+'-host')],variant+'-'+fixture+'-host-build')
    assert int(run([out/(variant+'-'+variant+'-'+fixture+'-host')],variant+'-'+fixture+'-host').stdout,16)==expected
   config='mos-snes.cfg' if fixture=='farblit_press' else 'mos-snes-hirom.cfg'
   largs=[tool/'mos-clang','--config',root/'build/install/bin'/config,'-mcpu=mosw65816',*flags,'-'+opt,*policy,'-mllvm','-verify-machineinstrs','-Wl,--mllvm=-verify-machineinstrs','-Wl,--save-temps',*lpolicy]
   table=[] if fixture=='farblit_press' else [root/'build/farblit_tbl.s']
   rom=out/(name+'.sfc');mapfile=out/(name+'.map')
   run([*largs,'-I',root/'examples/65816',source,*table,'-Wl,-Map='+str(mapfile),'-o',rom],name+'-lto')
   run(['python3',root/'tools/snes-checksum.py',*(['--hirom'] if table else []),rom],name+'-checksum')
   syms=run([tool/'llvm-objdump','-t',str(rom)+'.elf'],name+'-lto-symbols').stdout
   symbols={p[-1]:(int(p[0],16),int(p[-2],16)) for l in syms.splitlines() if len(p:=l.split())>=5 and re.fullmatch('[0-9a-f]{8}',p[0])}
   start,size=symbols['main'];addr,length=symbols['corpus_result']
   cmd=[root/'.scratch/carry-timing/jgxcycles-verified',rom,root/'vendor/bsnes-jg/Database',hex(start),hex(start+size),'0xffffffff',hex(addr),length,hex(expected),1500,1]
   measurement=json.loads(run(cmd,name+'-bsnes',timeout=600).stdout);assert measurement['pass']
   repeated=json.loads(run(cmd,name+'-bsnes-repeat',timeout=600).stdout);assert repeated==measurement
   rec.update(lto_main_bytes=size,lto_code_bytes=sum(int(p[-2],16) for line in syms.splitlines() if len(p:=line.split())>=6 and p[2]=='F'),measurement=measurement,expected=expected,rom=str(rom.relative_to(root)),map=str(mapfile.relative_to(root)))
   (w/(variant+'-o3-sweep.json')).write_text(json.dumps(records,indent=2)+'\n')
   print(name,'PASS',rec['function_bytes'],size,flush=True)
print('done',variant,len(records),'objects',flush=True)
