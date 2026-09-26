from pathlib import Path
import subprocess,json,shlex,resource
resource.setrlimit(resource.RLIMIT_CORE,(0,0));r=Path.cwd();e=r/'docs/defects/evidence/2026-09-25-coalescing-0015';d=e/'stock-c';d.mkdir(exist_ok=True);b=r/'build/upstream-reference/742d554bf08042b8df93d791c335260fadd16643/bin';src=e/'original/rcundef.c';results=[]
for cpu in ['mos6502','mosw65816']:
 for opt in ['O0','O1','O2','O3','Os','Oz']:
  stem=cpu+'-'+opt;flags=['--target=mos','-mcpu='+cpu,'-'+opt,'-fno-lto'];cmd=[str(b/'clang'),*flags,'-E',str(src),'-o',str(d/(stem+'.i'))];p=subprocess.run(cmd,capture_output=True,text=True);assert p.returncode==0,p.stderr
  cmd=[str(b/'clang'),*flags,'-S','-emit-llvm',str(src),'-o',str(d/(stem+'.ll'))];p=subprocess.run(cmd,capture_output=True,text=True);assert p.returncode==0,p.stderr
  for stage,extra in [('rewrite',['-stop-after=virtregrewriter']),('full',[])]:
   out=d/(stem+'-'+stage+'.out');cmd=[str(b/'llc'),'-mtriple=mos','-mcpu='+cpu,'-'+opt,'-verify-machineinstrs',*extra,str(d/(stem+'.ll')),'-o',str(out)];p=subprocess.run(cmd,capture_output=True,text=True);(d/(stem+'-'+stage+'.log')).write_text('$ '+shlex.join(cmd)+'\n'+p.stdout+p.stderr+'exit_code='+str(p.returncode)+'\n');results.append({'cpu':cpu,'opt':opt,'stage':stage,'exit':p.returncode,'command':shlex.join(cmd)});print(cpu,opt,stage,p.returncode,flush=True)
(e/'stock-c-results.json').write_text(json.dumps(results,indent=2)+'\n')
