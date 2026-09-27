#!/usr/bin/env python3
"""Measure near-index proof recovery with the same compiler and input corpus.

Run inside dev/container.sh. Objects, diagnostics, commands and tool identities
remain in --out. Both arms enable machine verification; only proof recovery
differs. The report includes failed configurations as well as paired sizes.
"""
import argparse
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
from pathlib import Path
import subprocess


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--tool', type=Path, default=Path('/work/build/llvm-mos/bin'))
    ap.add_argument('--out', type=Path, required=True)
    ap.add_argument('--jobs', type=int, default=2)
    args = ap.parse_args()
    root = Path(__file__).resolve().parent.parent
    out = args.out.resolve()
    out.mkdir(parents=True, exist_ok=True)
    tool = args.tool.resolve()
    sources = sorted(set(root.glob('examples/65816/*.c')) |
                     set(root.glob('examples/snes/corpus/*.c')) |
                     set(root.glob('examples/snes/*.c')))
    sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
    identity = {'tools': {n: sha(tool / n) for n in
                         ('clang', 'llvm-size', 'llvm-objdump')},
                'sources': {str(p.relative_to(root)): sha(p) for p in sources}}
    (out / 'identity.json').write_text(json.dumps(identity, indent=2) + '\n')

    def measure(case):
        src, mode, features = case
        row = {'source': str(src.relative_to(root)), 'mode': mode}
        flags = [x for f in features for x in
                 ('-Xclang', '-target-feature', '-Xclang', f)]
        stem = str(src.relative_to(root)).replace('/', '_') + '.' + mode
        for arm, enable in [('before', 'false'), ('after', 'true')]:
            obj = out / (stem + '.' + arm + '.o')
            cmd = [str(tool / 'clang'), '--config',
                   str(root / 'build/install/bin/mos-snes.cfg'),
                   '-mcpu=mosw65816', '-Os', '-fno-lto', *flags,
                   '-mllvm', '-verify-machineinstrs', '-mllvm',
                   '-mos-recover-near-nowrap=' + enable,
                   *['-I' + str(root / d) for d in
                     ('examples/65816', 'examples/snes', 'build',
                      'build/seamdemo-gen')], '-c', str(src), '-o', str(obj)]
            entry = {'command': cmd}
            row[arm] = entry
            try:
                p = subprocess.run(cmd, capture_output=True, text=True, timeout=120)
            except subprocess.TimeoutExpired:
                entry['error'] = 'timeout'
                continue
            entry['exit_code'] = p.returncode
            obj.with_suffix('.log').write_text(p.stdout + p.stderr)
            if p.returncode:
                continue
            sizes = subprocess.check_output([str(tool / 'llvm-size'), '-A',
                                             str(obj)], text=True)
            entry['text'] = sum(int(s.split()[1]) for s in sizes.splitlines()
                                if s.startswith('.text'))
            dis = subprocess.check_output([str(tool / 'llvm-objdump'), '-dr',
                                           str(obj)], text=True)
            entry['code_sha256'] = hashlib.sha256(
                '\n'.join(dis.splitlines()[3:]).encode()).hexdigest()
        return row

    modes = [('default', []), ('a16', ['+mos-a16']),
             ('xy16', ['+mos-a16', '+mos-xy16'])]
    cases = [(src, mode, features) for mode, features in modes for src in sources]
    rows = []
    with ThreadPoolExecutor(max_workers=args.jobs) as pool:
        for i, row in enumerate(pool.map(measure, cases), 1):
            rows.append(row)
            if i % 100 == 0:
                print(f'{i}/{len(cases)} configurations', flush=True)
                (out / 'report.json').write_text(json.dumps(rows, indent=2) + '\n')
    (out / 'report.json').write_text(json.dumps(rows, indent=2) + '\n')
    for mode, _ in modes:
        paired = [r for r in rows if r['mode'] == mode and
                  all('text' in r[a] for a in ('before', 'after'))]
        totals = [sum(r[a]['text'] for r in paired) for a in ('before', 'after')]
        delta = [r['after']['text'] - r['before']['text'] for r in paired]
        print(f'{mode}: {len(paired)}/{len(sources)} paired, '
              f'{totals[0]} -> {totals[1]} bytes, delta {sum(delta):+}, '
              f'{sum(d < 0 for d in delta)} smaller, '
              f'{sum(d > 0 for d in delta)} larger', flush=True)


if __name__ == '__main__':
    main()
