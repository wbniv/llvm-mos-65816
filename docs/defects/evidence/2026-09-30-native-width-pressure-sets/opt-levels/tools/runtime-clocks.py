#!/usr/bin/env python3
"""Master clocks of corpus sims per optimization level, llc variant and mode.

usage: runtime-clocks.py OUTDIR --level L [--level L ...] --variant NAME=LLC[:FLAG]
       [--variant ...] [--sim NAME ...] [--modes a16,a16xy16] [--jobs N]

Runs inside the dev container (paths are /work/...). Per sim and level, the
installed project clang (build/llvm-mos-install/bin/clang, mos-snes.cfg,
-mcpu=mosw65816, no target features, -fno-lto) emits IR from the current
source at that level; target-cpu/target-features attributes are stripped, as
for the frozen fixed set. Each llc variant compiles that IR per mode at llc
-O2 (-O3 for level O3; clang -Os/-Oz also codegen at -O2), the installed
mos-clang links it with the installed SDK at -Os (identical library code for
every variant), and the bsnes-jg cycle probe (dev/jgxcycles.cpp, built by
dev/build-cycle-probe.py) measures master clocks from main's entry to the
instruction that writes the expected corpus_result: Policy 0070's region.
A variant whose object is byte-identical to an already measured object reuses
its clocks (cache.json persists them, so a rerun resumes). Every compiler/linker runs under ulimit -v 2000000 and a timeout.
Writes OUTDIR/results.tsv and OUTDIR/identity.json.
"""
import argparse
import hashlib
import json
import os
import re
import resource
import subprocess
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

W = Path('/work')
TOOL = W / 'build/llvm-mos-install/bin'
CFG = W / 'build/install/bin/mos-snes.cfg'
PROBE = W / 'build/pressure-sets/opt-levels/probe/jgxcycles'
DB = W / 'vendor/bsnes-jg/Database'
SIZE = W / 'build/pressure-sets/build/bin/llvm-size'
OBJDUMP = W / 'build/pressure-sets/build/bin/llvm-objdump'
MODES = {'default': '', 'a16': '+mos-a16', 'a16xy16': '+mos-a16,+mos-xy16'}
SIMS = ['avalanche_sim', 'boids_sim', 'cgrade_sim', 'critters_sim', 'domcol_sim',
        'fenwick_sim', 'grid3d_sim', 'jt256_sim', 'lzdec_sim', 'montorbit_sim',
        'nmitally_sim', 'perlin_sim', 'rangecode_sim', 'satcast_sim', 'sodo_sim',
        'tea_sim', 'ulam_sim']


def sha(p):
    return hashlib.sha256(Path(p).read_bytes()).hexdigest()


def limit():
    resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
    resource.setrlimit(resource.RLIMIT_AS, (2000000 * 1024, 2000000 * 1024))


def run(cmd, timeout=300, capped=True):
    p = subprocess.run([str(c) for c in cmd], capture_output=True, text=True,
                       timeout=timeout, preexec_fn=limit if capped else None)
    return p.returncode, p.stdout, p.stderr


def expected_values(out):
    table = {}
    for line in (W / 'examples/snes/corpus/expected.tsv').read_text().splitlines():
        f = line.split()
        if len(f) >= 3 and f[0].startswith('corpus/'):
            table[f[0][7:-2]] = int(f[2], 16)
    got = {}
    for sim in SIMS:
        if sim in table:
            got[sim] = (table[sim], 'expected.tsv')
            continue
        base = sim[:-4]
        exe = out / 'oracle' / base
        exe.parent.mkdir(exist_ok=True)
        rc, o, e = run(['cc', '-O2', '-I', W / 'examples/65816', W / f'tools/{base}-sim.c',
                        '-o', exe, '-lm'], capped=False)
        assert rc == 0, e
        rc, o, e = run([exe], capped=False)
        assert rc == 0, e
        got[sim] = (int(re.findall(r'0x[0-9a-fA-F]+', o)[-1], 16), f'tools/{base}-sim.c')
    return got


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('out', type=Path)
    ap.add_argument('--level', action='append', required=True)
    ap.add_argument('--variant', action='append', required=True)
    ap.add_argument('--sim', action='append')
    ap.add_argument('--modes', default='a16,a16xy16')
    ap.add_argument('--jobs', type=int, default=3)
    a = ap.parse_args()
    out = a.out.resolve()
    out.mkdir(parents=True, exist_ok=True)
    variants = []
    for v in a.variant:
        name, spec = v.split('=', 1)
        llc, _, flag = spec.partition(':')
        variants.append((name, W / llc, flag))
    sims = a.sim or SIMS
    modes = a.modes.split(',')
    exp = expected_values(out)
    identity = {'clang': sha(TOOL / 'clang-23'), 'mos-clang-cfg': sha(CFG),
                'probe': sha(PROBE), 'llvm-size': sha(SIZE),
                'llcs': {n: {'path': str(l), 'sha256': sha(l), 'flag': f}
                         for n, l, f in variants},
                'sources': {s: sha(W / f'examples/snes/corpus/{s}.c') for s in sims},
                'expected': {s: [hex(exp[s][0]), exp[s][1]] for s in sims}}
    (out / 'identity.json').write_text(json.dumps(identity, indent=2) + '\n')

    def emit_ir(job):
        sim, level = job
        ir = out / 'ir' / f'{sim}.{level}.ll'
        ir.parent.mkdir(exist_ok=True)
        rc, o, e = run([TOOL / 'clang', '--config', CFG, '-mcpu=mosw65816', '-' + level,
                        '-fno-lto', '-I' + str(W / 'examples/65816'),
                        '-I' + str(W / 'examples/snes'), '-I' + str(W / 'build'),
                        '-I' + str(W / 'build/seamdemo-gen'), '-S', '-emit-llvm',
                        W / f'examples/snes/corpus/{sim}.c', '-o', ir])
        if rc:
            return job, None, f'clang rc={rc}: {e[-300:]}'
        text = re.sub(r' ?"target-(cpu|features)"="[^"]*"', '', ir.read_text())
        ir.write_text(text)
        return job, ir, None

    with ThreadPoolExecutor(a.jobs) as pool:
        irs = {j: (ir, err) for j, ir, err in
               pool.map(emit_ir, [(s, l) for s in sims for l in a.level])}

    cache_file = out / 'cache.json'
    cache = ({tuple(k.split('|')): v for k, v in json.loads(cache_file.read_text()).items()}
             if cache_file.exists() else {})

    def save_cache():
        cache_file.write_text(json.dumps({'|'.join(k): v for k, v in list(cache.items())}, indent=1))

    def measure(job):
        sim, level, (vname, llc, flag), mode = job
        ir, err = irs[(sim, level)]
        row = {'sim': sim, 'level': level, 'variant': vname, 'mode': mode}
        if err:
            return {**row, 'status': 'clang-fail', 'detail': err}
        stem = out / 'rom' / f'{sim}.{level}.{vname}.{mode}'
        stem.parent.mkdir(exist_ok=True)
        obj = Path(str(stem) + '.o')
        attr = ['-mattr=' + MODES[mode]] if MODES[mode] else []
        ol = '-O3' if level == 'O3' else '-O2'
        rc, o, e = run([llc, '-mtriple=mos', '-mcpu=mosw65816', *attr, ol,
                        *([flag] if flag else []), '-filetype=obj', ir, '-o', obj], 120)
        if rc:
            return {**row, 'status': f'llc-fail rc={rc}', 'detail': e.strip().splitlines()[:1]}
        rc, o, e = run([SIZE, '-A', obj], capped=False)
        row['bytes'] = sum(int(l.split()[1]) for l in o.splitlines()
                           if re.match(r'^\.(text|data|rodata)', l))
        row['obj_sha256'] = sha(obj)[:16]
        key = (sim, level, mode, row['obj_sha256'])
        if key in cache:
            return {**row, **cache[key], 'reused': True}
        rom = Path(str(stem) + '.sfc')
        cf = []
        for f in filter(None, MODES[mode].split(',')):
            cf += ['-Xclang', '-target-feature', '-Xclang', f]
        rc, o, e = run([TOOL / 'mos-clang', '--config', CFG, '-mcpu=mosw65816', *cf, '-Os',
                        obj, f'-Wl,-Map={stem}.map', '-o', rom])
        if rc:
            return {**row, 'status': f'link-fail rc={rc}', 'detail': e[-300:]}
        rc, o, e = run(['python3', W / 'tools/snes-checksum.py', rom], capped=False)
        if rc:
            return {**row, 'status': 'checksum-fail'}
        rc, o, e = run([OBJDUMP, '-t', str(rom) + '.elf'], capped=False)
        syms = {}
        for l in o.splitlines():
            p = l.split()
            if len(p) >= 5 and re.fullmatch('[0-9a-f]{8}', p[0]):
                hexes = [f for f in p[1:-1] if re.fullmatch('[0-9a-f]{8}', f)]
                if hexes:
                    syms[p[-1]] = (int(p[0], 16), int(hexes[-1], 16))
        start, size = syms['main']
        addr, length = syms['corpus_result']
        off = addr - 0x7e0000 if addr >= 0x7e0000 else addr
        want = exp[sim][0]
        runs = []
        for k in range(2):
            rc, o, e = run([PROBE, rom, DB, hex(start), hex(start + size), '0xffffffff',
                            hex(off), length, hex(want), 3000, 1], 600, capped=False)
            try:
                runs.append(json.loads(o))
            except ValueError:
                return {**row, 'status': f'probe rc={rc}', 'detail': (o + e)[-300:]}
        det = runs[0] == runs[1]
        r = runs[0]
        res = {'status': 'PASS' if r['pass'] else f"FAIL got={hex(r['got'])}",
               'clocks': r['samples'][0] if r['samples'] else None,
               'main_bytes': size, 'deterministic': det,
               'rom_sha256': sha(rom)[:16]}
        cache[key] = res
        return {**row, **res}

    def measure_safe(job):
        try:
            return measure(job)
        except Exception as e:  # keep the run going; record the failure
            sim, level, (vname, _, _), mode = job
            return {'sim': sim, 'level': level, 'variant': vname, 'mode': mode,
                    'status': 'tool-error', 'detail': repr(e)[:300]}

    jobs = [(s, l, v, m) for s in sims for l in a.level for m in modes for v in variants]
    rows = []
    # Run the first variant of every (sim, level, mode) before the others so
    # identical objects hit the cache instead of racing it.
    first = [j for j in jobs if j[2] == variants[0]]
    rest = [j for j in jobs if j[2] != variants[0]]
    with ThreadPoolExecutor(a.jobs) as pool:
        for batch in (first, rest):
            for row in pool.map(measure_safe, batch):
                rows.append(row)
                print('\t'.join(str(row.get(k, '-')) for k in
                                ('sim', 'level', 'mode', 'variant', 'status', 'bytes',
                                 'clocks', 'reused', 'detail')), flush=True)
            save_cache()
    cols = ['sim', 'level', 'mode', 'variant', 'status', 'bytes', 'main_bytes', 'clocks',
            'deterministic', 'obj_sha256', 'rom_sha256', 'reused']
    with (out / 'results.tsv').open('w') as f:
        f.write('\t'.join(cols) + '\n')
        for r in sorted(rows, key=lambda r: (r['sim'], r['level'], r['mode'], r['variant'])):
            f.write('\t'.join(str(r.get(c, '-')) for c in cols) + '\n')


if __name__ == '__main__':
    main()
