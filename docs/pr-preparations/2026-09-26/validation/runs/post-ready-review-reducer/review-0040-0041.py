#!/usr/bin/env python3
"""Retain fresh, read-only executions of the existing regression artifacts."""
import hashlib
import json
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[2]
OUT = Path(__file__).resolve().parent / 'review-0040-0041'
OUT.mkdir(exist_ok=True)

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def new_files(patch):
    result = {}
    for part in patch.read_text().split('diff --git ')[1:]:
        if '--- /dev/null\n' not in part:
            continue
        name = part.splitlines()[0].split(' b/')[1]
        content = ''.join(line[1:] + '\n' for line in part.splitlines()
                          if line.startswith('+') and not line.startswith('+++'))
        result[name] = content
    return result

inputs = {}
for n, patch in [('0040', 'patches/llvm-mos/0040-llvm-inline-spiller-coalesce-scratch-vregs.patch'),
                 ('0041', 'docs/pr-preparations/2026-09-24/0041-llvm-project.patch')]:
    for name, content in new_files(ROOT / patch).items():
        file = OUT / (n + '-' + Path(name).name)
        file.write_text(content)
        inputs[n] = file

bins = {
    '0040-old-before': ROOT / 'build/0040-ra-build/llc-before-0040',
    '0040-old-after': ROOT / 'build/0040-ra-build/llc-0040',
    'current-mos': ROOT / 'build/post-ready-validation-mos/0039/baseline-bin/llc',
    '0041-old-before': ROOT / 'build/0041-inlineasm-build/llc-before-0041',
    '0041-old-after': ROOT / 'build/0041-inlineasm-build/llc-0041',
}
results = {'binaries': {}, 'inputs': {}, 'runs': []}
for name, file in bins.items():
    results['binaries'][name] = {'path': str(file.relative_to(ROOT)), 'sha256': sha(file),
                               'version': subprocess.check_output([file, '--version'], text=True)}
for name, file in inputs.items():
    results['inputs'][name] = {'path': str(file.relative_to(ROOT)), 'sha256': sha(file)}

def run(tag, command):
    p = subprocess.run([str(x) for x in command], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    (OUT / (tag + '.stdout')).write_bytes(p.stdout)
    (OUT / (tag + '.stderr')).write_bytes(p.stderr)
    row = {'name': tag, 'command': [str(x) for x in command], 'returncode': p.returncode,
           'stdout_sha256': hashlib.sha256(p.stdout).hexdigest(),
           'stderr_sha256': hashlib.sha256(p.stderr).hexdigest()}
    results['runs'].append(row)
    print(tag, p.returncode, p.stderr.decode(errors='replace').splitlines()[:1], flush=True)
    return p

for name in ['0040-old-before', '0040-old-after', 'current-mos']:
    for cpu in ['mos6502', 'mos65c02', 'mosw65816']:
        cmd = [bins[name], '-O2', '-mtriple=mos', '-mcpu=' + cpu, '-verify-machineinstrs', inputs['0040'], '-o', '/dev/null']
        run(name + '-' + cpu, cmd)
        if name == 'current-mos':
            run(name + '-' + cpu + '-no-hoist', cmd + ['-disable-spill-hoist'])

mir = OUT / '0040-pre-greedy.mir'
run('0040-old-pre-greedy', [bins['0040-old-before'], '-O2', '-mtriple=mos', '-mcpu=mos65c02',
                           '-stop-before=greedy', inputs['0040'], '-o', mir])
results['inputs']['0040-pre-greedy'] = {'path': str(mir.relative_to(ROOT)), 'sha256': sha(mir)}
for name in ['0040-old-before', '0040-old-after', 'current-mos']:
    run(name + '-mir-replay', [bins[name], '-O2', '-mtriple=mos', '-mcpu=mos65c02', '-start-before=greedy',
                              '-disable-spill-hoist', '-verify-machineinstrs', mir, '-o', '/dev/null'])

for name in ['0041-old-before', '0041-old-after', 'current-mos']:
    for opt in ['-O0', '-O2']:
        for stage in ['irtranslator', 'final']:
            cmd = [bins[name], '-mtriple=aarch64-linux-gnu', '-global-isel', '-global-isel-abort=1',
                   opt, '-verify-machineinstrs', inputs['0041'], '-o', '-']
            if stage != 'final':
                cmd.append('-stop-after=' + stage)
            p = run(name + opt + '-' + stage, cmd)
            if p.returncode == 0:
                fc = ROOT / 'build/llvm-mos/bin/FileCheck'
                prefix = 'ASM' if stage == 'final' else 'CHECK'
                tag = name + opt + '-' + stage + '-check'
                asm = OUT / (name + opt + '-' + stage + '.stdout')
                run(tag, [fc, inputs['0041'], '--check-prefix=' + prefix, '--input-file=' + str(asm)])

(OUT / 'results.json').write_text(json.dumps(results, indent=2) + '\n')
