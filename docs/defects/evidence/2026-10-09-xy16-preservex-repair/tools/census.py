#!/usr/bin/env python3
"""Compile every corpus/demo/example C file to IR once per mode and level,
then run the before and after llc on that IR (verifier on) and record exit
codes, object sha256 and per-section .text sizes.

usage: census.py OUT_TSV BEFORE_LLC AFTER_LLC [JOBS]
Run from the repository root. Writes one TSV row per (file, mode, level).
"""
import hashlib, os, subprocess, sys, tempfile, glob, resource
from concurrent.futures import ThreadPoolExecutor

out_tsv, before, after = sys.argv[1:4]
jobs = int(sys.argv[4]) if len(sys.argv) > 4 else 4
CLANG = os.environ.get('CENSUS_CLANG', 'build/llvm-mos-install/bin/clang')
CFG = 'build/install/bin/mos-snes.cfg'
OBJDUMP = os.environ.get('CENSUS_OBJDUMP', 'build/llvm-mos-install/bin/llvm-objdump')
MODES = {'default': [], 'a16': ['+mos-a16'], 'xy16': ['+mos-a16', '+mos-xy16']}
LEVELS = {'Os': '-O2', 'Oz': '-O2', 'O2': '-O2', 'O3': '-O3'}
SRCS = sorted(glob.glob('examples/snes/*.c') + glob.glob('examples/snes/corpus/*.c')
              + glob.glob('examples/65816/*.c'))
INC = ['-I', 'examples/65816', '-I', 'examples/snes', '-I', 'build',
       '-I', 'build/seamdemo-gen']


def limits():
    resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
    resource.setrlimit(resource.RLIMIT_AS, (2_000_000 * 1024, 2_000_000 * 1024))


def text_size(obj):
    r = subprocess.run([OBJDUMP, '-h', obj], capture_output=True, text=True)
    tot = 0
    for line in r.stdout.splitlines():
        f = line.split()
        if len(f) >= 3 and f[1].startswith('.text'):
            tot += int(f[2], 16)
    return tot


def one(task):
    src, mode, level = task
    with tempfile.TemporaryDirectory(dir='build/xy16px/tmp') as td:
        ll = os.path.join(td, 'x.ll')
        feats = []
        for f in MODES[mode]:
            feats += ['-Xclang', '-target-feature', '-Xclang', f]
        r = subprocess.run([CLANG, '--config', CFG, '-mcpu=mosw65816', f'-{level}',
                            '-fno-lto', *feats, *INC, '-S', '-emit-llvm', src,
                            '-o', ll], capture_output=True, preexec_fn=limits)
        if r.returncode:
            return (src, mode, level, 'FE', '', '', '', '', '', '')
        row = [src, mode, level, 'ok']
        for llc in (before, after):
            obj = os.path.join(td, 'x.o')
            p = subprocess.run([llc, LEVELS[level], '-verify-machineinstrs',
                                '-filetype=obj', ll, '-o', obj],
                               capture_output=True, text=True, preexec_fn=limits)
            sig = 'undef-phys' if 'Using an undefined physical register' in p.stderr else ''
            if p.returncode == 0:
                h = hashlib.sha256(open(obj, 'rb').read()).hexdigest()[:16]
                row += [str(p.returncode), h, str(text_size(obj))]
            else:
                # Retry without the verifier to compare the emitted code.
                q = subprocess.run([llc, LEVELS[level], '-filetype=obj', ll, '-o', obj],
                                   capture_output=True, preexec_fn=limits)
                h = hashlib.sha256(open(obj, 'rb').read()).hexdigest()[:16] if q.returncode == 0 else 'none'
                sz = str(text_size(obj)) if q.returncode == 0 else ''
                row += [f'{p.returncode}:{sig}', h, sz]
        return tuple(row)


os.makedirs('build/xy16px/tmp', exist_ok=True)
tasks = [(s, m, l) for s in SRCS for m in MODES for l in LEVELS]
with open(out_tsv, 'w') as fo, ThreadPoolExecutor(jobs) as ex:
    fo.write('src\tmode\tlevel\tfe\tbefore_rc\tbefore_sha\tbefore_text\tafter_rc\tafter_sha\tafter_text\n')
    for row in ex.map(one, tasks):
        fo.write('\t'.join(row) + '\n')
        fo.flush()
