from pathlib import Path
import subprocess,resource,shlex,json
resource.setrlimit(resource.RLIMIT_CORE,(0,0));r=Path.cwd();e=r/'docs/defects/evidence/2026-09-25-historical-recovery';b=r/'build/defect-baselines/2026-09-25-historical-recovery/bin';o=e/'replay';o.mkdir(exist_ok=True);runs=[]
def run(name,cmd,expect=None):
 p=subprocess.run(list(map(str,cmd)),capture_output=True,text=True);(o/f'{name}.log').write_text('$ '+shlex.join(map(str,cmd))+'\n'+p.stdout+p.stderr+f'\nexit_code={p.returncode}\n');runs.append({'name':name,'command':list(map(str,cmd)),'exit_code':p.returncode});print(name,p.returncode,flush=True)
 if expect is not None:assert p.returncode==expect
for stage in ['shift-stage','inline-stage']:
 src=e/stage/'examples/65816/bitboard64-probe.c';common=[b/'clang','--target=mos','-mcpu=mosw65816','-Xclang','-target-feature','-Xclang','+mos-a16','-Os','-fno-lto']
 run(stage+'-preprocess',common+['-E',src,'-o',o/f'{stage}.i'],0)
 run(stage+'-ir',common+['-S','-emit-llvm',src,'-o',o/f'{stage}.ll'],0)
 run(stage+'-preprocessed-valid',common+['-x','cpp-output','-mllvm','-verify-machineinstrs','-c',o/f'{stage}.i','-o','/dev/null'],1 if stage=='shift-stage' else 0)
 run(stage+'-mir',[b/'llc','-mcpu=mosw65816','-mattr=+mos-a16','-O2','-stop-before=legalizer',o/f'{stage}.ll','-o',o/f'{stage}-prelegalizer.mir'],0)
 run(stage+'-llc',[b/'llc','-mcpu=mosw65816','-mattr=+mos-a16','-O2','-verify-machineinstrs',o/f'{stage}.ll','-o','/dev/null'],None)
(o/'runs.json').write_text(json.dumps(runs,indent=2)+'\n')
