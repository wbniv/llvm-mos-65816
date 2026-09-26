#!/usr/bin/env python3
"""Replay native-fix controls into a new review evidence directory."""
import hashlib
import json
import resource
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = Path(__file__).resolve().parent / 'native-checks'
OUT.mkdir(exist_ok=False)
resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
runs = []
tools = {}


def sha(path):
    return hashlib.file_digest(open(path, 'rb'), 'sha256').hexdigest()


def run(name, argv, stdin=None):
    argv = [str(x) for x in argv]
    tool = Path(argv[0])
    if tool.is_file():
        tools[str(tool)] = sha(tool)
    p = subprocess.run(argv, cwd=ROOT, input=stdin, capture_output=True, timeout=150)
    log = OUT / (name + '.log')
    log.write_bytes(p.stdout + p.stderr)
    runs.append({'name': name, 'argv': argv, 'returncode': p.returncode,
                 'log': str(log), 'log_sha256': sha(log)})
    print(name, p.returncode, flush=True)
    return p


refdir = ROOT / 'build/upstream-reference/742d554bf08042b8df93d791c335260fadd16643/bin'
curdir = ROOT / 'build/llvm-mos/bin'
fc = curdir / 'FileCheck'
mir = OUT.parent / 'native-immediates.mir'
comparisons = []
for label, bindir, passname in [('stock', refdir, 'prolog-epilog'),
                              ('fixed-fork', curdir, 'prologepilog')]:
    base = [bindir / 'llc', '-mtriple=mos', '-mcpu=mosw65816',
            '-start-after=' + passname, '-verify-machineinstrs', mir]
    assembly = OUT / (label + '.s')
    direct = OUT / (label + '-direct.o')
    reassembled = OUT / (label + '-reassembled.o')
    run(label + '-asm', [*base, '-o', assembly])
    run(label + '-asm-check', [fc, mir, '--input-file', assembly])
    run(label + '-direct-object', [*base, '-filetype=obj', '-o', direct])
    run(label + '-reassemble', [bindir / 'llvm-mc', '-triple=mos', '-mcpu=mosw65816',
        '-filetype=obj', assembly, '-o', reassembled])
    for suffix, obj in [('direct', direct), ('reassembled', reassembled)]:
        run(label + '-extract-' + suffix, [curdir / 'llvm-objcopy', '-O', 'binary',
            '--only-section=.text', obj, OUT / (label + '-' + suffix + '.bin')])
    a = (OUT / (label + '-direct.bin')).read_bytes()
    b = (OUT / (label + '-reassembled.bin')).read_bytes()
    comparisons.append({'label': label, 'identical': a == b, 'direct_hex': a.hex(),
        'reassembled_hex': b.hex(), 'direct_bytes': len(a), 'reassembled_bytes': len(b)})

reduced = ROOT / 'docs/defects/evidence/2026-09-25-shift-inlineasm-fixes/extend-masked.ll'
wide = ROOT / 'docs/defects/evidence/2026-09-25-shift-inlineasm-fixes/anyext-wide.mir'
old = ROOT / 'build/defect-baselines/2026-09-25-historical-recovery/bin'
for label, bindir in [('pre0055', old), ('current', curdir)]:
    for mode, features in [('default', []), ('a16', ['-mattr=+mos-a16']),
                           ('xy16', ['-mattr=+mos-a16,+mos-xy16'])]:
        for opt in ['O0', 'O2']:
            run('0055-' + label + '-' + mode + '-' + opt,
                [bindir / 'llc', '-mtriple=mos', '-mcpu=mosw65816', *features,
                 '-' + opt, '-verify-machineinstrs', reduced, '-o', '/dev/null'])
        output = OUT / ('0055-' + label + '-' + mode + '-wide.mir')
        p = run('0055-' + label + '-' + mode + '-wide',
            [bindir / 'llc', '-mtriple=mos', '-mcpu=mosw65816', *features,
             '-run-pass=legalizer', '-verify-machineinstrs', wide, '-o', output])
        if p.returncode == 0:
            run('0055-' + label + '-' + mode + '-wide-check',
                [fc, wide, '--implicit-check-not=G_ANYEXT', '--input-file', output])

arch = ROOT / 'build/defect-baselines/2026-09-26-far-memset'
fill = ROOT / 'docs/defects/evidence/2026-09-26-far-memset/far-memset.ll'
for label, binary in [('pre0013', 'llc-without-0013'), ('with0013', 'llc')]:
    for mode, feature in [('a16', '+mos-a16'), ('xy16', '+mos-a16,+mos-xy16')]:
        output = OUT / ('0013-' + label + '-' + mode + '.s')
        run('0013-' + label + '-' + mode,
            [arch / 'bin' / binary, '-mtriple=mos', '-mcpu=mosw65816',
             '-mattr=' + feature, '-verify-machineinstrs', fill, '-o', output])
        run('0013-' + label + '-' + mode + '-check', [fc, fill, '--input-file', output])
    run('0013-' + label + '-runtime', ['/usr/bin/python3', ROOT / 'dev/check-far-memset.py',
        '--input', ROOT / 'docs/defects/evidence/2026-09-26-far-memset/june-c-entry/input.ll',
        '--llc', arch / 'bin' / binary, '--clang', arch / 'bin/clang',
        '--objdump', arch / 'bin/llvm-objdump', '--sdk', arch / 'sdk',
        '--emulator', arch / 'bin/jgxcheck', '--database', arch / 'Database',
        '--output', OUT / ('0013-' + label + '-runtime')])

record = {'working_directory': str(ROOT), 'tools': tools,
          'inputs': {str(path): sha(path) for path in [mir, reduced, wide, fill]},
          'immediate_comparisons': comparisons, 'runs': runs}
(OUT / 'results.json').write_text(json.dumps(record, indent=2) + '\n')
assert comparisons[0]['identical'] is False
assert comparisons[1]['identical'] is True
