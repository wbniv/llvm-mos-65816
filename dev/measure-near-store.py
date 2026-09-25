#!/usr/bin/env python3
"""Compile a before/after near-store size and machine-verifier census.

Usage: measure-near-store.py BASE_TOOL CANDIDATE_TOOL --assets BUILD --out DIR
Tool arguments name directories containing mos-clang and llvm-size. The corpus
uses -Os, no LTO, and all three feature modes. Generated headers and SDK come
from --assets. Logs, objects, assembly, and a JSON report remain in --out.
"""
import argparse
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
from pathlib import Path
import subprocess


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('baseline', type=Path)
    ap.add_argument('candidate', type=Path)
    ap.add_argument('--assets', required=True, type=Path)
    ap.add_argument('--out', required=True, type=Path)
    ap.add_argument('--jobs', type=int, default=2)
    args = ap.parse_args()
    root = Path(__file__).resolve().parent.parent
    out = args.out.resolve()
    out.mkdir(parents=True, exist_ok=True)
    sources = sorted(set(root.glob('examples/65816/*.c')) |
                     set(root.glob('examples/snes/corpus/*.c')) |
                     set(root.glob('examples/snes/*.c')))
    report = []
    for mode, features in [('default', []), ('a16', ['+mos-a16']),
                           ('xy16', ['+mos-a16', '+mos-xy16'])]:
        flags = [item for feature in features
                 for item in ['-Xclang', '-target-feature', '-Xclang', feature]]
        def measure(src):
            name = str(src.relative_to(root)).replace('/', '_')[:-2]
            row = {'mode': mode, 'source': str(src.relative_to(root))}
            for label, tool in [('before', args.baseline), ('after', args.candidate)]:
                stem = out / f'{name}.{mode}.{label}'
                cmd = [str(tool / 'mos-clang'), '--config',
                       str(args.assets / 'install/bin/mos-snes.cfg'),
                       '-mcpu=mosw65816', '-Os', '-fno-lto', *flags,
                       '-mllvm', '-verify-machineinstrs',
                       '-I' + str(root / 'examples/65816'),
                       '-I' + str(root / 'examples/snes'),
                       '-I' + str(args.assets), '-I' + str(args.assets / 'seamdemo-gen'),
                       '-c', str(src), '-o', str(stem) + '.o']
                try:
                    result = subprocess.run(cmd, capture_output=True, text=True, timeout=120)
                except subprocess.TimeoutExpired:
                    Path(str(stem) + '.log').write_text('compile timed out after 120 seconds\n')
                    row[label] = {'error': 'timeout'}
                    continue
                Path(str(stem) + '.log').write_text(result.stderr)
                if result.returncode:
                    row[label] = {'error': result.returncode}
                    continue
                sizes = subprocess.check_output([str(tool / 'llvm-size'), '-A',
                                                  str(stem) + '.o'], text=True)
                text_size = sum(int(line.split()[1]) for line in sizes.splitlines()
                                if line.startswith('.text'))
                assembly = subprocess.check_output([str(tool / 'llvm-objdump'), '-dr',
                                                    str(stem) + '.o'], text=True)
                # The first line contains the object path, not code or relocations.
                assembly = '\n'.join(assembly.splitlines()[3:])
                Path(str(stem) + '.dis').write_text(assembly)
                row[label] = {'text': text_size,
                              'code': hashlib.sha256(assembly.encode()).hexdigest()}
            return row

        with ThreadPoolExecutor(max_workers=args.jobs) as pool:
            for index, row in enumerate(pool.map(measure, sources), 1):
                report.append(row)
                if index % 100 == 0:
                    print(f'{mode}: {index}/{len(sources)} compared', flush=True)
        rows = [r for r in report if r['mode'] == mode]
        paired = [r for r in rows if 'text' in r['before'] and 'text' in r['after']]
        delta = sum(r['after']['text'] - r['before']['text'] for r in paired)
        wins = [r for r in paired if r['after']['text'] < r['before']['text']]
        losses = [r for r in paired if r['after']['text'] > r['before']['text']]
        changed = [r for r in paired if r['before']['code'] != r['after']['code']]
        unpaired = [r for r in rows if ('text' in r['before']) != ('text' in r['after'])]
        print(f'{mode}: {len(paired)}/{len(rows)} paired, {len(wins)} smaller, '
              f'{len(losses)} larger, {len(changed)} code changes, {delta:+} bytes, '
              f'{len(unpaired)} unpaired', flush=True)
        for r in wins + losses + unpaired:
            print(r['source'], r['before'].get('text', 'error'),
                  r['after'].get('text', 'error'), flush=True)
        (out / 'report.json').write_text(json.dumps(report, indent=2) + '\n')


if __name__ == '__main__':
    main()
