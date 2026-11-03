#!/usr/bin/env python3
"""Check the volatile byte-transfer contract after experimental spilling."""

import hashlib
import json
from pathlib import Path
import re
import subprocess


ROOT = Path('/review')
LLC = Path('/work/build/0029-cross-target-build/bin/llc')
ORDER = [5, 0, 15, 3, 9, 1, 14, 6, 12, 2, 10, 4, 13, 8, 7, 11]


def address(text):
    match = re.fullmatch(r'(@(?:input|output)|%stack\.\d+)(?: \+ (\d+))?', text.strip())
    if not match:
        raise ValueError('Unsupported address: ' + text)
    return match[1], int(match[2] or 0)


def evaluate(text):
    """Propagate distinct input symbols through registers and stack locations.

    Every opcode outside this byte-transfer subset is rejected. An uninitialized
    stack read or wrong reload is observable independently of register names and
    spill-slot choices. This checks MIR values, not final machine execution.
    """
    memory = {('@input', i): f'input[{i}]' for i in range(16)}
    registers = {}
    output_events = []
    stores = reloads = 0
    body = re.split(r'^body:\s*\|\s*$', text, flags=re.M)[1]
    for original in body.splitlines():
        line = original.strip().split(' :: ')[0]
        if not line or line.startswith('bb.') or line == '...':
            continue
        if line == 'RTS':
            continue
        lhs, instruction = line.split(' = ', 1) if ' = ' in line else ('', line)
        opcode, operands = instruction.split(' ', 1)
        if opcode in ('LDAbs', 'LDStk'):
            destination = re.findall(r'%\d+', lhs)[0]
            source = operands.split(', ')[0]
            key = address(source)
            registers[destination] = memory[key]
            reloads += key[0].startswith('%stack.')
        elif opcode in ('STAbs', 'STStk'):
            source, destination, *_ = operands.split(', ')
            value = registers[re.findall(r'%\d+', source)[0]]
            key = address(destination)
            memory[key] = value
            stores += key[0].startswith('%stack.')
            if key[0] == '@output':
                output_events.append((key[1], value))
        else:
            raise ValueError('Unsupported instruction: ' + line)
    expected = [(i, f'input[{source}]') for i, source in enumerate(ORDER + ORDER[::-1])]
    if output_events != expected:
        raise AssertionError((output_events, expected))
    if not stores or not reloads:
        raise AssertionError('Pressure probe must exercise spills and reloads')
    return {'output_events': len(output_events), 'spill_stores': stores, 'reloads': reloads}


rows = []
for cpu in ('mos6502', 'mos65c02', 'mosw65816', 'mosspc700'):
    for stack, feature in (('static', '+static-stack'), ('soft', '-static-stack')):
        name = cpu + '-' + stack
        output = ROOT / (name + '.mir')
        command = [str(LLC), '-mtriple=mos', '-mcpu=' + cpu, '-mattr=' + feature,
                   '-stress-regalloc=8', '-mos-experimental-regalloc',
                   '-stop-after=mos-imag-reg-spill', '-verify-machineinstrs',
                   str(ROOT / 'pressure-probe.ll'), '-o', str(output)]
        process = subprocess.run(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        (ROOT / (name + '.log')).write_bytes(process.stdout)
        row = {'cpu': cpu, 'stack': stack, 'command': command, 'exit_code': process.returncode}
        if not process.returncode:
            try:
                row.update(evaluate(output.read_text()))
                row['semantic_check'] = 'pass'
            except Exception as error:
                row['semantic_check'] = repr(error)
            row['mir_sha256'] = hashlib.sha256(output.read_bytes()).hexdigest()
        rows.append(row)

(ROOT / 'pressure-results.json').write_text(json.dumps(rows, indent=2) + '\n')
for row in rows:
    print(row['cpu'], row['stack'], row['exit_code'], row.get('semantic_check'),
          row.get('spill_stores'), row.get('reloads'))
raise SystemExit(any(row.get('semantic_check') != 'pass' for row in rows))
