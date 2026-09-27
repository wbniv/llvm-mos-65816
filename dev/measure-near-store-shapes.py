#!/usr/bin/env python3
"""Retain near-store micro measurements, commands, IR, MIR, and tool identities.

Cycle counts use longx-shapes/cycles.py's fall-through-path estimate: ABI M8/X8
entry, direct-page low byte zero, and no page-crossing penalties. Call counts
include the call instruction but exclude the callee's execution.
"""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import subprocess


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('tools', type=Path)
    parser.add_argument('--out', type=Path, required=True)
    args = parser.parse_args()
    root = Path(__file__).resolve().parent.parent
    tool, out = args.tools.resolve(), args.out.resolve()
    if out.exists() and any(out.iterdir()):
        parser.error('output directory must be empty; retain previous measurements')
    out.mkdir(parents=True, exist_ok=True)
    spec = importlib.util.spec_from_file_location(
        'cycles', root / 'dev/longx-shapes/cycles.py')
    cycles = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(cycles)
    commands, rows = [], []

    def run(command):
        command = list(map(str, command))
        result = subprocess.run(command, capture_output=True, text=True)
        commands.append({'command': command, 'working_directory': str(root),
                         'exit_code': result.returncode, 'stderr': result.stderr})
        (out / 'commands.json').write_text(json.dumps(commands, indent=2) + '\n')
        if result.returncode:
            raise RuntimeError(result.stderr)
        return result.stdout

    identity = {}
    for name in ['mos-clang', 'llc', 'llvm-objdump']:
        executable = tool / name
        identity[name] = {'path': str(executable),
                          'sha256': hashlib.sha256(executable.read_bytes()).hexdigest(),
                          'version': run([executable, '--version'])}
    (out / 'identity.json').write_text(json.dumps(identity, indent=2) + '\n')
    for source in sorted((root / 'dev/near-store').glob('*.c')):
        (out / source.name).write_bytes(source.read_bytes())
        run([tool / 'mos-clang', '-mcpu=mosw65816', '-E', source,
             '-o', out / (source.stem + '.i')])
        for opt in ['Os', 'Oz', 'O2']:
            for mode, features in [('default', []), ('a16', ['+mos-a16']),
                                   ('xy16', ['+mos-a16', '+mos-xy16'])]:
                stem = out / f'{source.stem}-{opt}-{mode}'
                flags = [x for feature in features
                         for x in ['-Xclang', '-target-feature', '-Xclang', feature]]
                command = [tool / 'mos-clang', '-mcpu=mosw65816', '-' + opt,
                           '-fno-lto', '-mllvm', '-verify-machineinstrs', *flags, source]
                run([*command, '-c', '-o', str(stem) + '.o'])
                run([*command, '-S', '-o', str(stem) + '.s'])
                run([*command, '-S', '-emit-llvm', '-o', str(stem) + '.ll'])
                run([tool / 'llc', '-mtriple=mos', '-mcpu=mosw65816',
                     *(['-mattr=' + ','.join(features)] if features else []),
                     '-verify-machineinstrs', '-stop-after=legalizer',
                     str(stem) + '.ll', '-o', str(stem) + '.mir'])
                disassembly = run([tool / 'llvm-objdump', '-dr', str(stem) + '.o'])
                Path(str(stem) + '.dis').write_text(disassembly)
                for function in cycles.parse(disassembly.splitlines()):
                    if function['insns']:
                        rows.append({'source': source.name, 'opt': opt, 'mode': mode,
                                     **cycles.analyse(function, False)})
                (out / 'results.json').write_text(json.dumps(rows, indent=2) + '\n')
        print(source.name + ': complete', flush=True)


if __name__ == '__main__':
    main()
