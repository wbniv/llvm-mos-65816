#!/usr/bin/env python3
"""Check far memset routing and all 4096 physical WRAM bytes on bsnes-jg."""

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shlex
import subprocess


ROOT = Path(__file__).resolve().parent.parent


def digest(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--input', type=Path, default=ROOT / 'examples/65816/far_memset.c')
    parser.add_argument('--llc', type=Path, default=ROOT / 'build/llvm-mos/bin/llc')
    parser.add_argument('--clang', type=Path, default=ROOT / 'build/llvm-mos-install/bin/mos-clang')
    parser.add_argument('--objdump', type=Path, default=ROOT / 'build/llvm-mos/bin/llvm-objdump')
    parser.add_argument('--sdk', type=Path, default=ROOT / 'build/install')
    parser.add_argument('--emulator', type=Path, default=ROOT / 'build/jgxcheck')
    parser.add_argument('--database', type=Path, default=ROOT / 'vendor/bsnes-jg/Database')
    parser.add_argument('--mode', choices=['a16', 'xy16'], default='a16')
    parser.add_argument('--opt', choices=['Os', 'O2'], default='Os')
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    args.output = args.output.resolve()
    args.output.mkdir(parents=True, exist_ok=False)
    runs = []
    failures = []
    output_log = args.output / 'run.log'

    def note(message):
        print(message, flush=True)
        with output_log.open('a') as stream:
            stream.write(message + '\n')

    def run(name, argv, env=None):
        command = [str(x) for x in argv]
        result = subprocess.run(command, cwd=ROOT, env=env, capture_output=True)
        stdout = args.output / (name + '.stdout')
        stderr = args.output / (name + '.stderr')
        stdout.write_bytes(result.stdout)
        stderr.write_bytes(result.stderr)
        runs.append(dict(name=name, command=command, working_directory=str(ROOT),
                         exit_code=result.returncode,
                         environment={k: v for k, v in (env or {}).items() if k.startswith('JGX_')},
                         stdout_sha256=digest(stdout), stderr_sha256=digest(stderr)))
        note('$ ' + shlex.join(command))
        note((result.stdout + result.stderr).decode(errors='replace').rstrip())
        if result.returncode:
            failures.append(name)
        return result

    tools = {name: dict(path=str(getattr(args, name).resolve()),
                       sha256=digest(getattr(args, name)))
             for name in ['llc', 'clang', 'objdump', 'emulator']}
    config = args.sdk.resolve() / 'bin/mos-snes.cfg'
    features = ['-Xclang', '-target-feature', '-Xclang', '+mos-a16']
    attr = '+mos-a16'
    if args.mode == 'xy16':
        features += ['-Xclang', '-target-feature', '-Xclang', '+mos-xy16']
        attr += ',+mos-xy16'
    clang = [args.clang.resolve(), '--target=mos', '--config', config,
             '-mcpu=mosw65816', *features, '-' + args.opt, '-fno-lto']
    source = args.input.resolve()
    ir = source
    if source.suffix != '.ll':
        preprocessed = args.output / 'input.i'
        run('preprocess', [*clang, '-E', '-x', 'c', source, '-o', preprocessed])
        ir = args.output / 'input.ll'
        if not failures:
            run('frontend', [*clang, '-S', '-emit-llvm', '-x', 'cpp-output',
                             preprocessed, '-o', ir])
        if not failures:
            run('c-object', [*clang, '-mllvm', '-verify-machineinstrs',
                             '-c', '-x', 'cpp-output', preprocessed,
                             '-o', args.output / 'c-entry.o'])
    if not failures and not re.search(r'call void @llvm\.memset\.p2\.i32\([^\n]*i32 4096', ir.read_text()):
        failures.append('far-intrinsic-trigger')
        note('FAIL: expected llvm.memset.p2.i32 with length 4096')

    if not failures:
        common = [args.llc.resolve(), '-mtriple=mos', '-mcpu=mosw65816',
                  '-mattr=' + attr, '-O2', '-verify-machineinstrs', ir]
        run('prelegalizer', [*common, '-stop-before=legalizer',
                            '-o', args.output / 'prelegalizer.mir'])
        run('legalized', [*common, '-stop-after=legalizer',
                         '-o', args.output / 'legalized.mir'])
        obj = args.output / 'input.o'
        run('backend', [*common, '-filetype=obj', '-o', obj])
        if not failures:
            dis = run('object-disassembly', [args.objdump.resolve(), '-dr',
                                             '--mcpu=mosw65816', obj]).stdout.decode()
            route_ok = bool(re.search(r'R_MOS_ADDR16\s+__memset_far\b', dis))
            near = bool(re.search(r'R_MOS_ADDR16\s+__memset\b', dis))
            if not route_ok or near:
                failures.append('far-runtime-routing')
                note('FAIL: far memset uses near runtime or lacks __memset_far')
            rom = args.output / 'input.sfc'
            link_map = args.output / 'input.map'
            linked = run('link', [*clang, '-Wl,-Map=' + str(link_map), obj, '-o', rom])
            if linked.returncode == 0:
                run('checksum', ['python3', ROOT / 'tools/snes-checksum.py', rom])
                address = re.search(r'^\s*([0-9a-f]+)\s+[0-9a-f]+\s+[0-9a-f]+\s+\d+\s+corpus_result\s*$',
                                    link_map.read_text(), re.MULTILINE)
                if not address:
                    raise RuntimeError('corpus_result missing from linker map')
                offset = int(address[1], 16) & 0x1ffff
                dump = args.output / 'physical-wram.bin'
                env = {k: v for k, v in os.environ.items() if not k.startswith('JGX_')}
                env.update(JGX_ENTROPY='0', JGX_WRAM_DUMP='2000',
                           JGX_WRAM_DUMP_LEN='4096', JGX_WRAM_DUMP_FILE=str(dump))
                run('runtime', [args.emulator.resolve(), rom, args.database.resolve(),
                                f'{offset:x}', '2', '2000', '300'], env)
                actual = dump.read_bytes() if dump.exists() else b''
                mismatches = sum(byte != 0x42 for byte in actual) + abs(4096 - len(actual))
                if mismatches:
                    failures.append('physical-wram')
                    note(f'FAIL: physical WRAM $7E2000..$7E2FFF: {mismatches}/4096 bytes differ from 0x42')
                else:
                    note('PASS: physical WRAM $7E2000..$7E2FFF: all 4096 bytes equal 0x42')

    note('RESULT: ' + ('FAIL (' + ', '.join(failures) + ')' if failures else 'PASS'))
    summary = dict(input=dict(path=str(source), sha256=digest(source)), tools=tools,
                   configuration=dict(cpu='mosw65816', features=attr, optimization=args.opt,
                                      backend_optimization='O2', lto=False, entropy=0, frames=300),
                   runs=runs, failures=failures,
                   output_hashes={p.name: digest(p) for p in args.output.iterdir() if p.is_file()})
    (args.output / 'runs.json').write_text(json.dumps(summary, indent=2) + '\n')
    return bool(failures)


if __name__ == '__main__':
    raise SystemExit(main())
