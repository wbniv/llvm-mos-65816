from pathlib import Path
import subprocess,json,shlex,resource,hashlib
resource.setrlimit(resource.RLIMIT_CORE,(0,0));r=Path.cwd();e=r/'docs/defects/evidence/2026-09-25-coalescing-0015';d=e/'native-c';d.mkdir(exist_ok=True);clang=r/'build/llvm-mos-install/bin/clang';src=e/'original/rcundef.c';results=[]
compilers={'guard':r/'build/llvm-mos/bin/llc','noguard':r/'build/coalescing-0015-contrast/llc'}
for mode,features in [('default',''),('a16','+mos-a16'),('xy16','+mos-a16,+mos-xy16')]:
 for opt in ['O0','O1','O2','O3','Os','Oz']:
  stem=mode+'-'+opt;flags=['--target=mos','-mcpu=mosw65816','-'+opt,'-fno-lto']
  for feat in features.split(',') if features else []:flags+=['-Xclang','-target-feature','-Xclang',feat]
  commands=[]
  for step,extra,suffix in [('preprocess',['-E'],'.i'),('ir',['-S','-emit-llvm'],'.ll')]:
   cmd=[str(clang),*flags,*extra,str(src),'-o',str(d/(stem+suffix))];p=subprocess.run(cmd,capture_output=True,text=True);assert p.returncode==0,p.stderr;commands.append(shlex.join(cmd))
  for name,llc in compilers.items():
   cmd=[str(llc),'-mtriple=mos','-mcpu=mosw65816',('-O2' if opt in ['Os','Oz'] else '-'+opt),'-verify-machineinstrs',str(d/(stem+'.ll')),'-o',str(d/(stem+'-'+name+'.s'))];p=subprocess.run(cmd,capture_output=True,text=True);(d/(stem+'-'+name+'.log')).write_text('$ '+shlex.join(cmd)+'\n'+p.stdout+p.stderr+'exit_code='+str(p.returncode)+'\n');results.append({'mode':mode,'opt':opt,'compiler':name,'exit':p.returncode,'frontend_commands':commands,'command':shlex.join(cmd)});print(mode,opt,name,p.returncode,flush=True)
(e/'native-c-results.json').write_text(json.dumps(results,indent=2)+'\n')
