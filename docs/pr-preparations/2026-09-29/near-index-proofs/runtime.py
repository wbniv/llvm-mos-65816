#!/usr/bin/env python3
"""Run near-index runtime fixtures with an extracted backend on both cores.

Run inside dev/container.sh under `ulimit -c 0`. The local frontend lowers C to
IR without LTO, the extracted llc selects every fixture instruction, and the
existing SNES linker/startup libraries build the ROM. Fixtures are the
near-only Y-lifetime decoder, a bank-wrap witness without far pointers, and the
replay's corpus programs whose code the candidate changes and whose IR has no
far address space. Each candidate ROM is checked on MAME and bsnes-jg against a
manifest or host oracle. The comparison backend only compiles: it records
whether the candidate changed the code and whether a compile failure is shared.
"""
import argparse
from concurrent.futures import ThreadPoolExecutor
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import subprocess
import threading

MODES = [('default', []), ('a16', ['+mos-a16']),
         ('xy16', ['+mos-a16', '+mos-xy16'])]
INCLUDES = ('examples/65816', 'examples/snes', 'build', 'build/seamdemo-gen')


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--llc', type=Path, required=True)
    ap.add_argument('--compare-llc', type=Path, required=True)
    ap.add_argument('--replay', type=Path, required=True,
                    help='report.json written by measure.py')
    ap.add_argument('--out', type=Path, required=True)
    ap.add_argument('--llc-flag', action='append', default=[],
                    help='backend option passed to both llc invocations')
    ap.add_argument('--jobs', type=int, default=3)
    ap.add_argument('--frames', type=int, default=1000,
                    help='emulated frames before each core reads the result')
    args = ap.parse_args()
    here = Path(__file__).resolve().parent
    root = here.parents[3]
    out = args.out.resolve()
    out.mkdir(parents=True, exist_ok=False)
    spec = importlib.util.spec_from_file_location('fuzz', root / 'tools/a16_fuzz.py')
    fuzz = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(fuzz)
    # The emulator helpers read these at call time; one value serves every job.
    os.environ['BSNES_FRAMES'] = str(args.frames)
    os.environ['SMOKE_SETTLE'] = str(args.frames)
    clang = fuzz.TOOL / 'clang'
    objdump = args.llc.parent / 'llvm-objdump'
    lock = threading.Lock()
    commands, results = [], []

    def run(cmd, stem):
        cmd = list(map(str, cmd))
        p = subprocess.run(cmd, capture_output=True, text=True, timeout=300)
        (out / (stem + '.log')).write_text(
            'COMMAND: ' + ' '.join(cmd) + '\n' + p.stdout + p.stderr +
            f'EXIT: {p.returncode}\n')
        with lock:
            commands.append({'command': cmd, 'exit_code': p.returncode})
        return p

    def record(row):
        with lock:
            results.append(row)
            (out / 'results.json').write_text(json.dumps(results, indent=2) + '\n')
        print(row, flush=True)

    manifest = {}
    for line in (root / 'examples/snes/corpus/expected.tsv').read_text().splitlines():
        parts = line.split()
        if line.startswith('#') or len(parts) < 3:
            continue
        manifest['examples/snes/' + parts[0]] = (int(parts[2], 16), 'manifest')

    def host_oracle(src):
        name = Path(src).stem.removesuffix('_sim').replace('bf_vm', 'bf-vm')
        tool = root / 'tools' / (name + '-sim.c')
        if not tool.exists():
            return None
        host = out / (name + '-host')
        p = run(['cc', '-O2', '-I' + str(root / 'examples/65816'), tool, '-o', host,
                 '-lm'], name + '-host-build')
        if p.returncode:
            return None
        found = re.findall(r'0x[0-9A-Fa-f]{4}', run([host], name + '-host-run').stdout)
        return (int(found[-1], 16), 'host') if found else None

    rows = json.loads(args.replay.read_text())
    changed = sorted({r['source'] for r in rows
                      if '/corpus/' in r['source'] and
                      'code_sha256' in r.get('baseline', {}) and
                      'code_sha256' in r.get('candidate', {}) and
                      r['baseline']['code_sha256'] != r['candidate']['code_sha256']})
    far = {r['source'] for r in rows if r.get('ir_far_address_space')}
    fixtures = [
        ('examples/65816/near-y-decode.c', 0x5CF0, 'fixture', '-Oz'),
        (str((here / 'near-index-wrap-near.c').relative_to(root)), 0x5CF0,
         'fixture', '-Oz'),
    ]
    skipped = []
    for src in changed:
        if src in far:
            skipped.append({'source': src, 'reason': 'IR uses addrspace(2)'})
            continue
        oracle = manifest.get(src) or host_oracle(src)
        if oracle is None:
            skipped.append({'source': src, 'reason': 'no manifest or buildable host oracle'})
            continue
        fixtures.append((src, oracle[0], oracle[1], '-Os'))

    identity = {'llc_sha256': sha(args.llc),
                'compare_llc_sha256': sha(args.compare_llc),
                'llc_flags': args.llc_flag, 'frames': args.frames,
                'frontend_sha256': sha(clang),
                'linker_sha256': sha(fuzz.TOOL / 'ld.lld'),
                'config_sha256': sha(fuzz.CFG), 'lto': False,
                'fixtures': {src: {'sha256': sha(root / src), 'expected': f'0x{want:04X}',
                                   'oracle': kind, 'opt': opt}
                             for src, want, kind, opt in fixtures},
                'skipped': skipped}
    (out / 'identity.json').write_text(json.dumps(identity, indent=2) + '\n')

    def code_hash(obj):
        dis = subprocess.check_output([str(objdump), '-dr', str(obj)], text=True)
        return hashlib.sha256('\n'.join(dis.splitlines()[3:]).encode()).hexdigest()

    def check(job):
        src, want, kind, opt, mode, features = job
        stem = Path(src).stem + '-' + mode
        base = {'source': src, 'mode': mode, 'expected': f'0x{want:04X}', 'oracle': kind}
        ir, obj = out / (stem + '.ll'), out / (stem + '.o')
        ref = out / (stem + '.compare.o')
        rom, mapfile = out / (stem + '.sfc'), out / (stem + '.map')
        flags = [a for f in features for a in
                 ['-Xclang', '-target-feature', '-Xclang', f]]
        p = run([clang, '--config', fuzz.CFG, '-mcpu=mosw65816', opt, '-fno-lto',
                 *flags, *['-I' + str(root / d) for d in INCLUDES],
                 '-S', '-emit-llvm', root / src, '-o', ir], stem + '-frontend')
        if p.returncode:
            return record(base | {'status': 'frontend-failed'})
        backend = ['-mtriple=mos', '-mcpu=mosw65816', '-verify-machineinstrs',
                   *args.llc_flag,
                   *(['-mattr=' + ','.join(features)] if features else []),
                   '-filetype=obj', ir]
        compared = run([args.compare_llc, *backend, '-o', ref],
                       stem + '-compare-backend').returncode == 0
        p = run([args.llc, *backend, '-o', obj], stem + '-backend')
        if p.returncode:
            return record(base | {'status': 'compile-failed', 'compare_compiled': compared,
                                  'error': (p.stderr.strip().splitlines() or [''])[0][:300]})
        changed_code = compared and code_hash(obj) != code_hash(ref)
        p = run([clang, '--config', fuzz.CFG, '-mcpu=mosw65816', '-fno-lto',
                 '-Wl,-Map=' + str(mapfile), obj, '-o', rom], stem + '-link')
        if p.returncode or run(['python3', fuzz.CHECKSUM, rom], stem + '-checksum').returncode:
            return record(base | {'status': 'link-failed', 'code_changed': changed_code})
        address, size = fuzz.map_lookup(mapfile, 'corpus_result')
        if address is None or size != 2:
            return record(base | {'status': 'no-result-symbol', 'code_changed': changed_code})
        for core in ('mame', 'bsnes-jg'):
            if core == 'mame':
                got, log = fuzz.run_mame(rom, 0x7E0000 + address, want, size)
            else:
                got, log = fuzz.run_bsnes(rom, address, size, want)
            (out / (stem + '-' + core + '.txt')).write_text(str(log) + '\n')
            got = None if got in (None, 'skip') else f'0x{got:04X}'
            record(base | {'core': core, 'got': got,
                           'status': 'pass' if got == base['expected'] else 'mismatch',
                           'code_changed': changed_code, 'rom_sha256': sha(rom)})

    jobs = [(src, want, kind, opt, mode, features)
            for src, want, kind, opt in fixtures for mode, features in MODES]
    with ThreadPoolExecutor(max_workers=args.jobs) as pool:
        list(pool.map(check, jobs))
    (out / 'commands.json').write_text(json.dumps(commands, indent=2) + '\n')
    count = lambda status: sum(r['status'] == status for r in results)
    shared = sum(r['status'] == 'compile-failed' and not r['compare_compiled'] for r in results)
    summary = {'jobs': len(jobs), 'core_checks_pass': count('pass'),
               'core_checks_mismatch': count('mismatch'),
               'compile_failed_both': shared,
               'compile_failed_candidate_only': count('compile-failed') - shared,
               'other_failures': count('frontend-failed') + count('link-failed') + count('no-result-symbol'),
               'changed_code_builds': len({(r['source'], r['mode']) for r in results
                                           if r.get('code_changed')})}
    (out / 'summary.json').write_text(json.dumps(summary, indent=2) + '\n')
    print(json.dumps(summary), flush=True)
    bad = summary['core_checks_mismatch'] + summary['compile_failed_candidate_only'] + summary['other_failures']
    raise SystemExit(1 if bad else 0)


if __name__ == '__main__':
    main()
