#!/usr/bin/env python3
"""Validate exact submission patches in an owned, pinned scratch checkout."""

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import resource
import shutil
import subprocess
import time


def digest(path):
    with Path(path).open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('venue', choices=['mos', 'llvm'])
    parser.add_argument('--only', nargs='+')
    parser.add_argument('--run-tag', default='')
    args = parser.parse_args()
    root = Path('/work')
    package = root / 'docs/pr-preparations/2026-09-26'
    src = root / ('build/post-ready-2026-09-26-isolated-src' if args.venue == 'mos'
                  else 'build/post-ready-2026-09-26-llvm-src')
    build = root / ('build/0029-cross-target-build' if args.venue == 'mos'
                    else 'build/post-ready-2026-09-26-llvm-build')
    assert re.fullmatch(r'[-a-z0-9]*', args.run_tag)
    out = root / ('build/post-ready-validation-' + args.venue + args.run_tag)
    out.mkdir(exist_ok=True)
    resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
    targets = ['llc', 'opt', 'llvm-mc', 'llvm-objdump', 'llvm-objcopy',
               'llvm-readobj', 'llvm-readelf', 'FileCheck', 'not', 'split-file',
               'count', 'llvm-config', 'llvm-reduce', 'llvm-as', 'llvm-link',
               'yaml2obj', 'llvm-nm', 'llvm-dis', 'verify-uselistorder']
    candidates = (['0038', '0039', '0040', '0043', '0044', '0045', '0046', '0047', '0050', '0054']
                  if args.venue == 'mos' else ['0056', '0057', '0058', '0059', '0060', '0028', '0037', '0041'])
    deps = {'0044': ['0039'], '0058': ['0057'], '0059': ['0057']}
    suffix = 'llvm-mos' if args.venue == 'mos' else 'llvm-project'

    def run(command, log, *, cwd=root, check=False, env=None, timeout=1800):
        start = time.monotonic()
        with log.open('w') as stream:
            proc = subprocess.run(command, cwd=cwd, env=env, stdout=stream,
                                  stderr=subprocess.STDOUT, timeout=timeout)
        record = dict(command=command, cwd=str(cwd), exit_code=proc.returncode,
                      seconds=round(time.monotonic() - start, 3),
                      log=str(log.relative_to(root)), log_sha256=digest(log))
        if check and proc.returncode:
            raise RuntimeError(record)
        return record

    def build_tools(log):
        return run(['ninja', '-C', str(build), '-j', '2', *targets], log, check=True)

    def snapshot(folder):
        folder.mkdir()
        binaries = {}
        for tool in targets:
            original = build / 'bin' / tool
            destination = folder / tool
            subprocess.run(['cp', '--reflink=auto', str(original), str(destination)], check=True)
            binaries[tool] = digest(destination)
        return binaries

    def test_runs(files, folder, tools):
        folder.mkdir()
        environment = os.environ.copy()
        environment['PATH'] = str(tools) + os.pathsep + environment['PATH']
        records = []
        for source in files:
            testdir = folder / source.name
            testdir.mkdir()
            shutil.copy2(source, testdir / 'input.txt')
            commands, current = [], ''
            for line in source.read_text().splitlines():
                match = re.match(r'^\s*[;#/]\s*RUN:\s*(.*)', line)
                if not match:
                    continue
                current += match.group(1)
                if current.endswith('\\'):
                    current = current[:-1] + ' '
                    continue
                commands.append(current)
                current = ''
            for index, command in enumerate(commands):
                command = (command.replace('%s', str(source))
                           .replace('%S', str(source.parent))
                           .replace('%t', str(testdir / 'tmp')))
                record = run(['bash', '-o', 'pipefail', '-c', command],
                             testdir / f'{index:02d}.log', env=environment, timeout=120)
                record.update(test=str(source.relative_to(src)), input_sha256=digest(source))
                records.append(record)
                if record['exit_code']:
                    break
        return records

    assert not subprocess.check_output(['git', 'status', '--porcelain'], cwd=src), 'Scratch tree must be clean'
    base = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=src, text=True).strip()
    for number in args.only or candidates:
        assert number in candidates
        directory = out / number
        directory.mkdir()
        shutil.copy2(__file__, directory / 'validate.py')
        receipt = dict(venue=args.venue, base=base, patch=number, prerequisites=deps.get(number, []),
                       runner_sha256=digest(__file__),
                       container_image=os.environ.get('POST_READY_IMAGE', 'not captured'),
                       attribution='OpenAI Codex CLI 0.157.0 (codex-tui), gpt-6-astra, xhigh')
        applied = []
        try:
            for dependency in deps.get(number, []):
                path = package / f'{dependency}-{suffix}.patch'
                run(['git', 'apply', str(path)], directory / f'apply-{dependency}.log', cwd=src, check=True)
                applied.append(path)
            receipt['baseline_build'] = build_tools(directory / 'baseline-build.log')
            receipt['baseline_tools'] = snapshot(directory / 'baseline-bin')
            if args.venue == 'llvm':
                selected = ('(inline.?asm|asm-goto|callbr)' if number in ['0037', '0041', '0056', '0057', '0058', '0059']
                            else '(virtregrewriter|undef.*subreg|subreg.*undef|regalloc|spill)' if number in ['0028', '0040']
                            else '.*')
                suite_paths = ([str(build / 'test/tools/llvm-reduce')] if number == '0060'
                               else [str(build / 'test/CodeGen/AArch64'), str(build / 'test/CodeGen/X86')])
                receipt['baseline_suites'] = run([str(build / 'bin/llvm-lit'), '-j', '2', '-v',
                    '--filter=' + selected, *suite_paths], directory / 'baseline-suites.log')
            patch = package / f'{number}-{suffix}.patch'
            receipt['patch_sha256'] = digest(patch)
            receipt['dependency_sha256'] = {p.name: digest(p) for p in applied}
            shutil.copy2(build / 'CMakeCache.txt', directory / 'CMakeCache.txt')
            run(['git', 'apply', str(patch)], directory / 'apply.log', cwd=src, check=True)
            applied.append(patch)
            files = [src / name for name in re.findall(r'^\+\+\+ b/(llvm/test/[^\n]+)', patch.read_text(), re.M)]
            receipt['baseline_tests'] = test_runs(files, directory / 'baseline-tests', directory / 'baseline-bin')
            receipt['candidate_build'] = build_tools(directory / 'candidate-build.log')
            receipt['candidate_tools'] = snapshot(directory / 'candidate-bin')
            receipt['candidate_tests'] = test_runs(files, directory / 'candidate-tests', directory / 'candidate-bin')
            receipt['candidate_passed'] = all(r['exit_code'] == 0 for r in receipt['candidate_tests'])
            receipt['baseline_failed'] = any(r['exit_code'] != 0 for r in receipt['baseline_tests'])
            if args.venue == 'mos':
                receipt['mos_suites'] = run([str(build / 'bin/llvm-lit'), '-j', '2', '-v',
                    str(build / 'test/MC/MOS'), str(build / 'test/CodeGen/MOS')], directory / 'mos-suites.log')
            else:
                receipt['candidate_suites'] = run([str(build / 'bin/llvm-lit'), '-j', '2', '-v',
                    '--filter=' + selected, *suite_paths], directory / 'candidate-suites.log')
            suite_key = 'mos_suites' if args.venue == 'mos' else 'candidate_suites'
            receipt['candidate_suites_passed'] = receipt[suite_key]['exit_code'] == 0
            receipt['expected_baseline_observed'] = receipt['baseline_failed'] or number == '0046'
            receipt['validation_gates_passed'] = (receipt['candidate_passed'] and
                receipt['candidate_suites_passed'] and receipt['expected_baseline_observed'])
            print(number, 'candidate:', receipt['candidate_passed'], 'baseline red:', receipt['baseline_failed'],
                  'suites:', receipt['candidate_suites_passed'], flush=True)
        finally:
            (directory / 'receipt.json').write_text(json.dumps(receipt, indent=2) + '\n')
            for path in reversed(applied):
                subprocess.run(['git', 'apply', '-R', str(path)], cwd=src, check=True)
        if not receipt['validation_gates_passed']:
            raise RuntimeError(f'{number}: validation gate failed; inspect retained logs')


if __name__ == '__main__':
    main()
