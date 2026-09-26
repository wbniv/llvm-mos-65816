#!/usr/bin/env python3
"""Require a normal diagnostic for incompatible inline-asm vector parts."""

import argparse
from pathlib import Path
import resource
import shlex
import subprocess


def main():
    root = Path(__file__).resolve().parents[1]
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--llc', type=Path, required=True)
    parser.add_argument('--input', type=Path, default=root / 'docs/defects/evidence/2026-09-25-selectiondag-inlineasm/asm-many-virtual.ll')
    args = parser.parse_args()
    resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
    command = [str(args.llc), '-mtriple=aarch64', '-global-isel=0',
               '-O0', '-verify-machineinstrs', '-stop-after=finalize-isel',
               str(args.input), '-o', '/dev/null']
    print('$ ' + shlex.join(command), flush=True)
    result = subprocess.run(command, capture_output=True, text=True)
    print(result.stdout + result.stderr, end='')
    print('compiler_exit_code=' + str(result.returncode))
    expected = ('error: incompatible vector register parts, '
                'possible invalid constraint for vector type')
    if result.returncode != 1 or result.stderr.strip() != expected:
        print('Vector constraint diagnostic: FAIL')
        return 1
    print('Vector constraint diagnostic: PASS')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
