from pathlib import Path
import subprocess,json,os
r=Path.cwd(); d=r/'.scratch/sjlj-restoration'; source=d/'test-suite'; sdk=d/'llvm-mos'; results=[]
for opt in ['O0','O3','Os','Oz']:
 b=d/('mos-fixed-'+opt)
 configure=['cmake','-S',str(source),'-B',str(b),'-G','Ninja','-DLLVM_MOS='+str(sdk),'-C',str(source/'cmake/caches'/f'{opt}.cmake'),'-C',str(source/'cmake/caches/target-mos.cmake'),'-DTEST_SUITE_SUBDIRS=SingleSource','-DCMAKE_EXE_LINKER_FLAGS='+str(d/'setjmp-fixed.o')]
 with (d/(b.name+'.configure.log')).open('w') as log:
  subprocess.run(configure,stdout=log,stderr=subprocess.STDOUT,check=True)
 with (d/(b.name+'.build.log')).open('w') as log:
  subprocess.run(['cmake','--build',str(b),'--target','FarJump','Looping','MultipleSetjmp','SimpleCTest','WhileLoop','longjmp-zero','build-fpcmp','build-timeit'],stdout=log,stderr=subprocess.STDOUT,check=True)
 cmd=[str(r/'build/llvm-mos/bin/llvm-lit'),'-v','--timeout=10',str(b/'SingleSource/UnitTests/SetjmpLongjmp'),str(b/'SingleSource/UnitTests/longjmp-zero.test')]
 with (d/(b.name+'.lit.log')).open('w') as log:
  run=subprocess.run(cmd,stdout=log,stderr=subprocess.STDOUT,env={**os.environ,'PYTHONDONTWRITEBYTECODE':'1'})
 results.append({'opt':opt,'configure':configure,'lit':cmd,'exit_code':run.returncode})
 print(opt,'lit exit',run.returncode,flush=True)
(d/'mos-fixed-lit.json').write_text(json.dumps(results,indent=2)+'\n')
