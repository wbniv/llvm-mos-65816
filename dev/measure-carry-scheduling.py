#!/usr/bin/env python3
"""Compare verified non-LTO code generation with two identified MOS toolchains."""

import argparse
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
from pathlib import Path
import re
import subprocess


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('baseline', type=Path)
    ap.add_argument('candidate', type=Path)
    ap.add_argument('--assets', required=True, type=Path)
    ap.add_argument('--out', required=True, type=Path)
    ap.add_argument('--jobs', type=int, default=3)
    ap.add_argument('--opts', nargs='+', default=['Os', 'Oz'])
    ap.add_argument('--modes', nargs='+', default=['default', 'a16', 'xy16'])
    ap.add_argument('--sources', type=Path, help='JSON list of repository paths')
    args = ap.parse_args()
    root = Path(__file__).resolve().parent.parent
    out = args.out.resolve()
    out.mkdir(parents=True, exist_ok=True)
    sources = ([root / p for p in json.loads(args.sources.read_text())]
               if args.sources else sorted(set(root.glob('examples/65816/*.c')) |
                                           set(root.glob('examples/snes/corpus/*.c')) |
                                           set(root.glob('examples/snes/*.c'))))
    tools = {'before': args.baseline.resolve(), 'after': args.candidate.resolve()}
    metadata = {'tools': {label: {n: digest(tool / n) for n in
                                 ['mos-clang', 'llvm-size', 'llvm-objdump']}
                          for label, tool in tools.items()},
                'sources': {str(p.relative_to(root)): digest(p) for p in sources}}
    (out / 'identity.json').write_text(json.dumps(metadata, indent=2) + '\n')
    features = {'default': [], 'a16': ['+mos-a16'],
                'xy16': ['+mos-a16', '+mos-xy16'], '6502': []}
    report = []
    summaries = []
    for opt in args.opts:
        for mode in args.modes:
            flags = [v for f in features[mode]
                     for v in ['-Xclang', '-target-feature', '-Xclang', f]]

            def measure(src):
                rel = str(src.relative_to(root))
                row = {'mode': mode, 'optimization': opt, 'source': rel}
                for label, tool in tools.items():
                    stem = out / (rel.replace('/', '_') + f'.{mode}.{opt}.{label}')
                    cmd = [str(tool / 'mos-clang'), '--config',
                           str(args.assets.resolve() / 'install/bin/mos-snes.cfg'),
                           '-mcpu=' + ('mos6502' if mode == '6502' else 'mosw65816'),
                           '-' + opt, '-fno-lto', *flags, '-mllvm',
                           '-verify-machineinstrs', '-I' + str(root / 'examples/65816'),
                           '-I' + str(root / 'examples/snes'),
                           '-I' + str(root / 'examples/snes/corpus'),
                           '-I' + str(args.assets.resolve()),
                           '-I' + str(args.assets.resolve() / 'seamdemo-gen'),
                           '-c', str(src), '-o', str(stem) + '.o']
                    entry = {'command': cmd}
                    row[label] = entry
                    try:
                        p = subprocess.run(cmd, capture_output=True, text=True, timeout=120)
                    except subprocess.TimeoutExpired:
                        entry['error'] = 'timeout'
                        Path(str(stem) + '.log').write_text('timeout after 120 seconds\n')
                        continue
                    Path(str(stem) + '.log').write_text(p.stdout + p.stderr)
                    if p.returncode:
                        entry['error'] = p.returncode
                        entry['diagnostic'] = next((s for s in p.stderr.splitlines()
                                                    if 'error:' in s), p.stderr[:200])
                        continue
                    sizes = subprocess.check_output([str(tool / 'llvm-size'), '-A',
                                                      str(stem) + '.o'], text=True)
                    entry['text'] = sum(int(s.split()[1]) for s in sizes.splitlines()
                                        if s.startswith('.text'))
                    dis = subprocess.check_output([str(tool / 'llvm-objdump'), '-dr',
                                                    str(stem) + '.o'], text=True)
                    dis = '\n'.join(dis.splitlines()[3:])
                    Path(str(stem) + '.dis').write_text(dis)
                    entry['code'] = hashlib.sha256(dis.encode()).hexdigest()
                    entry['rep_sep'] = len(re.findall(r'\t(?:rep|sep)\s', dis))
                    syms = subprocess.check_output([str(tool / 'llvm-objdump'), '-t',
                                                     str(stem) + '.o'], text=True)
                    entry['functions'] = {parts[-1]: int(parts[-2], 16)
                                          for line in syms.splitlines()
                                          if len(parts := line.split()) >= 6
                                          and parts[2] == 'F'}
                return row

            with ThreadPoolExecutor(max_workers=args.jobs) as pool:
                rows = list(pool.map(measure, sources))
            report.extend(rows)
            paired = [r for r in rows if all('text' in r[k] for k in tools)]
            summary = {'optimization': opt, 'mode': mode, 'inputs': len(rows),
                       'paired': len(paired),
                       'smaller': sum(r['after']['text'] < r['before']['text'] for r in paired),
                       'larger': sum(r['after']['text'] > r['before']['text'] for r in paired),
                       'code_changes': sum(r['after']['code'] != r['before']['code'] for r in paired),
                       'delta': sum(r['after']['text'] - r['before']['text'] for r in paired),
                       'unpaired': [r['source'] for r in rows
                                    if ('text' in r['before']) != ('text' in r['after'])]}
            summaries.append(summary)
            print(json.dumps(summary), flush=True)
            (out / 'report.json').write_text(json.dumps(report, indent=2) + '\n')
            (out / 'summary.json').write_text(json.dumps(summaries, indent=2) + '\n')


if __name__ == '__main__':
    main()
