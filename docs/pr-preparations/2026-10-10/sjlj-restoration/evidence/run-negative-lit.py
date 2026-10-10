from pathlib import Path
import subprocess,os,json
r=Path.cwd(); d=r/'.scratch/sjlj-restoration'; source=d/'test-suite'; sdk=d/'llvm-mos'; results=[]
b=d/'mos-unfixed-O3'
cfg=['cmake','-S',str(source),'-B',str(b),'-G','Ninja','-DLLVM_MOS='+str(sdk),'-C',str(source/'cmake/caches/O3.cmake'),'-C',str(source/'cmake/caches/target-mos.cmake'),'-DTEST_SUITE_SUBDIRS=SingleSource','-DTEST_SUITE_RUN_UNDER=timeout 2 '+str(sdk/'bin/mos-sim')]
with (d/'mos-unfixed-O3.configure.log').open('w') as f: subprocess.run(cfg,stdout=f,stderr=subprocess.STDOUT,check=True)
with (d/'mos-unfixed-O3.build.log').open('w') as f: subprocess.run(['cmake','--build',str(b),'--target','FarJump','Looping','MultipleSetjmp','SimpleCTest','WhileLoop','longjmp-zero','build-fpcmp','build-timeit'],stdout=f,stderr=subprocess.STDOUT,check=True)
cmd=[str(r/'build/llvm-mos/bin/llvm-lit'),'-v','--timeout=5',str(b/'SingleSource/UnitTests/SetjmpLongjmp'),str(b/'SingleSource/UnitTests/longjmp-zero.test')]
with (d/'mos-unfixed-O3.lit.log').open('w') as f: run=subprocess.run(cmd,stdout=f,stderr=subprocess.STDOUT,env={**os.environ,'PYTHONDONTWRITEBYTECODE':'1'})
log=(d/'mos-unfixed-O3.lit.log').read_text()
assert run.returncode==1 and 'Passed: 4' in log and 'Failed: 2' in log
results.append({'kind':'unfixed SDK','command':cmd,'exit_code':run.returncode,'passed':4,'failed':2})
print('Unfixed SDK: four pass, WhileLoop and longjmp-zero fail',flush=True)
b=d/'host-O3'
for ref in sorted((b/'SingleSource/UnitTests').rglob('*.reference_output')):
 if 'SetjmpLongjmp' not in str(ref) and ref.stem!='longjmp-zero': continue
 saved=ref.read_bytes()
 try:
  ref.write_bytes(saved.replace(b'exit 0\n',b'exit 1\n'))
  test=ref.with_suffix('.test')
  cmd=[str(r/'build/llvm-mos/bin/llvm-lit'),'-v',str(test)]
  out=subprocess.run(cmd,capture_output=True,text=True,env={**os.environ,'PYTHONDONTWRITEBYTECODE':'1'})
  assert out.returncode==1 and 'Failed: 1' in out.stdout
  (d/(ref.stem+'.wrong-reference.log')).write_text(out.stdout+out.stderr)
  results.append({'kind':'wrong exit oracle','test':str(test),'exit_code':out.returncode})
  print('Rejected incorrect reference:',ref.stem,flush=True)
 finally: ref.write_bytes(saved)
(d/'negative-lit.json').write_text(json.dumps(results,indent=2)+'\n')
