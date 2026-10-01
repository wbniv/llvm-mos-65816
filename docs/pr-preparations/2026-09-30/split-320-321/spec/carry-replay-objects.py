#!/usr/bin/env python3
"""Recompile the far-word packet's 58 frozen post-LTO IR configurations.

usage: carry-replay-objects.py PRE0070_LLC CANDIDATE_LLC RESULTS_JSON OUT_DIR
  PRE0070_LLC    llc for the `baseline` variant (far-word patches through 11)
  CANDIDATE_LLC  llc for the `default` and `all` variants (patches through 14)
  RESULTS_JSON   the packet's evidence/runtime-results.json (recorded objects)
  OUT_DIR        objects, logs and objects.json land here
Uses exactly the llc arguments of the packet's runtime.py and compares each
object's sha256 with the recorded one. Run inside the dev container. Each llc
runs with ulimit -c 0, ulimit -v 2000000 and a 180 s timeout, three at a time.
"""
import concurrent.futures as cf, hashlib, json, os, subprocess, sys

if len(sys.argv) != 5 or sys.argv[1] in ('-h', '--help'):
    print(__doc__.strip()); sys.exit(0)
pre, cand, results, out = sys.argv[1:]
os.makedirs(out, exist_ok=True)
runs = '/work/.scratch/far-word-policy/runs'
rec = json.load(open(results))


def job(r):
    stem = '-'.join([r['fixture'], r['mode'], r['opt']])
    ir = f'{runs}/baseline-{stem}.sfc.0.5.precodegen.bc'
    name = r['variant'] + '-' + stem
    llc = pre if r['variant'] == 'baseline' else cand
    attrs = '+mos-a16,+mos-xy16' if r['mode'] == 'xy16' else '+mos-a16'
    args = [llc, '-mtriple=mos', '-mcpu=mosw65816', '-mattr=' + attrs, '-verify-machineinstrs',
            '-disable-spill-hoist', '-O3' if r['opt'] == 'O3' else '-O2', '-filetype=obj']
    if r['variant'] == 'all':
        args.append('-mos-far-word-index=all')
    obj = f'{out}/{name}.o'
    p = subprocess.run(['bash', '-c', 'ulimit -c 0; ulimit -v 2000000; exec timeout 180 "$@"', '_',
                        *args, ir, '-o', obj], capture_output=True, text=True)
    open(f'{out}/{name}.log', 'w').write(p.stdout + p.stderr)
    h = hashlib.sha256(open(obj, 'rb').read()).hexdigest() if p.returncode == 0 else None
    return dict(name=name, fixture=r['fixture'], mode=r['mode'], opt=r['opt'], variant=r['variant'],
                exit_code=p.returncode, object_sha256=h, recorded_sha256=r['object_sha256'],
                identical=h == r['object_sha256'])


with cf.ThreadPoolExecutor(3) as ex:
    rows = list(ex.map(job, rec))
json.dump(dict(pre0070_llc=pre, candidate_llc=cand,
               pre0070_sha256=hashlib.sha256(open(pre, 'rb').read()).hexdigest(),
               candidate_sha256=hashlib.sha256(open(cand, 'rb').read()).hexdigest(),
               inputs=runs, rows=rows), open(f'{out}/objects.json', 'w'), indent=1)
same = sum(r['identical'] for r in rows)
print(f'{len(rows)} configurations: {same} identical to the recorded objects, '
      f'{len(rows) - same} different, {sum(r["exit_code"] != 0 for r in rows)} failed')
for r in rows:
    if not r['identical']:
        print('  DIFF', r['name'], 'exit', r['exit_code'])
