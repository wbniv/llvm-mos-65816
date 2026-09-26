#!/usr/bin/env python3
"""Replay retained regressions without changing their source or tool binaries."""
import hashlib
import json
import resource
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = Path(__file__).resolve().parent
resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
rows = []


def run(name, command, expected, check=None):
    proc = subprocess.run(command, cwd=ROOT, capture_output=True, timeout=120)
    (OUT / (name + '.log')).write_bytes(proc.stdout + proc.stderr)
    row = {'name': name, 'command': command, 'returncode': proc.returncode,
           'expected': expected, 'matches_expectation': proc.returncode == expected}
    if check and proc.returncode == 0:
        checked = subprocess.run(check, cwd=ROOT, capture_output=True, timeout=30)
        (OUT / (name + '-check.log')).write_bytes(checked.stdout + checked.stderr)
        row['check_command'] = check
        row['check_returncode'] = checked.returncode
    rows.append(row)
    print(name, proc.returncode, row.get('check_returncode', ''), flush=True)


fc = str(ROOT / 'build/llvm-mos/bin/FileCheck')
mir = str(ROOT / 'docs/defects/evidence/2026-09-25-llvm-reduce-parallel-mir/parallel-instr-reduce.mir')
for variant, tool, jobs, expected in (
    ('baseline-j2', 'build/defect-baselines/2026-09-25-coalescing-0015/bin/llvm-reduce', 2, -11),
    ('candidate-j2', 'build/defect-candidates/2026-09-25-llvm-reduce-parallel-mir/bin/llvm-reduce', 2, 0),
    ('candidate-j4', 'build/defect-candidates/2026-09-25-llvm-reduce-parallel-mir/bin/llvm-reduce', 4, 0),
    ('candidate-j16', 'build/defect-candidates/2026-09-25-llvm-reduce-parallel-mir/bin/llvm-reduce', 16, 0),
):
    output = str(OUT / (variant + '.mir'))
    run(variant, [str(ROOT / tool), '-x=mir', '-j', str(jobs),
                  '--delta-passes=instructions', '--test', fc,
                  '--test-arg', '--check-prefix=INTERESTING', '--test-arg', mir,
                  '--test-arg', '--input-file', mir, '-o', output], expected,
        [fc, '--check-prefix=CHECK', mir, '--input-file', output])

reference = str(ROOT / 'build/upstream-reference/742d554bf08042b8df93d791c335260fadd16643/bin/llc')
scavenger = str(ROOT / 'vendor/llvm-mos/llvm/test/CodeGen/MOS/scavenger-status-save-range.mir')
run('0054-stock-no-native', [reference, '-mtriple=mos', '-mcpu=mosw65816',
    '-run-pass=prologepilog', '-verify-machineinstrs', scavenger,
    '-o', str(OUT / '0054-stock-no-native.mir')], 0)
run('0054-stock-current-pass', [reference, '-mtriple=mos', '-mcpu=mosw65816',
    '-run-pass=prolog-epilog', '-verify-machineinstrs', scavenger,
    '-o', str(OUT / '0054-stock-current-pass.mir')], 0)
identities = {}
for path in [fc, mir, reference, scavenger,
             str(ROOT / 'patches/llvm-mos/0060-llvm-reduce-parallel-mir.patch'),
             str(ROOT / 'build/defect-baselines/2026-09-25-coalescing-0015/bin/llvm-reduce'),
             str(ROOT / 'build/defect-candidates/2026-09-25-llvm-reduce-parallel-mir/bin/llvm-reduce')]:
    identities[path] = hashlib.file_digest(open(path, 'rb'), 'sha256').hexdigest()
(OUT / 'results.json').write_text(json.dumps({'runs': rows, 'identities': identities}, indent=2) + '\n')
