#!/usr/bin/env python3
"""Replay a MOS census with off, always and gated carry scheduling."""

import argparse
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
from pathlib import Path
import subprocess
import threading
import time


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('compiler', type=Path)
    parser.add_argument('reports', nargs='+', type=Path)
    parser.add_argument('--out', required=True, type=Path)
    parser.add_argument('--jobs', type=int, default=3)
    parser.add_argument('--complete-o2', action='store_true')
    parser.add_argument('--resume', action='store_true')
    args = parser.parse_args()
    tool = args.compiler.resolve()
    out = args.out.resolve()
    out.mkdir(parents=True, exist_ok=True)
    cases = {}
    for report in args.reports:
        for row in json.loads(report.read_text()):
            key = (row['source'], row['mode'], row['optimization'])
            cases[key] = row
            if args.complete_o2 and row['optimization'] == 'Os':
                command = ['-O2' if value == '-Os' else value
                           for value in row['after']['command']]
                cases[(row['source'], row['mode'], 'O2')] = {
                    **row, 'optimization': 'O2', 'after': {'command': command}}
    identity = {
        'tools': {name: digest(tool / name) for name in
                  ('clang-23', 'llc', 'llvm-size', 'llvm-objdump')},
        'reports': {str(path): digest(path) for path in args.reports},
        'complete_o2': args.complete_o2,
        'sources': {row['after']['command'][row['after']['command'].index('-c') + 1]:
                    digest(Path(row['after']['command'][row['after']['command'].index('-c') + 1]))
                    for row in cases.values()},
        'policies': ['off', 'always', 'gated']}
    identity_path = out / 'identity.json'
    if args.resume and identity_path.exists():
        if json.loads(identity_path.read_text()) != identity:
            raise ValueError('Resume requires identical tools, reports and source inputs')
    identity_path.write_text(json.dumps(identity, indent=2) + '\n')
    journal = out / 'results.jsonl'
    results = ([json.loads(line) for line in journal.read_text().splitlines()]
               if args.resume and journal.exists() else [])
    if not args.resume:
        journal.write_text('')
    completed = {(row['source'], row['mode'], row['optimization']) for row in results}
    pending = [row for key, row in cases.items() if key not in completed]
    lock = threading.Lock()

    def measure(case):
        result = {key: case[key] for key in ('source', 'mode', 'optimization')}
        stem = case['source'].replace('/', '_') + '.' + case['mode'] + '.' + case['optimization']
        for policy in identity['policies']:
            obj = out / (stem + '.' + policy + '.o')
            command = case['after']['command'][:]
            command[0] = str(tool / 'mos-clang')
            command[command.index('-o') + 1] = str(obj)
            command += ['-mllvm', '-mos-carry-sched=' + policy]
            entry = {'command': command}
            result[policy] = entry
            start = time.monotonic()
            try:
                process = subprocess.run(command, capture_output=True, text=True, timeout=120)
            except subprocess.TimeoutExpired:
                entry['exit_code'] = 'timeout'
                obj.with_suffix('.log').write_text('timeout after 120 seconds\n')
                continue
            entry['exit_code'] = process.returncode
            entry['elapsed_seconds'] = time.monotonic() - start
            obj.with_suffix('.log').write_text(process.stdout + process.stderr)
            if process.returncode:
                continue
            entry['object_sha256'] = digest(obj)
            sizes = subprocess.check_output([str(tool / 'llvm-size'), '-A', str(obj)], text=True)
            entry['text'] = sum(int(line.split()[1]) for line in sizes.splitlines()
                                if line.startswith('.text'))
            disassembly = subprocess.check_output([str(tool / 'llvm-objdump'), '-dr', str(obj)], text=True)
            disassembly = '\n'.join(disassembly.splitlines()[3:])
            obj.with_suffix('.dis').write_text(disassembly)
            entry['code'] = hashlib.sha256(disassembly.encode()).hexdigest()
            symbols = subprocess.check_output([str(tool / 'llvm-objdump'), '-t', str(obj)], text=True)
            entry['functions'] = {parts[-1]: int(parts[-2], 16)
                                  for line in symbols.splitlines()
                                  if len(parts := line.split()) >= 6 and parts[2] == 'F'}
        with lock:
            results.append(result)
            with journal.open('a') as stream:
                stream.write(json.dumps(result) + '\n')
            if len(results) % 100 == 0:
                print(f'{len(results)}/{len(cases)} configurations', flush=True)

    with ThreadPoolExecutor(max_workers=args.jobs) as pool:
        list(pool.map(measure, pending))
    results.sort(key=lambda row: (row['optimization'], row['mode'], row['source']))
    (out / 'report.json').write_text(json.dumps(results, indent=2) + '\n')
    summaries = []
    for mode, opt in sorted({(row['mode'], row['optimization']) for row in results}):
        rows = [row for row in results if (row['mode'], row['optimization']) == (mode, opt)]
        paired = [row for row in rows if all('text' in row[p] for p in identity['policies'])]
        summary = {'mode': mode, 'optimization': opt, 'inputs': len(rows), 'paired': len(paired),
                   'unpaired': [row['source'] for row in rows
                                if len({row[p]['exit_code'] for p in identity['policies']}) > 1]}
        for policy in ('always', 'gated'):
            summary[policy] = {
                'delta': sum(row[policy]['text'] - row['off']['text'] for row in paired),
                'smaller': sum(row[policy]['text'] < row['off']['text'] for row in paired),
                'larger': sum(row[policy]['text'] > row['off']['text'] for row in paired),
                'code_changes': sum(row[policy]['code'] != row['off']['code'] for row in paired)}
        summaries.append(summary)
    (out / 'summary.json').write_text(json.dumps(summaries, indent=2) + '\n')
    print(json.dumps(summaries, indent=2), flush=True)


if __name__ == '__main__':
    main()
