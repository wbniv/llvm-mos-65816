from pathlib import Path
import json,re,subprocess,importlib.util,sys
root=Path.cwd();w=root/'.scratch/farblit-payoff';out=w/'runs';tool=root/'build/llvm-mos-install/bin'
commands=[];rows=[]
def run(cmd,name):
 cmd=list(map(str,cmd));p=subprocess.run(cmd,capture_output=True,text=True,timeout=300)
 (out/(name+'.log')).write_text(p.stdout+p.stderr)
 commands.append({'command':cmd,'exit_code':p.returncode,'log':name+'.log'})
 (w/'validation-commands.json').write_text(json.dumps(commands,indent=2)+'\n')
 assert p.returncode==0,name+'\n'+p.stderr[-2000:]
 return p.stdout
for fixture,source,expected in [('bounds',w/'source/bounds.c',0xC9276F1E),('pressure',root/'examples/65816/farblit_press.c',0xD695)]:
 run(['cc','-DHOST','-O2',source,'-o',out/(fixture+'-host')],fixture+'-host-build')
 assert int(run([out/(fixture+'-host')],fixture+'-host'),16)==expected
 for mode in ['a16','xy16']:
  features='+mos-a16'+(',+mos-xy16' if mode=='xy16' else '')
  if fixture=='pressure':
   flags=['-Xclang','-target-feature','-Xclang','+mos-a16']
   if mode=='xy16':flags+=['-Xclang','-target-feature','-Xclang','+mos-xy16']
   run([tool/'mos-clang','--target=mos','-mcpu=mosw65816',*flags,'-Os','-gline-tables-only','-S','-mllvm','-stop-before=legalizer',source,'-o',w/(mode+'.pressure.pre')],fixture+'-'+mode+'-frontend')
  for variant in ['baseline','both']:
   name=fixture+'-'+variant+'-'+mode
   compiler=w/'bin'/('llc-baseline' if variant=='baseline' else 'llc-candidate')
   options=[] if variant=='baseline' else ['-mos-far-range-experiment','-mos-far-word-experiment']
   args=[compiler,'-mtriple=mos','-mcpu=mosw65816','-mattr='+features,'-x=mir','-start-before=legalizer','-verify-machineinstrs',*options,w/(mode+'.'+fixture+'.pre')]
   for typ,ext in [('obj','o'),('asm','s')]: run([*args,'-filetype='+typ,'-o',out/(name+'.'+ext)],name+'-'+typ)
   run([*args,'-stop-after=legalizer','-o',out/(name+'.after.mir')],name+'-after')
   rom=out/(name+'.sfc')
   table=[root/'build/farblit_tbl.s'] if fixture=='bounds' else []
   config='mos-snes-hirom.cfg' if fixture=='bounds' else 'mos-snes.cfg'
   run([tool/'mos-clang','--config',root/'build/install/bin'/config,'-mcpu=mosw65816','-Os','-fno-lto',out/(name+'.o'),*table,'-Wl,-Map='+str(out/(name+'.map')),'-o',rom],name+'-link')
   run(['python3',root/'tools/snes-checksum.py',*(['--hirom'] if fixture=='bounds' else []),rom],name+'-checksum')
   text=run([tool/'llvm-objdump','-t',str(rom)+'.elf'],name+'-symbols')
   syms={p[-1]:(int(p[0],16),int(p[-2],16)) for l in text.splitlines() if len(p:=l.split())>=5 and re.fullmatch('[0-9a-f]{8}',p[0])}
   start,size=syms['main'];addr,length=syms['corpus_result']
   cmd=[root/'.scratch/carry-timing/jgxcycles-verified',rom,root/'vendor/bsnes-jg/Database',hex(start),hex(start+size),'0xffffffff',hex(addr),length,hex(expected),1500,1]
   measurement=json.loads(run(cmd,name+'-bsnes'));assert measurement['pass']
   if fixture=='pressure':
    spec=importlib.util.spec_from_file_location('shapes',root/'dev/check-farblit-shapes.py');m=importlib.util.module_from_spec(spec);sys.modules[spec.name]=m;spec.loader.exec_module(m)
    shape=m.check_shapes((out/(name+'.s')).read_text(),source,mode,'pressure');(out/(name+'.shapes.json')).write_text(json.dumps(shape,indent=2)+'\n')
   rows.append({'fixture':fixture,'variant':variant,'mode':mode,'expected':expected,'pass':True,'rom':str(rom.relative_to(root))})
   (w/'validation.json').write_text(json.dumps(rows,indent=2)+'\n')
   print(name,'PASS',hex(expected),flush=True)
