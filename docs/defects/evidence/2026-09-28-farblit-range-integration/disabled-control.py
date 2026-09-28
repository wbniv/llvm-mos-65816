from pathlib import Path
import subprocess,json,hashlib
root=Path.cwd();w=root/'.scratch/farblit-range-integration';rows=[];seen=set()
for c in json.loads((w/'baseline-commands.json').read_text()):
 if c['status'] or not c['log'].endswith(('-compile.log','-lto.log')):continue
 cmd=[x.replace(str(w/'baseline/bin/mos-clang'),str(root/'build/llvm-mos-install/bin/mos-clang')).replace('/runs/baseline-','/runs/disabled-') for x in c['command']]
 output=Path(cmd[cmd.index('-o')+1]);reference=Path(str(output).replace('/runs/disabled-','/runs/baseline-'))
 if output in seen:continue
 seen.add(output)
 cmd+=['-mllvm','-mos-far-loop-range=false']
 if output.suffix=='.sfc':cmd+=['-Wl,--mllvm=-mos-far-loop-range=false']
 p=subprocess.run(cmd,capture_output=True,text=True);(w/'runs'/('disabled-'+c['log'].removeprefix('baseline-'))).write_text(p.stdout+p.stderr);assert p.returncode==0,p.stderr
 if output.suffix=='.sfc':subprocess.run(['python3','tools/snes-checksum.py',*(['--hirom'] if '-farblit_press-' not in output.name else []),str(output)],check=True,capture_output=True)
 assert output.read_bytes()==reference.read_bytes(),str(output)
 rows.append(dict(command=cmd,output=str(output.relative_to(root)),reference=str(reference.relative_to(root)),sha256=hashlib.sha256(output.read_bytes()).hexdigest(),identical=True))
 (w/'disabled-control.json').write_text(json.dumps(rows,indent=2)+'\n')
 print(output.name,'identical',flush=True)
