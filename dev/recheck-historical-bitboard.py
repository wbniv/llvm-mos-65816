#!/usr/bin/env python3
"""Verify the inline i64 bit-count caller at the C and backend boundaries."""

import argparse
from pathlib import Path
import resource
import shlex
import subprocess
import tempfile


def main():
    root = Path(__file__).resolve().parents[1]
    evidence = root / 'docs/defects/evidence/2026-09-25-historical-recovery'
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--clang', type=Path, default=root / 'build/llvm-mos-install/bin/mos-clang')
    parser.add_argument('--llc', type=Path, default=root / 'build/llvm-mos/bin/llc')
    args = parser.parse_args()
    resource.setrlimit(resource.RLIMIT_CORE, (0, 0))

    # The captured IR keeps all three i64 intrinsics in the same caller,
    # independently of transformations performed by the selected frontend.
    ir = evidence / 'replay/inline-stage.ll'
    body = ir.read_text().split('@bitboard64_step()', 2)[2].split('\n}', 1)[0]
    assert all('@llvm.' + name + '.i64' in body for name in ('ctpop', 'cttz', 'ctlz'))
    with tempfile.TemporaryDirectory(prefix='bitboard-check-') as directory:
        commands = [
            [args.clang, '--target=mos', '-mcpu=mosw65816', '-Xclang', '-target-feature',
             '-Xclang', '+mos-a16', '-Os', '-fno-lto', '-mllvm', '-verify-machineinstrs',
             '-c', evidence / 'inline-stage/examples/65816/bitboard64-probe.c',
             '-o', Path(directory) / 'probe.o'],
            [args.llc, '-mcpu=mosw65816', '-mattr=+mos-a16', '-O2',
             '-verify-machineinstrs', ir, '-o', Path(directory) / 'probe.s'],
        ]
        for command in commands:
            print('$ ' + shlex.join(map(str, command)), flush=True)
            result = subprocess.run(list(map(str, command)))
            if result.returncode:
                return 1
    print('Inline bitboard C and retained IR: PASS')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
