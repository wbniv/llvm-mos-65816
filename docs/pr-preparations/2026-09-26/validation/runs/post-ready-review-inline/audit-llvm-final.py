#!/usr/bin/env python3
"""Read-only verification of final LLVM packet and retained receipt bytes."""

from pathlib import Path
import hashlib
import json
import re
import subprocess

ROOT = Path('/home/will/llvm-mos-65816')
PACKET = ROOT / 'docs/pr-preparations/2026-09-26'
ARCHIVE = PACKET / 'validation/runs/post-ready-validation-llvm'
SOURCE = ROOT / 'build/post-ready-2026-09-26-llvm-src'
BASE = 'e59a0c697552ae7d1c3aeed5774e829cdc5e16b5'


def digest(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def patched_files(path):
    result = {}
    for chunk in path.read_text().split('diff --git ')[1:]:
        lines = chunk.splitlines(keepends=True)
        name = lines[0].split(' b/', 1)[1].strip()
        if not name.startswith('llvm/test/'):
            continue
        old = [] if '--- /dev/null\n' in lines else subprocess.check_output(
            ['git', '-C', str(SOURCE), 'show', BASE + ':' + name], text=True
        ).splitlines(keepends=True)
        output, cursor, pos = [], 0, 1
        while pos < len(lines):
            match = re.match(r'@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@', lines[pos])
            if not match:
                pos += 1
                continue
            start = max(0, int(match.group(1)) - 1)
            output.extend(old[cursor:start])
            cursor, pos = start, pos + 1
            old_left = int(match.group(2) or 1)
            new_left = int(match.group(4) or 1)
            while old_left or new_left:
                line = lines[pos]
                if line.startswith('+'):
                    output.append(line[1:])
                    new_left -= 1
                elif line.startswith(('-', ' ')) or line == '\n':
                    expected = line[1:] if line != '\n' else line
                    assert old[cursor] == expected, (name, cursor, old[cursor], expected)
                    if not line.startswith('-'):
                        output.append(expected)
                        new_left -= 1
                    cursor += 1
                    old_left -= 1
                elif line.startswith('\\ No newline'):
                    raise AssertionError('Handle unterminated input explicitly')
                pos += 1
        output.extend(old[cursor:])
        result[name] = ''.join(output).encode()
    return result


total_logs = total_inputs = total_tools = 0
for number in ['0028', '0037', '0041', '0056', '0057', '0058', '0059']:
    folder = ROOT / 'build/post-ready-validation-llvm' / number
    archived = ARCHIVE / number
    receipt = json.loads((folder / 'receipt.json').read_text())
    assert (folder / 'receipt.json').read_bytes() == (archived / 'receipt.json').read_bytes()
    assert receipt['base'] == BASE
    assert receipt['container_image'] == 'sha256:eeecfab76840167d9f16982b1efddae90d4969c5d7891ec16e87e46150ac94c1'
    assert receipt['validation_gates_passed']
    patch = PACKET / (number + '-llvm-project.patch')
    assert digest(patch) == receipt['patch_sha256']
    assert digest(archived / 'validate.py') == receipt['runner_sha256']
    for name, expected in receipt['dependency_sha256'].items():
        assert digest(PACKET / name) == expected
    results = patched_files(patch)
    log_count = input_count = tool_count = 0

    def logs(obj):
        global log_count
        if isinstance(obj, dict):
            if 'log' in obj:
                original = ROOT / obj['log']
                saved = PACKET / 'validation/runs' / Path(obj['log']).relative_to('build')
                assert digest(original) == obj['log_sha256'], original
                assert digest(saved) == obj['log_sha256'], saved
                log_count += 1
            for value in obj.values():
                logs(value)
        elif isinstance(obj, list):
            for value in obj:
                logs(value)

    logs(receipt)
    inputs = set()
    for phase in ['baseline', 'candidate']:
        for run in receipt[phase + '_tests']:
            test = run['test']
            data = results[test]
            assert hashlib.sha256(data).hexdigest() == run['input_sha256']
            name = Path(test).name
            for base in [folder, archived]:
                assert (base / (phase + '-tests') / name / 'input.txt').read_bytes() == data
            inputs.add((phase, test))
        for tool in ['llc', 'FileCheck', 'not', 'split-file']:
            assert digest(folder / (phase + '-bin') / tool) == receipt[phase + '_tools'][tool]
            tool_count += 1
    input_count = len(inputs)
    config = (archived / 'CMakeCache.txt').read_text()
    assert config == (folder / 'CMakeCache.txt').read_text()
    for text in ['CMAKE_BUILD_TYPE:STRING=Release', 'LLVM_ENABLE_ASSERTIONS:BOOL=ON',
                 'LLVM_TARGETS_TO_BUILD:STRING=X86;AArch64',
                 'LLVM_EXPERIMENTAL_TARGETS_TO_BUILD:STRING=\n']:
        assert text in config
    print(json.dumps(dict(number=number, receipt_sha256=digest(folder / 'receipt.json'),
                          logs=log_count, inputs=input_count, tools=tool_count,
                          candidate_runs=len(receipt['candidate_tests']),
                          input_hashes={k: hashlib.sha256(v).hexdigest() for k, v in results.items()
                                        if k.startswith('llvm/test/')})), flush=True)
    total_logs += log_count
    total_inputs += input_count
    total_tools += tool_count

final = (PACKET / '0041-llvm-project.patch').read_text()
updated = ('+; For the i128 "r" operands here, AArch64 selects GPR32common, so each operand\n'
           '+; occupies two 32-bit registers and the value is narrowed to their combined\n'
           '+; width -- exactly what SelectionDAG does for the same asm.\n')
earlier = ('+; AArch64 selects GPR32common for "r" whenever the type is not 64-bit, so an\n'
           '+; i128 operand occupies two 32-bit registers and the value is narrowed to their\n'
           '+; combined width -- exactly what SelectionDAG does for the same asm.\n')
assert updated in final
assert hashlib.sha256(final.replace(updated, earlier).encode()).hexdigest() == \
    '2b8e1087e94ba26b53ec3ff95a45f8f7a04873a955f838ce85f9ffc68dbaab7a'
print(json.dumps(dict(total_logs=total_logs, total_inputs=total_inputs,
                      total_tool_snapshots=total_tools, final_0041_comment_only=True)))
