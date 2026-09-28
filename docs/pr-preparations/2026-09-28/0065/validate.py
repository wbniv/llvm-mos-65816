#!/usr/bin/env python3
"""Replay frozen near-store IR with one identified extracted backend."""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import shlex
import subprocess


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--tools', type=Path, required=True)
    parser.add_argument('--inputs', type=Path, required=True)
    parser.add_argument('--out', type=Path, required=True)
    args = parser.parse_args()
    tools, inputs, out = (p.resolve() for p in (args.tools, args.inputs, args.out))
    out.mkdir(parents=True, exist_ok=False)
    commands, rows = [], []
    root = Path(__file__).resolve().parents[4]
    spec = importlib.util.spec_from_file_location('cycles', root / 'dev/longx-shapes/cycles.py')
    cycles = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(cycles)

    def run(command, stem):
        result = subprocess.run(list(map(str, command)), capture_output=True, text=True)
        (out / (stem + '.stderr')).write_text(result.stderr)
        commands.append({'command': list(map(str, command)), 'exit_code': result.returncode,
                         'working_directory': str(Path.cwd())})
        (out / 'commands.json').write_text(json.dumps(commands, indent=2) + '\n')
        if result.returncode:
            raise RuntimeError(shlex.join(list(map(str, command))) + '\n' + result.stderr)
        return result.stdout

    identity = {}
    for name in ['llc', 'llvm-mc', 'llvm-objdump', 'FileCheck']:
        p = tools / name
        identity[name] = {'path': str(p), 'sha256': hashlib.sha256(p.read_bytes()).hexdigest(),
                          'version': run([p, '--version'], name + '-version')}
    (out / 'identity.json').write_text(json.dumps(identity, indent=2) + '\n')
    sources = sorted(inputs.glob('*.ll'))
    if not sources:
        raise ValueError(f'No LLVM IR inputs in {inputs}')
    for source in sources:
        mode = source.stem.split('-')[-1]
        features = {'default': [], 'a16': ['-mattr=+mos-a16'],
                    'xy16': ['-mattr=+mos-a16,+mos-xy16']}[mode]
        command = [tools / 'llc', '-mtriple=mos', '-mcpu=mosw65816',
                   '-verify-machineinstrs', *features, source]
        obj, asm = out / (source.stem + '.o'), out / (source.stem + '.s')
        run([*command, '-filetype=obj', '-o', obj], source.stem + '-object')
        run([*command, '-o', asm], source.stem + '-asm')
        run([*command, '-stop-after=legalizer', '-o', out / (source.stem + '.mir')],
            source.stem + '-mir')
        dis = run([tools / 'llvm-objdump', '-dr', obj], source.stem + '-dis')
        (out / (source.stem + '.dis')).write_text(dis)
        for function in cycles.parse(dis.splitlines()):
            if function['insns']:
                rows.append({'input': source.name, 'mode': mode,
                             'input_sha256': hashlib.sha256(source.read_bytes()).hexdigest(),
                             **cycles.analyse(function, False)})
    if not rows:
        raise ValueError('No measured functions in disassembled objects')
    (out / 'results.json').write_text(json.dumps(rows, indent=2) + '\n')
    print(f'{len(commands)} successful commands; {len(rows)} function measurements')


if __name__ == '__main__':
    main()
