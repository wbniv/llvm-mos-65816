#!/usr/bin/env python3
"""Replay retained inputs and compare actual results with expected contracts."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(os.environ.get('REVIEW_ROOT', '/review'))
BUILD = Path('/work/build/repin/20261010T033430Z-ardhs7qy/build-source-3rl8r2dw')
PHASE = sys.argv[1]
MODE = sys.argv[3] if len(sys.argv)>3 else 'all'
assert MODE in ['all','backend','c']
BIN = Path(os.environ.get('REVIEW_BIN', str(BUILD / 'bin')))
OUT = ROOT / 'evidence' / (sys.argv[2] if len(sys.argv)>2 else PHASE)
OUT.mkdir(exist_ok=False)
ROWS = []

def run(name, args, *, expected=0, signature=None, check=None):
    cmd = [str(x) for x in args]
    p = subprocess.run(cmd, capture_output=True)
    (OUT / (name + '.stdout')).write_bytes(p.stdout)
    (OUT / (name + '.stderr')).write_bytes(p.stderr)
    ok = (p.returncode == 0) if expected == 0 else (p.returncode != 0)
    if signature:
        ok = ok and signature.encode() in p.stderr
    row = {'name': name, 'command': cmd, 'exit_code': p.returncode,
           'expected_exit': expected, 'expected_signature': signature, 'pass': ok}
    if check:
        c = subprocess.run([str(BIN / 'FileCheck'), str(ROOT / 'inputs/twoaddr-reschedule-physreg.mir'),
                            '--check-prefixes=' + check], input=p.stdout, capture_output=True)
        (OUT / (name + '-check.stderr')).write_bytes(c.stderr)
        row['filecheck_exit_code'] = c.returncode
        want = 0 if PHASE != 'main' or check.endswith('NOSCHED') else 1
        row['expected_filecheck_exit'] = want
        row['pass'] = row['pass'] and ((c.returncode == 0) if want == 0 else (c.returncode != 0))
    ROWS.append(row)
    return p

baseline = PHASE == 'main'
if MODE != 'c':
    for level in ['0','1','2','3']:
        fail = baseline and level != '0'
        run('retained-ir-O' + level, [BIN/'llc','-mtriple=mos','-mcpu=mos6502','-O'+level,
            '-verify-machineinstrs','-filetype=obj',ROOT/'inputs/mixed-width-call.ll','-o','/dev/null'],
            expected=1 if fail else 0, signature='ran out of registers' if fail else None)

    mir = ROOT / 'inputs/twoaddr-reschedule-physreg.mir'
    for name, passes, check in [('no-analysis','two-address-instruction','CHECK,NOSCHED'),
                               ('liveintervals','liveintervals,two-address-instruction','CHECK,LI')]:
        run(name,[BIN/'llc','-mtriple=mos','-mcpu=mos6502','-run-pass='+passes,
            '-verify-machineinstrs',mir,'-o','-'],check=check)
    run('spare-class-order',[BIN/'FileCheck',mir,'--check-prefix=LI',
        '--input-file='+str(OUT/'liveintervals.stdout')])
    run('allocate',[BIN/'llc','-mtriple=mos','-mcpu=mos6502',
        '-start-after=two-address-instruction','-verify-machineinstrs','-x','mir',
        OUT/'liveintervals.stdout','-o','/dev/null'], expected=1 if baseline else 0,
        signature='ran out of registers' if baseline else None)

    for stage in ['before','after']:
        run('twoaddr-'+stage,[BIN/'llc','-mtriple=mos','-mcpu=mos6502','-O2',
            '-stop-'+stage+'=two-address-instruction',ROOT/'inputs/mixed-width-call.ll','-o','-'])

if MODE != 'backend':
    run('preprocess',[BIN/'clang','--target=mos','-mcpu=mos6502','-E',ROOT/'inputs/mixed-width-call.c','-o','-'])
    for cpu in ['mos6502','mosw65816']:
        for level in ['0','1','2','3','s','z']:
            stem=cpu+'-O'+level
            fail=baseline and level!='0'
            emitted=run(stem+'-emit',[BIN/'clang','--target=mos','-mcpu='+cpu,'-O'+level,
                        '-S','-emit-llvm',ROOT/'inputs/mixed-width-call.c','-o','-'])
            ir=OUT/(stem+'-emit.stdout')
            for verify in [False,True]:
                tag='-verify' if verify else '-normal'
                args=[BIN/'clang','--target=mos','-mcpu='+cpu,'-O'+level]
                if verify: args+=['-mllvm','-verify-machineinstrs']
                run(stem+'-driver'+tag,args+['-c',ROOT/'inputs/mixed-width-call.c','-o','/dev/null'],
                    expected=1 if fail else 0,signature='ran out of registers' if fail else None)
                args=[BIN/'llc','-mtriple=mos','-mcpu='+cpu,'-O'+('2' if level in ['s','z'] else level),'-filetype=obj']
                if verify: args+=['-verify-machineinstrs']
                run(stem+'-backend'+tag,args+[ir,'-o','/dev/null'],expected=1 if fail else 0,
                    signature='ran out of registers' if fail else None)

manifest={'phase':PHASE,'mode':MODE,'upstream_base':'a5c31b24a97cc16c582d124167e29e3da8946581',
    'assertions':False,'build_type':'Release','lto':False,
    'binary_sha256':{name:hashlib.sha256((BIN/name).read_bytes()).hexdigest() for name in (['llc','FileCheck'] if MODE=='backend' else ['llc','clang','FileCheck'])},
    'versions':{name:subprocess.check_output([str(BIN/name),'--version'],text=True) for name in (['llc'] if MODE=='backend' else ['llc','clang'])},
    'inputs_sha256':{p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in (ROOT/'inputs').iterdir() if p.is_file()},
    'runs':ROWS}
(OUT/'results.json').write_text(json.dumps(manifest,indent=2)+'\n')
print(json.dumps({'phase':PHASE,'checks':len(ROWS),'unexpected':[r for r in ROWS if not r['pass']]},indent=2))
sys.exit(any(not row['pass'] for row in ROWS))
