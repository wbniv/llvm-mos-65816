import hashlib,json,subprocess,sys
from pathlib import Path
phase=sys.argv[1]
out=Path('/work/docs/pr-preparations/2026-10-10/0029/evidence')
bin=Path('/work/build/0029-20261010/baseline/bin') if phase.startswith('baseline') else Path('/work/build/repin/20261010T033430Z-ardhs7qy/build-source-3rl8r2dw/bin')
mir=out/(sys.argv[2] if len(sys.argv)>2 else 'twoaddr-reschedule-physreg.mir')
rows=[]
def run(name,args,check_args=None):
 p=subprocess.run([str(x) for x in args],capture_output=True)
 (out/f'{phase}-{name}.stdout').write_bytes(p.stdout)
 (out/f'{phase}-{name}.log').write_bytes(p.stderr)
 row={'name':name,'command':[str(x) for x in args],'exit_code':p.returncode}
 if check_args:
  c=subprocess.run([str(bin/'FileCheck'),str(mir),*check_args],input=p.stdout,capture_output=True)
  (out/f'{phase}-{name}-check.log').write_bytes(c.stdout+c.stderr)
  row['check_command']=[str(bin/'FileCheck'),str(mir),*check_args];row['check_exit_code']=c.returncode
 rows.append(row)
 return p.returncode
version=subprocess.check_output([bin/'llc','--version']).decode()
for opt in [0,1,2,3]:
 run(f'ir-O{opt}',[bin/'llc','-mtriple=mos','-mcpu=mos6502',f'-O{opt}','-verify-machineinstrs','-filetype=obj',out/'mixed-width-call.ll','-o',out/f'{phase}-ir-O{opt}.o'])
for name,passes,prefix in [('no-analysis','twoaddressinstruction','CHECK,NOSCHED'),('liveintervals','liveintervals,twoaddressinstruction','CHECK,LI')]:
 run(name,[bin/'llc','-mtriple=mos','-mcpu=mos6502','-run-pass='+passes,'-verify-machineinstrs','-o','-',mir],['--check-prefixes='+prefix])
run('mir-allocated', [bin/'llc','-mtriple=mos','-mcpu=mos6502','-start-after=twoaddressinstruction','-verify-machineinstrs','-x','mir','-o','/dev/null',out/f'{phase}-liveintervals.stdout'])
run('mir-full',[bin/'llc','-mtriple=mos','-mcpu=mos6502','-start-before=twoaddressinstruction','-verify-machineinstrs','-o','/dev/null',mir])
for stage in ['before','after']:
 run('twoaddr-'+stage,[bin/'llc','-mtriple=mos','-mcpu=mos6502','-O2','-stop-'+stage+'=twoaddressinstruction',out/'mixed-width-call.ll','-o',out/f'{phase}-twoaddr-{stage}.mir'])
identity={'phase':phase,'source_base':'0f031168a7cc8e81b7b40c0ec0b1f7b3c90b8a63','build':'Release','assertions':False,'lto':False,'version':version,'binary_sha256':{str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in bin.iterdir() if p.name in ['llc','FileCheck','opt']},'runs':rows}
(out/f'{phase}-backend.json').write_text(json.dumps(identity,indent=2)+'\n')
print(json.dumps([(r['name'],r['exit_code'],r.get('check_exit_code')) for r in rows]),flush=True)
