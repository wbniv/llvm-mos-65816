#!/usr/bin/env python3
"""Replay frozen carry-census commands with experimental profitability models."""

import argparse
from concurrent.futures import ThreadPoolExecutor
import gzip
import hashlib
import json
from pathlib import Path
import subprocess
import threading
import time


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def key(row):
    return tuple(row[k] for k in ('source', 'mode', 'optimization'))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('compiler', type=Path)
    parser.add_argument('census', type=Path)
    parser.add_argument('--out', required=True, type=Path)
    parser.add_argument('--variants', nargs='+', required=True,
                        help='POLICY:MODEL:OBJECTIVE, e.g. gated:weighted:size')
    parser.add_argument('--screen', action='store_true')
    parser.add_argument('--jobs', type=int, default=3)
    parser.add_argument('--resume', action='store_true')
    args = parser.parse_args()
    rows = json.loads(gzip.decompress(args.census.read_bytes()))
    if args.screen:
        paired = [r for r in rows if all('text' in r[p] for p in ('off', 'always', 'gated'))]
        selected = {key(r): r for r in paired
                    if any(r[p]['text'] > r['off']['text'] for p in ('always', 'gated'))}
        for r in sorted(paired, key=lambda r: r['gated']['text'] - r['always']['text'], reverse=True)[:100]:
            selected[key(r)] = r
        rows = list(selected.values())
    tool = args.compiler.resolve()
    out = args.out.resolve()
    out.mkdir(parents=True, exist_ok=True)
    identity = {
        'census': digest(args.census), 'screen': args.screen,
        'variants': args.variants,
        'tools': {name: digest(tool / name) for name in ('clang-23', 'llc', 'llvm-size', 'llvm-objdump')},
        'sources': {r['off']['command'][r['off']['command'].index('-c') + 1]:
                    digest(Path(r['off']['command'][r['off']['command'].index('-c') + 1])) for r in rows}}
    identity_file = out / 'identity.json'
    if args.resume:
        assert json.loads(identity_file.read_text()) == identity, 'Resume identity mismatch'
    identity_file.write_text(json.dumps(identity, indent=2) + '\n')
    journal = out / 'results.jsonl'
    results = ([json.loads(line) for line in journal.read_text().splitlines()]
               if args.resume and journal.exists() else [])
    if not args.resume:
        journal.write_text('')
    done = {key(r) for r in results}
    lock = threading.Lock()

    def measure(row):
        result = {k: row[k] for k in ('source', 'mode', 'optimization', 'off', 'always', 'gated')}
        stem = '.'.join(key(row)).replace('/', '_')
        for variant in args.variants:
            policy, model, objective = variant.split(':')
            obj = out / (stem + '.' + variant.replace(':', '-') + '.o')
            command = row['off']['command'][:]
            command[0] = str(tool / 'mos-clang')
            command[command.index('-o') + 1] = str(obj)
            command = [('-mos-carry-sched=' + policy) if a.startswith('-mos-carry-sched=') else a for a in command]
            command += ['-mllvm', '-mos-carry-cost=' + model, '-mllvm', '-mos-carry-objective=' + objective]
            entry = {'command': command}
            result[variant] = entry
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
            entry['text'] = sum(int(line.split()[1]) for line in sizes.splitlines() if line.startswith('.text'))
            dis = subprocess.check_output([str(tool / 'llvm-objdump'), '-dr', str(obj)], text=True)
            dis = '\n'.join(dis.splitlines()[3:])
            obj.with_suffix('.dis').write_text(dis)
            entry['code'] = hashlib.sha256(dis.encode()).hexdigest()
            symbols = subprocess.check_output([str(tool / 'llvm-objdump'), '-t', str(obj)], text=True)
            entry['functions'] = {p[-1]: int(p[-2], 16) for line in symbols.splitlines()
                                  if len(p := line.split()) >= 6 and p[2] == 'F'}
        with lock:
            results.append(result)
            with journal.open('a') as stream:
                stream.write(json.dumps(result) + '\n')
            if len(results) % 20 == 0:
                print(f'{len(results)}/{len(rows)} configurations', flush=True)

    with ThreadPoolExecutor(max_workers=args.jobs) as pool:
        list(pool.map(measure, [r for r in rows if key(r) not in done]))
    results.sort(key=key)
    (out / 'report.json').write_text(json.dumps(results, indent=2) + '\n')
    summary = {}
    for variant in ['always', 'gated', *args.variants]:
        paired = [r for r in results if 'text' in r[variant] and 'text' in r['off']]
        summary[variant] = {
            'paired': len(paired),
            'saving': sum(r['off']['text'] - r[variant]['text'] for r in paired),
            'growing_objects': sum(r[variant]['text'] > r['off']['text'] for r in paired),
            'growth_bytes': sum(max(0, r[variant]['text'] - r['off']['text']) for r in paired),
            'growing_functions': sum(sum(size > r['off']['functions'].get(fn, 0)
                                         for fn, size in r[variant]['functions'].items()) for r in paired),
            'changed_from_always': sum(r[variant]['code'] != r['always']['code'] for r in paired),
            'changed_from_gated': sum(r[variant]['code'] != r['gated']['code'] for r in paired),
            'policy_specific_failures': [key(r) for r in results if 'text' in r['off'] and 'text' not in r[variant]]}
    (out / 'summary.json').write_text(json.dumps(summary, indent=2) + '\n')
    print(json.dumps(summary, indent=2), flush=True)


if __name__ == '__main__':
    main()
