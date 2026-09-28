from pathlib import Path
import subprocess,json
w=Path('.scratch/far-word-policy');rows=[]
for mode in ['a16','xy16']:
 for policy,prefix in [('off','OFF'),('speed','SPEED'),('all','ALL')]:
  name=mode+'-'+policy
  cmd=[str(w/'candidate/bin/llc'),'-mtriple=mos','-mcpu=mosw65816','-mattr=+mos-a16'+(',+mos-xy16' if mode=='xy16' else ''),'-mos-far-word-index='+policy,'-run-pass=legalizer','-verify-machineinstrs',str(w/'source/far-word-policy.mir'),'-o','-']
  p=subprocess.run(cmd,text=True,capture_output=True);(w/(name+'-tests.mir')).write_text(p.stdout);(w/(name+'-tests.log')).write_text(p.stderr)
  c=subprocess.run([str(w/'candidate/bin/FileCheck'),str(w/'source/far-word-policy.mir'),'--check-prefix='+prefix],input=p.stdout,text=True,capture_output=True)
  (w/(name+'-checks.log')).write_text(c.stdout+c.stderr);rows.append(dict(command=cmd,compiler=p.returncode,check=c.returncode))
  print(name,p.returncode,c.returncode,c.stderr[:400]);assert not p.returncode and not c.returncode
(w/'focused-tests.json').write_text(json.dumps(rows,indent=2)+'\n')
