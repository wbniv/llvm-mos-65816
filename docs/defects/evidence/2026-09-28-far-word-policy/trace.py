from pathlib import Path
import subprocess,json,re,collections,difflib
root=Path.cwd();w=root/'.scratch/far-word-policy';out=w/'trace';out.mkdir(exist_ok=True);tool=w/'candidate/bin'
commands=[]
def run(cmd):
 p=subprocess.run(list(map(str,cmd)),capture_output=True,text=True);commands.append(dict(command=list(map(str,cmd)),status=p.returncode));assert not p.returncode,p.stderr;return p.stdout
rows=[]
for variant in ['off','all']:
 name=out/variant
 flags=['-mtriple=mos','-mcpu=mosw65816','-mattr=+mos-a16','-x=mir','-start-before=legalizer','-verify-machineinstrs','-mos-far-word-index='+variant]
 pre=root/'.scratch/farblit-payoff/a16.pre'
 for ext,extra in [('s',[]),('mir',['-stop-after=virtregrewriter'])]:
  run([tool/'llc',*flags,*extra,pre,'-o',str(name)+'.'+ext])
 s=Path(str(name)+'.s').read_text();labelled=s.replace('.LBB','trace_bb')
 Path(str(name)+'.labels.s').write_text(labelled)
 run([tool/'llvm-mc','-triple=mos','-mcpu=mosw65816','-mattr=+mos-a16','-filetype=obj',str(name)+'.labels.s','-o',str(name)+'.o'])
 sym=run([tool/'llvm-objdump','-t',str(name)+'.o']);Path(str(name)+'.symbols').write_text(sym)
 dis=run([tool/'llvm-objdump','-dr',str(name)+'.o']);Path(str(name)+'.dis').write_text(dis)
 blocks=[];cur=None
 for line in dis.splitlines():
  if m:=re.match(r'([0-9a-f]+) <(main|trace_bb[^>]+)>:',line):
   cur=dict(name=m[2],start=int(m[1],16),bytes=0,ops=collections.Counter());blocks.append(cur)
  elif cur is not None and (m:=re.match(r'\s*[0-9a-f]+:\s+((?:[0-9a-f]{2} )+)\s*(\w+)',line)):
   cur['bytes']+=len(m[1].split());cur['ops'][m[2]]+=1
 rows.append(dict(variant=variant,blocks=blocks))
(w/'trace.json').write_text(json.dumps(rows,indent=2)+'\n');(w/'trace-commands.json').write_text(json.dumps(commands,indent=2)+'\n')
a,b=rows
for x,y in zip(a['blocks'],b['blocks']):
 if x['bytes']!=y['bytes'] or x['ops']!=y['ops']:print(x['name'],x['bytes'],y['bytes'],dict(collections.Counter(y['ops'])-collections.Counter(x['ops'])),dict(collections.Counter(x['ops'])-collections.Counter(y['ops'])))
(out/'assembly.diff').write_text(''.join(difflib.unified_diff((out/'off.s').read_text().splitlines(True),(out/'all.s').read_text().splitlines(True))))
