#!/usr/bin/env python3
"""Prototype size selection between complete MOS object compilations.

The command JSON contains one Clang argv list with -c and -o. Selection compares
allocated, file-backed section bytes and permits no increase in writable section
bytes. Ties keep off. Linking can still change size through layout or relaxation.
"""

import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import time


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def object_cost(readobj, path):
    result = subprocess.run([str(readobj), '--elf-output-style=JSON',
                             '--file-headers', '--sections', str(path)],
                            capture_output=True, text=True, check=True)
    data, = json.loads(result.stdout)
    if data['FileSummary']['Format'] != 'elf32-mos' or data['ElfHeader']['Type'] != 'Relocatable (0x1)':
        raise ValueError('Selection requires a relocatable MOS ELF object')
    sections = []
    for item in data['Sections']:
        section = item['Section']
        flags = section['Flags']['Value']
        if flags & 2:
            sections.append({'name': section['Name']['Name'],
                             'size': section['Size'],
                             'alignment': section['AddressAlignment'],
                             'file_backed': section['Type']['Value'] != 8,
                             'writable': bool(flags & 1),
                             'executable': bool(flags & 4)})
    return {'file_bytes': sum(s['size'] for s in sections if s['file_backed']),
            'writable_bytes': sum(s['size'] for s in sections if s['writable']),
            'text_bytes': sum(s['size'] for s in sections if s['executable']),
            'sections': sections}


def choose(costs, allow_writable_growth=False):
    """Require strict file-byte improvement and no writable-byte growth."""
    best = 'off'
    for policy, cost in costs.items():
        if ((allow_writable_growth or cost['writable_bytes'] <= costs['off']['writable_bytes']) and
                cost['file_bytes'] < costs[best]['file_bytes']):
            best = policy
    return best


def compile_and_select(compiler, command, output, report, policies=('always', 'gated'), allow_writable_growth=False):
    compiler = compiler.absolute()
    if command.count('-c') != 1 or command.count('-o') != 1:
        raise ValueError('Expected one -c and one -o in the compile command')
    if any(a.startswith(('@', '-flto', '-M', '-save-temps', '-ftime-trace', '-fprofile', '-fcoverage', '--coverage'))
           or a in ('-S', '-E', '-emit-llvm') or a.startswith('-o=') for a in command[1:]):
        raise ValueError('Prototype accepts plain object compilation without side-output options')
    if output.resolve() == report.resolve():
        raise ValueError('Object and report paths must differ')
    output.parent.mkdir(parents=True, exist_ok=True)
    report.parent.mkdir(parents=True, exist_ok=True)
    record = {'compiler': str(compiler), 'compiler_sha256': digest(compiler),
              'cwd': str(Path.cwd()), 'objective': 'allocated file-backed section bytes',
              'allow_writable_growth': allow_writable_growth, 'runs': {}}
    with tempfile.TemporaryDirectory(prefix='carry-select-', dir=output.parent) as temporary:
        objects = {}
        costs = {}
        for policy in ('off', *policies):
            if policy in objects:
                raise ValueError('Duplicate policy')
            obj = Path(temporary) / (policy + '.o')
            objects[policy] = obj
            argv = command[:]
            argv[0] = str(compiler)
            argv[argv.index('-o') + 1] = str(obj)
            filtered = []
            i = 0
            while i < len(argv):
                if (argv[i] == '-mllvm' and i + 1 < len(argv) and
                        argv[i + 1].startswith('-mos-carry-')):
                    i += 2
                    continue
                if argv[i].startswith('-mos-carry-'):
                    raise ValueError('Carry options must follow -mllvm')
                filtered.append(argv[i])
                i += 1
            argv = filtered
            argv += ['-fno-lto', '-mllvm', '-mos-carry-sched=' + policy]
            start = time.perf_counter()
            process = subprocess.run(argv, capture_output=True, text=True)
            run = {'command': argv, 'exit_code': process.returncode,
                   'wall_seconds': time.perf_counter() - start,
                   'stdout': process.stdout, 'stderr': process.stderr}
            record['runs'][policy] = run
            if policy == 'off':
                sys.stdout.write(process.stdout)
                sys.stderr.write(process.stderr)
            if process.returncode:
                if policy == 'off':
                    report.write_text(json.dumps(record, indent=2) + '\n')
                    return process.returncode
                print(f'carry selection: {policy} compilation failed; see {report}', file=sys.stderr)
                continue
            costs[policy] = object_cost(compiler.parent / 'llvm-readobj', obj)
            run.update(cost=costs[policy], object_sha256=digest(obj))
        selected = choose(costs, allow_writable_growth)
        record['selected'] = selected
        record['output_sha256'] = digest(objects[selected])
        # Replace only a fully compiled object; all alternatives stay within
        # the same compilation unit and its module-wide allocation decisions.
        destination = Path(temporary) / 'selected.o'
        shutil.copyfile(objects[selected], destination)
        destination.replace(output)
        report.write_text(json.dumps(record, indent=2) + '\n')
    return 0


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--compiler', required=True, type=Path)
    parser.add_argument('--command-json', required=True, type=Path)
    parser.add_argument('--output', required=True, type=Path)
    parser.add_argument('--report', required=True, type=Path)
    parser.add_argument('--policies', nargs='+', choices=('always', 'gated'), default=['always', 'gated'])
    parser.add_argument('--allow-writable-growth', action='store_true',
                        help='Compare file bytes without a writable-section limit')
    args = parser.parse_args()
    command = json.loads(args.command_json.read_text())
    if not isinstance(command, list) or not all(isinstance(a, str) for a in command):
        parser.error('command JSON must be a list of argument strings')
    return compile_and_select(args.compiler, command, args.output, args.report, args.policies, args.allow_writable_growth)


if __name__ == '__main__':
    sys.exit(main())
