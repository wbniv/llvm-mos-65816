#!/usr/bin/env python3
"""Count MOS carry materialization sequences in llvm-objdump disassembly."""

import argparse
import hashlib
import json
from pathlib import Path
import re
import tarfile


INSTRUCTION = re.compile(
    r'^\s*([0-9a-f]+):\s+((?:[0-9a-f]{2}\s+)+)\t([a-z]+)\s*(.*)$')
SYMBOL = re.compile(r'^[0-9a-f]+ <([^>]+)>:$')


def digest(data):
    return hashlib.sha256(data).hexdigest()


def count(text):
    """Return counts and instruction addresses per function.

    A materialization is an adjacent load-one/BCS/load-zero sequence with the
    same destination and a branch over exactly the zero load. CMP/CPX/CPY #1
    are restore candidates: disassembly alone does not prove boolean provenance.
    """
    functions = {}
    current = None
    for line in text.splitlines():
        symbol = SYMBOL.match(line)
        if symbol:
            current = symbol[1]
            functions.setdefault(current, [])
        insn = INSTRUCTION.match(line)
        if insn:
            if current is None:
                raise ValueError('Instruction precedes a function symbol: ' + line)
            functions[current].append({
                'address': int(insn[1], 16), 'bytes': bytes.fromhex(insn[2]),
                'mnemonic': insn[3], 'operand': insn[4].split(';')[0].strip()})
    result = {}
    for name, instructions in functions.items():
        saves = []
        restores = []
        for insn in instructions:
            if (insn['mnemonic'] in ('cmp', 'cpx', 'cpy')
                    and insn['operand'] == '#$1'):
                restores.append(hex(insn['address']))
        for first, branch, last in zip(instructions, instructions[1:], instructions[2:]):
            if (first['mnemonic'] in ('lda', 'ldx', 'ldy')
                    and first['operand'] == '#$1'
                    and branch['mnemonic'] == 'bcs'
                    and branch['bytes'] == bytes([0xb0, len(last['bytes'])])
                    and last['mnemonic'] == first['mnemonic']
                    and last['operand'] == '#$0'
                    and first['address'] + len(first['bytes']) == branch['address']
                    and branch['address'] + len(branch['bytes']) == last['address']):
                saves.append(hex(first['address']))
        result[name] = {
            'materializations': len(saves), 'cmp1_candidates': len(restores),
            'materialization_addresses': saves, 'cmp1_addresses': restores}
    if not result:
        raise ValueError('No function disassembly found')
    return result


def growth_report(evidence):
    controls = []
    for expected in json.loads((evidence / 'carry-sequence-counts.json').read_text()):
        path = evidence / expected['stage'] / (expected['shape'] + '-a16') / 'normal.o.dis'
        data = path.read_bytes()
        counts = count(data.decode())['f']
        if (counts['materializations'] != expected['carry_materializations']
                or counts['cmp1_candidates'] != expected['carry_restore_cmp1']):
            raise ValueError('Control counts disagree: ' + str(path))
        controls.append({'path': str(path), 'sha256': digest(data), **counts})
    review_path = evidence / 'growth-review.json'
    archive_path = evidence / 'growth-disassembly.tar.gz'
    review = json.loads(review_path.read_text())
    rows = []
    with tarfile.open(archive_path) as archive:
        for case in review['rows']:
            members = case['disassembly_archive_members']
            data = [archive.extractfile(name).read() for name in members]
            counts = [count(value.decode()) for value in data]
            functions = []
            for name, delta in case['function_deltas'].items():
                if delta <= 0:
                    continue
                before, after = [value[name] for value in counts]
                functions.append({'name': name, 'size_delta': delta,
                                  'before': before, 'after': after,
                                  'materializations_removed':
                                  before['materializations'] - after['materializations']})
            rows.append({key: case[key] for key in
                         ('source', 'mode', 'optimization', 'census', 'delta')} | {
                             'inputs': [{'member': name, 'sha256': digest(value)}
                                        for name, value in zip(members, data)],
                             'growing_functions': functions})
    functions = [f for row in rows for f in row['growing_functions']]
    return {
        'scope': 'Static sequence counts; CMP #1 candidates are not proven carry restores.',
        'input_hashes': {str(p): digest(p.read_bytes()) for p in (review_path, archive_path)},
        'controls': controls, 'rows': rows,
        'summary': {'configurations': len(rows), 'growing_functions': len(functions),
                    'size_growth_bytes': sum(row['delta'] for row in rows),
                    'functions_with_fewer_materializations':
                    sum(f['materializations_removed'] > 0 for f in functions)}}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('disassembly', nargs='*', type=Path)
    parser.add_argument('--growth-evidence', type=Path)
    parser.add_argument('--out', type=Path)
    args = parser.parse_args()
    if bool(args.disassembly) == bool(args.growth_evidence):
        parser.error('Choose disassembly files or --growth-evidence')
    report = (growth_report(args.growth_evidence) if args.growth_evidence else
              {str(path): count(path.read_text()) for path in args.disassembly})
    output = json.dumps(report, indent=2) + '\n'
    if args.out:
        args.out.parent.mkdir(parents=True, exist_ok=True)
        args.out.write_text(output)
    else:
        print(output, end='')


if __name__ == '__main__':
    main()
