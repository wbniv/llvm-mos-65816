#!/usr/bin/env python3
"""Check MOS byte-to-bit selection and retain commands, outputs, and tool hashes."""

import argparse
import hashlib
import json
from pathlib import Path
import subprocess


ROOT = Path(__file__).resolve().parent.parent
OLD = ROOT / 'docs/defects/evidence/2026-09-25-trunc-imag8-i1'
TEST = ROOT / 'test/upstream/trunc-imag8-i1'


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--llc', action='append', required=True, metavar='NAME=PATH')
    parser.add_argument('--filecheck', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=False)
    runs = []
    tools = {}
    failures = []

    def run(name, command, input_path=None, stdin=None):
        result = subprocess.run(command, input=stdin, capture_output=True, cwd=ROOT)
        for suffix, data in [('stdout', result.stdout), ('stderr', result.stderr)]:
            (args.output / f'{name}.{suffix}').write_bytes(data)
        record = dict(name=name, command=[str(x) for x in command],
                      cwd=str(ROOT), exit_code=result.returncode,
                      stdout_sha256=hashlib.sha256(result.stdout).hexdigest(),
                      stderr_sha256=hashlib.sha256(result.stderr).hexdigest())
        if input_path:
            record['input'] = str(input_path.relative_to(ROOT))
            record['input_sha256'] = digest(input_path)
        if stdin is not None:
            record['stdin_sha256'] = hashlib.sha256(stdin).hexdigest()
        runs.append(record)
        if result.returncode:
            failures.append(name)
        return result

    filecheck = args.filecheck.resolve()
    tools['FileCheck'] = dict(path=str(filecheck), sha256=digest(filecheck))
    for spec in args.llc:
        name, path = spec.split('=', 1)
        llc = Path(path).resolve()
        version = subprocess.check_output([llc, '--version'], text=True)
        tools[name] = dict(path=str(llc), sha256=digest(llc), version=version)
        for cpu in ['mos6502', 'mos65c02', 'mos65ce02', 'mosw65816']:
            common = [llc, '-mtriple=mos', '-mcpu=' + cpu, '-O1',
                      '-verify-machineinstrs', '-o', '-']
            for fixture in ['regclasses.mir', 'direct.mir', 'input.ll', 'clang-o1.ll']:
                source = (TEST if fixture == 'regclasses.mir' else OLD) / fixture
                mode = ('-run-pass=instruction-select' if source.suffix == '.mir'
                        else '-stop-after=instruction-select')
                label = f'{name}-{cpu}-{source.stem}'
                selected = run(label, common + [mode, source], source)
                checks = source if fixture == 'regclasses.mir' else TEST / 'selected.check'
                if selected.returncode == 0:
                    run(label + '-check', [filecheck, checks], checks, selected.stdout)
                if source.suffix == '.ll':
                    run(label + '-asm', common + [source], source)
    summary = dict(tools=tools, runs=runs, failures=failures,
                   compiler_runs=sum(not r['name'].endswith('-check') for r in runs),
                   selection_checks=sum(r['name'].endswith('-check') for r in runs))
    (args.output / 'runs.json').write_text(json.dumps(summary, indent=2) + '\n')
    print(f"{summary['compiler_runs']} compiler runs, "
          f"{summary['selection_checks']} selection checks; failures: {failures}")
    return bool(failures)


if __name__ == '__main__':
    raise SystemExit(main())
