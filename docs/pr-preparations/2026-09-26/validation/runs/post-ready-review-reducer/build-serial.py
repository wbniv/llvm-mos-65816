#!/usr/bin/env python3
"""Build isolated reducer candidates from read-only local objects and libraries."""
import difflib
import hashlib
import json
import shlex
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = Path(__file__).resolve().parent
UPSTREAM = ROOT / 'docs/pr-preparations/2026-09-26/upstream-source/llvm/tools/llvm-reduce/deltas/Delta.cpp'


def transform(source):
    marker = '  std::atomic<bool> AnyReduced;\n'
    assert source.count(marker) == 1
    source = source.replace(marker,
        '  // The parallel path transports IR bitcode, which does not contain machine\n'
        '  // functions. MIR reductions use the serial cloning path to retain them.\n'
        '  const bool UseParallelism = NumJobs > 1 && !Test.getProgram().isMIR();\n\n' + marker)
    assert source.count('if (NumJobs > 1)') == 2
    assert source.count('if (NumJobs > 1 && WorkLeft > 1)') == 1
    return source.replace('if (NumJobs > 1)', 'if (UseParallelism)').replace(
        'if (NumJobs > 1 && WorkLeft > 1)', 'if (UseParallelism && WorkLeft > 1)')


base = subprocess.check_output(['git', '-C', str(ROOT / 'vendor/llvm-mos'),
    'show', 'HEAD:llvm/tools/llvm-reduce/deltas/Delta.cpp'], text=True)
(OUT / 'Delta.baseline.cpp').write_text(base)
(OUT / 'Delta.serial.cpp').write_text(transform(base))
current = UPSTREAM.read_text()
(OUT / 'Delta.llvm-current.serial.cpp').write_text(transform(current))
patch = ''.join(difflib.unified_diff(current.splitlines(True),
    transform(current).splitlines(True),
    fromfile='a/llvm/tools/llvm-reduce/deltas/Delta.cpp',
    tofile='b/llvm/tools/llvm-reduce/deltas/Delta.cpp'))
(OUT / '0060-serial-alternative-source.patch').write_text(patch)
commands = []
build_commands = (ROOT / 'docs/defects/evidence/2026-09-25-llvm-reduce-parallel-mir/build-commands.txt').read_text()
link = shlex.split(next(line[len('link: '):] for line in build_commands.splitlines()
    if line.startswith('link: ')))
for variant in ['baseline', 'serial']:
    obj = str(OUT / ('Delta.' + variant + '.o'))
    compile_args = ['g++', '-std=c++17', '-O2', '-DNDEBUG', '-fPIC', '-fno-exceptions', '-fno-rtti',
        '-I', str(ROOT / 'build/llvm-mos/include'),
        '-I', str(ROOT / 'vendor/llvm-mos/llvm/include'),
        '-I', str(ROOT / 'vendor/llvm-mos/llvm/tools/llvm-reduce'),
        '-I', str(ROOT / 'vendor/llvm-mos/llvm/tools/llvm-reduce/deltas'),
        '-c', str(OUT / ('Delta.' + variant + '.cpp')), '-o', obj]
    for phase, argv, cwd in [
        ('compile', compile_args, ROOT),
        ('link', [obj if arg == '/tmp/llvm-reduce-delta-fix.o' else
                  str(OUT / ('llvm-reduce-' + variant)) if arg == '/tmp/llvm-reduce-parallel-fix'
                  else arg for arg in link], ROOT / 'build/llvm-mos')]:
        print(variant, phase, flush=True)
        proc = subprocess.run(argv, cwd=cwd, capture_output=True)
        (OUT / (variant + '-' + phase + '.log')).write_bytes(proc.stdout + proc.stderr)
        commands.append({'variant': variant, 'phase': phase, 'cwd': str(cwd),
            'argv': argv, 'exit_code': proc.returncode})
        assert proc.returncode == 0, proc.stderr.decode()
hashes = {str(path): hashlib.file_digest(open(path, 'rb'), 'sha256').hexdigest()
          for path in [OUT / 'llvm-reduce-baseline', OUT / 'llvm-reduce-serial',
                       OUT / 'Delta.baseline.cpp', OUT / 'Delta.serial.cpp', UPSTREAM,
                       OUT / '0060-serial-alternative-source.patch']}
(OUT / 'serial-build.json').write_text(json.dumps({'commands': commands, 'sha256': hashes}, indent=2) + '\n')
