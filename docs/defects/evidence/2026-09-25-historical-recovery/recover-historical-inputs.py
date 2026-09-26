from pathlib import Path
import re,json,subprocess,shlex,resource
resource.setrlimit(resource.RLIMIT_CORE,(0,0))
r=Path.cwd();e=r/'docs/defects/evidence/2026-09-25-historical-recovery';files={}
def apply(n):
 lines=(e/f'patch-{n}.txt').read_text().splitlines();i=1
 while i<len(lines) and lines[i]!='*** End Patch':
  line=lines[i];kind='Add' if line.startswith('*** Add File: ') else 'Update';path=line.split(': ',1)[1].removeprefix(str(r)+'/');i+=1;body=[]
  while i<len(lines) and not lines[i].startswith('*** '):body.append(lines[i]);i+=1
  if kind=='Add':
   assert path not in files; assert all(x.startswith('+') for x in body);files[path]='\n'.join(x[1:] for x in body)+'\n';continue
  hunks=[]
  for l in body:
   if l.startswith('@@'):hunks.append([])
   else:hunks[-1].append(l)
  cursor=0
  for hunk in hunks:
   old='\n'.join(l[1:] for l in hunk if l.startswith((' ','-')))+'\n';new='\n'.join(l[1:] for l in hunk if l.startswith((' ','+')))+'\n'
   pos=files[path].find(old,cursor);assert pos>=0,(n,path,old);files[path]=files[path][:pos]+new+files[path][pos+len(old):];cursor=pos+len(new)
def save(name):
 for path,s in files.items():
  p=e/name/path;p.parent.mkdir(parents=True,exist_ok=True);p.write_text(s)
for n in [437,453,465]:apply(n)
save('shift-stage')
for n in [475,480]:apply(n)
save('inline-stage')
for stage in ['shift-stage','inline-stage']:
 p=e/stage/'examples/65816/bitboard64-probe.c';log=e/f'{stage}-current.log'
 cmd=[str(r/'build/llvm-mos-install/bin/mos-clang'),'--target=mos','-mcpu=mosw65816','-Xclang','-target-feature','-Xclang','+mos-a16','-Os','-fno-lto','-mllvm','-verify-machineinstrs','-c',str(p),'-o','/dev/null']
 x=subprocess.run(cmd,capture_output=True,text=True);log.write_text('$ '+shlex.join(cmd)+'\n'+x.stdout+x.stderr+f'\nexit_code={x.returncode}\n');print(stage,x.returncode,x.stderr[:1000])
