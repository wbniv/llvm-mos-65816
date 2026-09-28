from pathlib import Path
import subprocess,json,hashlib
root=Path.cwd();w=root/'.scratch/far-word-policy';rows=[]
commands=json.loads((w/'default-commands.json').read_text())
for c in commands:
 if c['status'] or not c['log'].endswith(('-compile.log','-lto.log')):continue
 cmd=[x.replace(str(w/'policy/bin/mos-clang'),str(root/'build/llvm-mos-install/bin/mos-clang')).replace('/runs/default-','/runs/installed-') for x in c['command']]
 output=Path(cmd[cmd.index('-o')+1]);reference=Path(str(output).replace('/runs/installed-','/runs/default-'))
 p=subprocess.run(cmd,capture_output=True,text=True);(w/'runs'/('installed-'+c['log'].removeprefix('default-'))).write_text(p.stdout+p.stderr);assert p.returncode==0,p.stderr
 if output.suffix=='.sfc':
  chk=['python3','tools/snes-checksum.py']+(['--hirom'] if '-farblit_press-' not in output.name else [])+[str(output)]
  subprocess.run(chk,check=True,capture_output=True)
 assert output.read_bytes()==reference.read_bytes(),str(output)
 rows.append(dict(command=cmd,output=str(output.relative_to(root)),reference=str(reference.relative_to(root)),sha256=hashlib.sha256(output.read_bytes()).hexdigest(),identical=True))
 (w/'installed-control.json').write_text(json.dumps(rows,indent=2)+'\n')
 print(output.name,'identical',flush=True)
