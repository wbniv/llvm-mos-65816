#!/usr/bin/env python3
"""Compile the near-store runtime fixture with an extracted llc and run both cores.

The existing frontend and SDK provide C translation, linking, and startup. All
fixture machine instructions are selected by the supplied backend without LTO.
"""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import subprocess


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--llc', type=Path, required=True)
    parser.add_argument('--out', type=Path, required=True)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[4]
    out = args.out.resolve()
    out.mkdir(parents=True, exist_ok=False)
    llc = args.llc.resolve()
    spec = importlib.util.spec_from_file_location('fuzz', root / 'tools/a16_fuzz.py')
    fuzz = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(fuzz)
    src = root / 'examples/65816/a16storebroad.c'
    commands, results = [], []

    def run(cmd, stem):
        cmd = list(map(str, cmd))
        result = subprocess.run(cmd, capture_output=True, text=True)
        (out / (stem + '.stdout')).write_text(result.stdout)
        (out / (stem + '.stderr')).write_text(result.stderr)
        commands.append({'command': cmd, 'exit_code': result.returncode})
        (out / 'commands.json').write_text(json.dumps(commands, indent=2) + '\n')
        if result.returncode:
            raise RuntimeError(result.stderr)
        return result.stdout

    host = out / 'host'
    run(['/usr/bin/cc', '-O2', '-DHOST_MAIN', src, '-o', host], 'host-build')
    expected = int(run([host], 'host-run').strip(), 16)
    clang = fuzz.TOOL / 'mos-clang'
    identity = {'llc_sha256': hashlib.sha256(llc.read_bytes()).hexdigest(),
                'frontend_sha256': hashlib.sha256(clang.read_bytes()).hexdigest(),
                'fixture_sha256': hashlib.sha256(src.read_bytes()).hexdigest(),
                'lto': False, 'expected': expected}
    (out / 'identity.json').write_text(json.dumps(identity, indent=2) + '\n')
    for mode, features in [('default', []), ('a16', ['+mos-a16']),
                           ('xy16', ['+mos-a16', '+mos-xy16'])]:
        ir, obj = out / (mode + '.ll'), out / (mode + '.o')
        rom, mapfile = out / (mode + '.sfc'), out / (mode + '.map')
        flags = [arg for feature in features for arg in
                 ['-Xclang', '-target-feature', '-Xclang', feature]]
        run([clang, '--config', fuzz.CFG, '-mcpu=mosw65816', '-Os', '-fno-lto',
             *flags, '-S', '-emit-llvm', src, '-o', ir], mode + '-frontend')
        run([llc, '-mtriple=mos', '-mcpu=mosw65816', '-verify-machineinstrs',
             *(['-mattr=' + ','.join(features)] if features else []),
             '-filetype=obj', ir, '-o', obj], mode + '-backend')
        run([clang, '--config', fuzz.CFG, '-mcpu=mosw65816', '-fno-lto',
             '-Wl,-Map=' + str(mapfile), obj, '-o', rom], mode + '-link')
        run(['python3', fuzz.CHECKSUM, rom], mode + '-checksum')
        address, size = fuzz.map_lookup(mapfile, 'corpus_result')
        assert address is not None and size == 2, (address, size)
        for core in ['mame', 'bsnes-jg']:
            if core == 'mame':
                got, log = fuzz.run_mame(rom, 0x7E0000 + address, expected, size)
            else:
                got, log = fuzz.run_bsnes(rom, address, size, expected)
            (out / (mode + '-' + core + '.log')).write_text(log + '\n')
            results.append({'mode': mode, 'core': core, 'got': got, 'expected': expected,
                            'address': address, 'size': size,
                            'rom_sha256': hashlib.sha256(rom.read_bytes()).hexdigest()})
            (out / 'results.json').write_text(json.dumps(results, indent=2) + '\n')
            print(mode, core, got, log, flush=True)
            assert got == expected, (mode, core, got, expected)


if __name__ == '__main__':
    main()
