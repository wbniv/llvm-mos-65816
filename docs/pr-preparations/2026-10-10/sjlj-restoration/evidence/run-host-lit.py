import subprocess,os,json
from pathlib import Path
r=Path.cwd(); d=r/'.scratch/sjlj-restoration'; s=d/'test-suite'; results=[]
for opt in ['O0','O3','Os','Oz']:
 b=d/('host-'+opt)
 cfg=['cmake','-S',str(s),'-B',str(b),'-G','Ninja','-C',str(s/'cmake/caches'/f'{opt}.cmake'),'-DTEST_SUITE_SUBDIRS=SingleSource','-DTEST_SUITE_COLLECT_CODE_SIZE=OFF']
 with (d/(b.name+'.configure.log')).open('w') as log:
  subprocess.run(cfg,stdout=log,stderr=subprocess.STDOUT,check=True)
 with (d/(b.name+'.build.log')).open('w') as log:
  subprocess.run(['cmake','--build',str(b),'--target','FarJump','Looping','MultipleSetjmp','SimpleCTest','WhileLoop','C++Catch','longjmp-zero','build-fpcmp','build-timeit'],stdout=log,stderr=subprocess.STDOUT,check=True)
 cmd=[str(r/'build/llvm-mos/bin/llvm-lit'),'-v','--timeout=10',str(b/'SingleSource/UnitTests/SetjmpLongjmp'),str(b/'SingleSource/UnitTests/longjmp-zero.test')]
 with (d/(b.name+'.lit.log')).open('w') as log:
  run=subprocess.run(cmd,stdout=log,stderr=subprocess.STDOUT,env={**os.environ,'PYTHONDONTWRITEBYTECODE':'1'})
 results.append({'opt':opt,'configure':cfg,'lit':cmd,'exit_code':run.returncode})
 print('host',opt,run.returncode,flush=True)
(d/'host-lit.json').write_text(json.dumps(results,indent=2)+'\n')
