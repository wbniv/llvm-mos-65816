#!/usr/bin/env python3
"""Require a clean diagnostic for an unknown AArch64 register operand type."""

import argparse
from pathlib import Path
import resource
import shlex
import subprocess


def main():
    root = Path(__file__).resolve().parents[1]
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--llc', type=Path, required=True)
    parser.add_argument('--input', type=Path, default=root / 'docs/defects/evidence/2026-09-25-selectiondag-inlineasm/integer-many-virtual.ll')
    args = parser.parse_args()
    resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
    command = [str(args.llc), '-mtriple=aarch64', '-global-isel=0',
               '-O0', '-verify-machineinstrs', '-stop-after=finalize-isel',
               str(args.input), '-o', '/dev/null']
    print('$ ' + shlex.join(command), flush=True)
    result = subprocess.run(command, capture_output=True, text=True)
    print(result.stdout + result.stderr, end='')
    print('compiler_exit_code=' + str(result.returncode))
    expected = (
        "error: could not allocate input reg for constraint 'r'",
        "error: couldn't allocate input reg for constraint 'r'",
    )
    if result.returncode != 1 or result.stderr.strip() not in expected:
        print('Clean AArch64 type diagnostic: FAIL')
        return 1
    print('Clean AArch64 type diagnostic: PASS')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
