from pathlib import Path
import subprocess,re,shlex,json
root=Path.cwd();d=root/'.scratch/upstream-pin-2026-10-09';src=d/'source';check=d/'bootstrap15';check.mkdir(exist_ok=True)
def git(*args,**kw):return subprocess.run(['git','-C',str(check),*args],check=True,**kw)
git('init','-q');(check/'.git/objects/info/alternates').write_text(str(src/'.git/objects')+'\n')
commands=[];paths=set()
for l in (root/'dev/toolchain.sh').read_text().replace('\\\n',' ').splitlines():
 if re.match(r'^  apply_patch ',l):
  w=shlex.split(l);commands.append((w[1],w[2:]));p=root/'patches/llvm-mos'/f'{w[1]}.patch'
  for line in p.read_text().splitlines():
   if line.startswith('diff --git '):paths.add(shlex.split(line)[2][2:])
   if line.startswith('--- a/'):paths.add(line[6:].split('\t')[0])
git('config','core.sparseCheckout','true');(check/'.git/info/sparse-checkout').write_text('\n'.join('/'+p for p in sorted(paths))+'\n');git('update-ref','HEAD','f24948c7d1a4b9f162d4d0192ccceecab1e441ff');git('read-tree','-mu','HEAD')
for name,args in commands:
 patch=root/'patches/llvm-mos'/f'{name}.patch'
 if not patch.stat().st_size:raise RuntimeError(f'Empty patch {name}')
 git('apply',*args,str(patch));print(name,flush=True)
results=[]
for p in sorted(paths):
 a=check/p;b=src/p
 if a.exists()!=b.exists() or (a.exists() and a.read_bytes()!=b.read_bytes()):results.append(p)
print('Mismatches:',results)
(d/'bootstrap-verification.json').write_text(json.dumps({'pin':'f24948c7d1a4b9f162d4d0192ccceecab1e441ff','patch_count':len(commands),'mismatches':results},indent=2)+'\n')
if results:raise SystemExit(1)
