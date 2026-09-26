#!/usr/bin/env python3
"""Compare MIR fallback and IR parallel behavior on isolated reducer binaries."""
import hashlib
import json
import resource
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = Path(__file__).resolve().parent
resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
rows = []
fc = str(ROOT / 'build/llvm-mos/bin/FileCheck')
mir = str(ROOT / 'docs/defects/evidence/2026-09-25-llvm-reduce-parallel-mir/parallel-instr-reduce.mir')


def run(name, command, expected, check=None):
    proc = subprocess.run(command, cwd=ROOT, capture_output=True, timeout=150)
    (OUT / (name + '.log')).write_bytes(proc.stdout + proc.stderr)
    row = {'name': name, 'command': command, 'returncode': proc.returncode,
           'expected': expected, 'matches_expectation': proc.returncode == expected}
    if check and proc.returncode == 0:
        checked = subprocess.run(check, cwd=ROOT, capture_output=True, timeout=30)
        (OUT / (name + '-check.log')).write_bytes(checked.stdout + checked.stderr)
        row.update({'check_command': check, 'check_returncode': checked.returncode})
    rows.append(row)
    print(name, proc.returncode, row.get('check_returncode', ''), flush=True)


for variant, jobs, expected in [('baseline', 1, 0), ('baseline', 2, -11),
                               ('serial', 1, 0), ('serial', 2, 0),
                               ('serial', 4, 0), ('serial', 16, 0)]:
    name = 'matched-' + variant + '-j' + str(jobs)
    output = str(OUT / (name + '.mir'))
    run(name, [str(OUT / ('llvm-reduce-' + variant)), '-x=mir', '-j', str(jobs),
        '--delta-passes=instructions', '--test', fc,
        '--test-arg', '--check-prefix=INTERESTING', '--test-arg', mir,
        '--test-arg', '--input-file', mir, '-o', output], expected,
        [fc, '--check-prefix=CHECK', mir, '--input-file', output])

original = str(ROOT / 'docs/defects/evidence/2026-09-25-coalescing-0015/stock-identity-copy-model.mir')
interesting = str(ROOT / 'docs/defects/evidence/2026-09-25-coalescing-0015/interesting-rewriter.py')
run('matched-serial-original', [str(OUT / 'llvm-reduce-serial'), '-x=mir', '-j', '2',
    '--max-pass-iterations=1', '--test=/usr/bin/python3', '--test-arg=' + interesting,
    original, '-o', str(OUT / 'matched-serial-original.mir')], 0,
    ['/usr/bin/python3', interesting, str(OUT / 'matched-serial-original.mir')])

ir = str(ROOT / 'vendor/llvm-mos/llvm/test/tools/llvm-reduce/parallel-workitem-kill.ll')
ir_test = str(ROOT / 'vendor/llvm-mos/llvm/test/tools/llvm-reduce/Inputs/sleep-and-check-stores.py')
run('matched-serial-parallel-ir', [str(OUT / 'llvm-reduce-serial'), '-j', '4', ir,
    '-o', str(OUT / 'matched-serial-parallel-ir.ll'), '--abort-on-invalid-reduction',
    '--delta-passes=instructions', '--test', '/usr/bin/python3',
    '--test-arg', ir_test, '--test-arg', '1', '--test-arg', '5'], 0,
    [fc, ir, '--input-file', str(OUT / 'matched-serial-parallel-ir.ll')])

hashes = {path.name: hashlib.file_digest(open(path, 'rb'), 'sha256').hexdigest()
    for path in OUT.glob('matched-*.mir')}
(OUT / 'serial-tests.json').write_text(json.dumps({'runs': rows, 'output_sha256': hashes}, indent=2) + '\n')
assert all(row['matches_expectation'] and row.get('check_returncode', 0) == 0 for row in rows)
assert len({hashes['matched-serial-j' + str(jobs) + '.mir'] for jobs in [1, 2, 4, 16]}) == 1
