#!/usr/bin/env python3
"""Check marked far accesses in optimized MOS assembly with source line tables."""

import argparse
from collections import Counter, defaultdict, deque
from dataclasses import dataclass
import json
from pathlib import Path
import re
import shlex


class ShapeError(ValueError):
    pass


@dataclass
class Instruction:
    opcode: str
    operand: str
    line: int
    location: tuple


def expectations(mode, fixture):
    # An unindexed access has no index-width requirement. Widths are in bits.
    def load(form, accum=8, index=None):
        return ('lda', form, accum, index)

    def store(form, index=None):
        return ('sta', form, 8, index)

    wide = mode == 'xy16'
    indexed_load = load('indirect-y', index=16) if wide else load('indirect')
    indexed_store = store('indirect-y', 16) if wide else store('indirect')
    if fixture == 'pressure':
        return {'fill': [indexed_store], 'sample': [indexed_load]}
    return {
        'rd8': [load('indirect-y', index=8)],
        'rdg': [load('long-x', index=8)],
        'rd16': [indexed_load],
        'rdw': [load('indirect', accum=16)],
        'rdw16': [indexed_load],
        'rdw16g': [load('long-x', index=16) if wide else load('indirect')],
        'rdw8': [load('indirect-y', index=8)],
        'wr8': [store('indirect-y', 8)],
        'cp8': [load('indirect-y', index=8), store('indirect-y', 8)],
        'wr16': [indexed_store],
        'readback': [load('long')] * 16,
    }


def source_markers(source):
    return {number: match[1]
            for number, line in enumerate(source.read_text().splitlines(), 1)
            if (match := re.search(r'FARBLIT-PROBE: (\w+)', line))}


def parse_assembly(text, source):
    files, functions = {}, {}
    current = None
    location = (None, 0)
    for number, raw in enumerate(text.splitlines(), 1):
        match = re.match(r'\s*\.file\s+(\d+)\s+(.*)', raw)
        if match:
            fields = shlex.split(match[2])
            path = Path(fields[0])
            if len(fields) > 1 and fields[1] != 'md5':
                path /= fields[1]
            files[int(match[1])] = path.resolve()
            continue
        line = raw.split(';', 1)[0].strip()
        match = re.match(r'\.type\s+(\w+),@function$', line)
        if match:
            current = ([], {})
            functions[match[1]] = current
            location = (None, 0)
            continue
        if line.startswith('.size'):
            current = None
        if current is None:
            continue
        instructions, labels = current
        match = re.match(r'\.loc\s+(\d+)\s+(\d+)\b', line)
        if match:
            location = (int(match[1]), int(match[2]))
        elif line.endswith(':'):
            labels[line[:-1]] = len(instructions)
        elif line and not line.startswith('.'):
            match = re.fullmatch(r'([a-z][a-z0-9]*)\s*(.*)', line)
            if not match:
                raise ShapeError(f'assembly line {number}: unsupported instruction {line}')
            instructions.append(Instruction(match[1], match[2], number, location))
    if not functions or source.resolve() not in files.values():
        raise ShapeError('missing functions or source file in assembly line tables')
    return files, functions


def width_states(instructions, labels):
    """Propagate ABI entry widths through every reachable branch and loop."""
    conditional = {'bcc', 'bcs', 'beq', 'bne', 'bmi', 'bpl', 'bvc', 'bvs'}
    successors, predecessors = {}, defaultdict(set)
    for index, inst in enumerate(instructions):
        following = [index + 1] if index + 1 < len(instructions) else []
        if inst.opcode in conditional | {'bra', 'brl', 'jmp', 'jml'}:
            if inst.operand not in labels:
                raise ShapeError(f'assembly line {inst.line}: unknown branch target {inst.operand}')
            following = [labels[inst.operand]] + (following if inst.opcode in conditional else [])
        elif inst.opcode in {'rts', 'rtl', 'rti', 'stp'}:
            following = []
        successors[index] = following
        for target in following:
            if target >= len(instructions):
                raise ShapeError(f'assembly line {inst.line}: branch leaves function')
            predecessors[target].add(index)

    states = defaultdict(set)
    queue = deque([(0, (8, 8))])
    while queue:
        index, state = queue.popleft()
        if state in states[index]:
            continue
        states[index].add(state)
        inst = instructions[index]
        accum, idx = state
        if inst.opcode in {'rep', 'sep'}:
            match = re.fullmatch(r'#(\d+|\$[0-9a-fA-F]+|0x[0-9a-fA-F]+)', inst.operand)
            if not match:
                raise ShapeError(f'assembly line {inst.line}: unsupported status mask')
            value = match[1]
            mask = int(value[1:], 16) if value.startswith('$') else int(value, 0)
            width = 16 if inst.opcode == 'rep' else 8
            accum = width if mask & 32 else accum
            idx = width if mask & 16 else idx
        elif inst.opcode in {'plp', 'rti', 'xce'}:
            accum = idx = None
        elif inst.opcode in {'jsr', 'jsl'}:
            if state != (8, 8):
                raise ShapeError(f'assembly line {inst.line}: call outside M8/X8 ABI')
            accum = idx = 8
        for target in successors[index]:
            queue.append((target, (accum, idx)))
    return states, predecessors


def address_form(operand):
    if re.fullmatch(r'\[[^\]]+\],y', operand):
        return 'indirect-y'
    if re.fullmatch(r'\[[^\]]+\]', operand):
        return 'indirect'
    if re.fullmatch(r'mos24\(.+\),x', operand):
        return 'long-x'
    if re.fullmatch(r'mos24\(.+\)', operand):
        return 'long'
    if re.fullmatch(r'\d+|\$[0-9a-fA-F]+|0x[0-9a-fA-F]+', operand):
        value = int(operand[1:], 16) if operand.startswith('$') else int(operand, 0)
        if value > 65535:
            return 'long'
    return None


def check_shapes(text, source, mode, fixture):
    expected = expectations(mode, fixture)
    markers = source_markers(source)
    if set(markers.values()) != set(expected):
        raise ShapeError(f'source probe markers differ: expected {sorted(expected)}, got {sorted(set(markers.values()))}')
    files, functions = parse_assembly(text, source)
    accesses = defaultdict(list)
    errors = []
    for function, (instructions, labels) in functions.items():
        states, predecessors = width_states(instructions, labels)
        for index, inst in enumerate(instructions):
            form = address_form(inst.operand)
            if form is None:
                continue
            file_id, source_line = inst.location
            probe = markers.get(source_line) if files.get(file_id) == source.resolve() else None
            if probe is None:
                errors.append(f'{function}:{inst.line}: unmarked far access {inst.opcode} {inst.operand}')
                continue
            widths = states[index]
            if len(widths) != 1 or None in next(iter(widths), (None, None)):
                errors.append(f'{probe}: unknown, conflicting or unreachable M/X widths at assembly line {inst.line}')
                continue
            accum, idx = next(iter(widths))
            accesses[probe].append({'operation': inst.opcode, 'form': form,
                                    'accumulator_bits': accum,
                                    'index_bits': idx if form in {'indirect-y', 'long-x'} else None,
                                    'source_line': source_line, 'assembly_line': inst.line,
                                    'function': function, 'instruction': f'{inst.opcode} {inst.operand}'})
            if form == 'indirect-y' and idx == 16:
                previous = instructions[index - 1] if index else None
                if (predecessors[index] != {index - 1} or previous is None or
                        previous.opcode != 'ldy' or previous.operand.startswith('#') or
                        {state[1] for state in states[index - 1]} != {16}):
                    errors.append(f'{probe}: Y16 access must immediately follow its runtime ldy on every path')
    for probe, shapes in expected.items():
        actual = [(a['operation'], a['form'], a['accumulator_bits'], a['index_bits'])
                  for a in accesses[probe]]
        if actual != shapes:
            errors.append(f'{probe}: expected {shapes}, got {actual}')
        # Every marked expression must contribute its own access, including readbacks.
        marked = {line for line, name in markers.items() if name == probe}
        observed = {a['source_line'] for a in accesses[probe]}
        if marked != observed:
            errors.append(f'{probe}: missing or mismatched source expressions {sorted(marked ^ observed)}')
    if errors:
        raise ShapeError('\n'.join(errors))
    return dict(accesses)


def disassembly_body(text):
    lines = text.splitlines()
    headers = [i for i, line in enumerate(lines) if line.startswith('Disassembly of section ')]
    if not headers:
        raise ShapeError('empty disassembly: no code sections')
    return lines[headers[0]:]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--mode', choices=['a16', 'xy16'], required=True)
    parser.add_argument('--fixture', choices=['main', 'pressure'], required=True)
    parser.add_argument('--source', type=Path, required=True)
    parser.add_argument('--assembly', type=Path, required=True)
    parser.add_argument('--plain-dis', type=Path, required=True)
    parser.add_argument('--debug-dis', type=Path, required=True)
    parser.add_argument('--json', type=Path)
    args = parser.parse_args()
    try:
        if disassembly_body(args.plain_dis.read_text()) != disassembly_body(args.debug_dis.read_text()):
            raise ShapeError('checked assembly differs from the plain object (instructions or relocations)')
        accesses = check_shapes(args.assembly.read_text(), args.source, args.mode, args.fixture)
    except (ShapeError, OSError) as error:
        print(f'FAIL[{args.mode}/{args.fixture}]: {error}')
        return 1
    for probe, rows in accesses.items():
        shapes = Counter(f"{a['operation']} {a['form']} M{a['accumulator_bits']}" +
                         (f" index{a['index_bits']}" if a['index_bits'] else '') for a in rows)
        print(f'  PASS[{args.mode}/{probe}]: ' + ', '.join(f'{count} x {shape}' for shape, count in shapes.items()))
    if args.json:
        args.json.write_text(json.dumps({'mode': args.mode, 'fixture': args.fixture,
                                        'assembly_matches_plain_object': True, 'accesses': accesses}, indent=2) + '\n')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
