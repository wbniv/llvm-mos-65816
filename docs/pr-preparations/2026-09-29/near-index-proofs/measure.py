#!/usr/bin/env python3
"""Replay the near-index proof census through extracted backends.

Run inside dev/container.sh. The local frontend lowers each census C input to
optimized LLVM IR once per mode (-Os, no LTO). Every backend arm then compiles
the same IR file with machine verification: the prerequisite-only baseline,
the candidate, and the candidate with recovery disabled. The report keeps
failed configurations, code hashes and every size increase. --ir-from reuses
the IR of an earlier run; --llc-flag passes a backend option to every arm, such
as the -disable-spill-hoist that the destination driver adds for MOS.
"""
import argparse
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
from pathlib import Path
import subprocess

MODES = [('default', []), ('a16', ['+mos-a16']),
         ('xy16', ['+mos-a16', '+mos-xy16'])]
INCLUDES = ('examples/65816', 'examples/snes', 'build', 'build/seamdemo-gen')


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def first_error(text):
    lines = [l for l in text.splitlines() if 'error' in l.lower()]
    return (lines or text.splitlines()[-1:] or [''])[0][:300]


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--frontend', type=Path, required=True,
                    help='directory holding the local clang')
    ap.add_argument('--baseline', type=Path, required=True)
    ap.add_argument('--candidate', type=Path, required=True)
    ap.add_argument('--census', type=Path, required=True,
                    help='census-identity.json naming the September 27 inputs')
    ap.add_argument('--out', type=Path, required=True)
    ap.add_argument('--jobs', type=int, default=4)
    ap.add_argument('--ir-from', type=Path,
                    help='directory of an earlier run whose IR files to reuse')
    ap.add_argument('--llc-flag', action='append', default=[],
                    help='backend option added to every arm')
    ap.add_argument('--discard-objects', action='store_true',
                    help='delete each object after recording its size and hash')
    args = ap.parse_args()
    root = Path(__file__).resolve().parents[4]
    out = args.out.resolve()
    out.mkdir(parents=True, exist_ok=False)
    census = json.loads(args.census.read_text())
    sources = sorted(census['sources'])
    if not sources:
        raise SystemExit('census names no inputs')
    arms = {'baseline': (args.baseline, list(args.llc_flag)),
            'candidate': (args.candidate, list(args.llc_flag)),
            'disabled': (args.candidate,
                         [*args.llc_flag, '-mos-recover-near-nowrap=false'])}
    measure_tools = args.candidate
    identity = {
        'frontend': {n: sha(args.frontend / n) for n in ('clang',)},
        'backends': {name: sha(tools / 'llc') for name, (tools, _) in arms.items()},
        'measurement_tools': {n: sha(measure_tools / n)
                              for n in ('llvm-size', 'llvm-objdump')},
        'config': sha(root / 'build/install/bin/mos-snes.cfg'),
        'llc_flags': args.llc_flag,
        'ir_from': str(args.ir_from) if args.ir_from else None,
        'sources': {s: sha(root / s) for s in sources},
        'sources_changed_since_census': [
            s for s in sources if sha(root / s) != census['sources'][s]],
    }
    (out / 'identity.json').write_text(json.dumps(identity, indent=2) + '\n')

    def run(cmd, log):
        p = subprocess.run([str(c) for c in cmd], capture_output=True, text=True,
                           timeout=180)
        log.write_text('COMMAND: ' + ' '.join(map(str, cmd)) + '\n' +
                       p.stdout + p.stderr + f'EXIT: {p.returncode}\n')
        return p

    def measure(case):
        src, mode, features = case
        stem = src.replace('/', '_') + '.' + mode
        row = {'source': src, 'mode': mode}
        ir = out / (stem + '.ll')
        if args.ir_from:
            ir = args.ir_from / (stem + '.ll')
            row['frontend_exit'] = 0 if ir.exists() else 1
            if not ir.exists():
                row['frontend_error'] = 'no IR in ' + str(args.ir_from)
                return row
        else:
            flags = [x for f in features for x in
                     ('-Xclang', '-target-feature', '-Xclang', f)]
            p = run([args.frontend / 'clang', '--config',
                     root / 'build/install/bin/mos-snes.cfg', '-mcpu=mosw65816',
                     '-Os', '-fno-lto', *flags,
                     *['-I' + str(root / d) for d in INCLUDES],
                     '-S', '-emit-llvm', root / src, '-o', ir],
                    out / (stem + '.frontend.log'))
            row['frontend_exit'] = p.returncode
            if p.returncode:
                row['frontend_error'] = first_error(p.stdout + p.stderr)
                return row
        row['ir_sha256'] = sha(ir)
        row['ir_far_address_space'] = 'addrspace(2)' in ir.read_text()
        for arm, (tools, extra) in arms.items():
            obj = out / (stem + '.' + arm + '.o')
            cmd = [tools / 'llc', '-mtriple=mos', '-mcpu=mosw65816',
                   *(['-mattr=' + ','.join(features)] if features else []),
                   '-verify-machineinstrs', *extra, '-filetype=obj', ir,
                   '-o', obj]
            p = run(cmd, out / (stem + '.' + arm + '.log'))
            entry = {'exit': p.returncode}
            row[arm] = entry
            if p.returncode:
                entry['error'] = first_error(p.stdout + p.stderr)
                continue
            sizes = subprocess.check_output(
                [str(measure_tools / 'llvm-size'), '-A', str(obj)], text=True)
            entry['text'] = sum(int(s.split()[1]) for s in sizes.splitlines()
                                if s.startswith('.text'))
            dis = subprocess.check_output(
                [str(measure_tools / 'llvm-objdump'), '-dr', str(obj)], text=True)
            entry['code_sha256'] = hashlib.sha256(
                '\n'.join(dis.splitlines()[3:]).encode()).hexdigest()
            if args.discard_objects:
                obj.unlink()
        return row

    cases = [(s, m, f) for m, f in MODES for s in sources]
    rows = []
    with ThreadPoolExecutor(max_workers=args.jobs) as pool:
        for i, row in enumerate(pool.map(measure, cases), 1):
            rows.append(row)
            if i % 100 == 0:
                print(f'{i}/{len(cases)} configurations', flush=True)
    (out / 'report.json').write_text(json.dumps(rows, indent=2) + '\n')
    summary = summarize(rows, len(sources))
    (out / 'summary.json').write_text(json.dumps(summary, indent=2) + '\n')
    print(json.dumps(summary['modes'], indent=2))


def summarize(rows, inputs):
    ok = lambda r, a: 'text' in r.get(a, {})
    modes = {}
    for mode, _ in MODES:
        mine = [r for r in rows if r['mode'] == mode]
        paired = [r for r in mine if ok(r, 'baseline') and ok(r, 'candidate')]
        delta = [r['candidate']['text'] - r['baseline']['text'] for r in paired]
        modes[mode] = {
            'inputs': inputs,
            'frontend_failures': sum(r['frontend_exit'] != 0 for r in mine),
            'paired': len(paired),
            'baseline_bytes': sum(r['baseline']['text'] for r in paired),
            'candidate_bytes': sum(r['candidate']['text'] for r in paired),
            'delta': sum(delta),
            'smaller': sum(d < 0 for d in delta),
            'larger': sum(d > 0 for d in delta),
            'code_changed': sum(r['baseline']['code_sha256'] !=
                                r['candidate']['code_sha256'] for r in paired),
            'baseline_only_failures': sum(ok(r, 'candidate') and not ok(r, 'baseline')
                                          for r in mine if r['frontend_exit'] == 0),
            'candidate_only_failures': sum(ok(r, 'baseline') and not ok(r, 'candidate')
                                           for r in mine if r['frontend_exit'] == 0),
            'both_arms_failed': sum(not ok(r, 'baseline') and not ok(r, 'candidate')
                                    for r in mine if r['frontend_exit'] == 0),
        }
    both = [r for r in rows if ok(r, 'baseline') and ok(r, 'disabled')]
    larger = sorted(
        ({'source': r['source'], 'mode': r['mode'],
          'growth': r['candidate']['text'] - r['baseline']['text'],
          'ir_far_address_space': r['ir_far_address_space']}
         for r in rows if ok(r, 'baseline') and ok(r, 'candidate') and
         r['candidate']['text'] > r['baseline']['text']),
        key=lambda x: (x['mode'], x['source']))
    return {
        'modes': modes,
        'disabled_matches_baseline': sum(r['disabled']['code_sha256'] ==
                                         r['baseline']['code_sha256'] for r in both),
        'disabled_compared': len(both),
        'disabled_exit_mismatches': sum(
            r.get('disabled', {}).get('exit') != r.get('baseline', {}).get('exit')
            for r in rows if r['frontend_exit'] == 0),
        'larger': larger,
    }


if __name__ == '__main__':
    main()
