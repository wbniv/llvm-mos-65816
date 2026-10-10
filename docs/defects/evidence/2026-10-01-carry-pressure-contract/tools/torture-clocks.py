#!/usr/bin/env python3
"""Master clocks of held-out gcc c-torture/execute tests per llc variant.

usage: torture-clocks.py OUTDIR --irdir DIR --level L [--level L ...]
       --variant NAME=LLC[:FLAGS] [--variant ...] [--modes default,a16,a16xy16]
       [--tests FILE] [--jobs N]

Runs INSIDE the dev container (paths are /work/...). For each test, level and
mode, every llc variant compiles DIR/LEVEL/TEST.MODE.ll (gen-torture-ir.sh
output) at llc -O2 (-O3 for O3). When all variants give the same object the
test is recorded as 'same' and not run: identical objects take identical
clocks. Otherwise every distinct object is linked with the torture shim
(examples/65816/torture/_shim.c, compiled once per mode at -Os) and the
installed SDK at -Os, its checksum fixed, and the bsnes-jg cycle probe
(build/pressure-sets/opt-levels/probe/jgxcycles) measures master clocks from
the shim's main to the instruction that writes the PASS sentinel 0x600D to
corpus_result, twice. A variant whose program does not reach 0x600D within
the frame budget is recorded as FAIL. Every compiler/linker runs under
ulimit -c 0, ulimit -v 2000000 and a timeout. Writes OUTDIR/results.tsv
(one row per test/level/mode/variant) and OUTDIR/identity.json; a cache keyed
by object hash persists in OUTDIR/cache.json so a rerun resumes.
"""
import argparse
import hashlib
import json
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
SHIM = W / 'examples/65816/torture/_shim.c'
MODES = {'default': '', 'a16': '+mos-a16', 'a16xy16': '+mos-a16,+mos-xy16'}
PASS = 0x600D


def sha(p):
    return hashlib.sha256(Path(p).read_bytes()).hexdigest()


def limit():
    resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
    resource.setrlimit(resource.RLIMIT_AS, (2000000 * 1024, 2000000 * 1024))


def run(cmd, timeout=300, capped=True):
    p = subprocess.run([str(c) for c in cmd], capture_output=True, text=True,
                       timeout=timeout, preexec_fn=limit if capped else None)
    return p.returncode, p.stdout, p.stderr


def feats(mode):
    out = []
    for f in filter(None, MODES[mode].split(',')):
        out += ['-Xclang', '-target-feature', '-Xclang', f]
    return out


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('out', type=Path)
    ap.add_argument('--irdir', type=Path, required=True)
    ap.add_argument('--level', action='append', required=True)
    ap.add_argument('--variant', action='append', required=True)
    ap.add_argument('--modes', default='default,a16,a16xy16')
    ap.add_argument('--tests', type=Path)
    ap.add_argument('--jobs', type=int, default=3)
    a = ap.parse_args()
    out = a.out.resolve()
    out.mkdir(parents=True, exist_ok=True)
    variants = []
    for v in a.variant:
        name, spec = v.split('=', 1)
        llc, _, flag = spec.partition(':')
        variants.append((name, W / llc, flag))
    modes = a.modes.split(',')
    src = a.tests or (W / 'examples/65816/torture/inscope.tsv')
    tests = [l.split()[0] for l in src.read_text().splitlines()
             if l.strip() and not l.startswith('#')]
    (out / 'obj').mkdir(exist_ok=True)
    (out / 'rom').mkdir(exist_ok=True)
    shims = {}
    for m in modes:
        o = out / f'shim.{m}.o'
        rc, so, se = run([TOOL / 'clang', '--config', CFG, '-mcpu=mosw65816', *feats(m), '-Os',
                          '-fno-lto', '-c', SHIM, '-o', o])
        assert rc == 0, se
        shims[m] = o
    identity = {'clang': sha(TOOL / 'clang-23'), 'mos-clang-cfg': sha(CFG), 'probe': sha(PROBE),
                'shim': sha(SHIM),
                'llcs': {n: {'path': str(l), 'sha256': sha(l), 'flag': f} for n, l, f in variants}}
    (out / 'identity.json').write_text(json.dumps(identity, indent=2) + '\n')
    cache_file = out / 'cache.json'
    cache = json.loads(cache_file.read_text()) if cache_file.exists() else {}

    def clocks(test, level, mode, obj, osha):
        key = f'{mode}|{osha}'
        if key in cache:
            return dict(cache[key], reused=True)
        stem = out / 'rom' / f'{test}.{level}.{mode}.{osha[:16]}'
        rom = Path(str(stem) + '.sfc')
        rc, o, e = run([TOOL / 'mos-clang', '--config', CFG, '-mcpu=mosw65816', *feats(mode),
                        '-Os', obj, shims[mode], f'-Wl,-Map={stem}.map', '-o', rom], 120)
        if rc:
            return {'status': 'link-fail', 'detail': e[-200:]}
        rc, o, e = run(['python3', W / 'tools/snes-checksum.py', rom], capped=False)
        if rc:
            return {'status': 'checksum-fail'}
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
        runs = []
        for k in range(2):
            rc, o, e = run([PROBE, rom, DB, hex(start), hex(start + size), '0xffffffff',
                            hex(off), length, hex(PASS), 3000, 1], 600, capped=False)
            try:
                runs.append(json.loads(o))
            except ValueError:
                return {'status': f'probe rc={rc}', 'detail': (o + e)[-200:]}
        r = runs[0]
        res = {'status': 'PASS' if r['pass'] else f"FAIL got={hex(r['got'])}",
               'clocks': r['samples'][0] if r['samples'] else None,
               'deterministic': runs[0] == runs[1]}
        for p in (rom, Path(str(rom) + '.elf'), Path(f'{stem}.map')):
            p.unlink(missing_ok=True)
        cache[key] = res
        return res

    def job(tlm):
        test, level, mode = tlm
        ir = a.irdir / level / f'{test}.{mode}.ll'
        rows = []
        if not ir.exists():
            return [{'test': test, 'level': level, 'mode': mode, 'variant': '*',
                     'status': 'no-ir'}]
        ol = '-O3' if level == 'O3' else '-O2'
        objs = {}
        for name, llc, flag in variants:
            obj = out / 'obj' / f'{test}.{level}.{mode}.{name}.o'
            rc, o, e = run([llc, ol, *flag.split(), '-filetype=obj', ir, '-o', obj], 120)
            if rc:
                objs[name] = None
                rows.append({'test': test, 'level': level, 'mode': mode, 'variant': name,
                             'status': f'llc-fail rc={rc}'})
                continue
            rc, o, e = run([SIZE, '-A', obj], capped=False)
            nbytes = sum(int(l.split()[1]) for l in o.splitlines()
                         if re.match(r'^\.(text|data|rodata)', l))
            objs[name] = (obj, sha(obj), nbytes)
        good = {n: v for n, v in objs.items() if v}
        same = len({v[1] for v in good.values()}) <= 1
        for name, v in good.items():
            row = {'test': test, 'level': level, 'mode': mode, 'variant': name,
                   'bytes': v[2], 'obj_sha256': v[1][:16]}
            if same:
                row['status'] = 'same'
            else:
                row.update(clocks(test, level, mode, v[0], v[1]))
            rows.append(row)
        for v in good.values():
            v[0].unlink(missing_ok=True)
        return rows

    jobs = [(t, l, m) for t in tests for l in a.level for m in modes]
    allrows = []
    cols = ['test', 'level', 'mode', 'variant', 'status', 'bytes', 'clocks', 'deterministic',
            'obj_sha256', 'reused', 'detail']
    with ThreadPoolExecutor(a.jobs) as pool:
        for i, rows in enumerate(pool.map(job, jobs)):
            allrows += rows
            if i % 200 == 0:
                cache_file.write_text(json.dumps(cache))
                print(f'{i}/{len(jobs)}', flush=True)
    cache_file.write_text(json.dumps(cache))
    with (out / 'results.tsv').open('w') as f:
        f.write('\t'.join(cols) + '\n')
        for r in allrows:
            f.write('\t'.join(str(r.get(c, '-')) for c in cols) + '\n')


if __name__ == '__main__':
    main()
