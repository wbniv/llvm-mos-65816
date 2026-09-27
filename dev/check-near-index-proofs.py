#!/usr/bin/env python3
"""Check near-index code generation using a named compiler and retained input."""
import argparse
from pathlib import Path
import shlex
import subprocess


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('llc', type=Path)
    ap.add_argument('input', type=Path)
    args = ap.parse_args()
    cmd = [str(args.llc), '-mtriple=mos', '-mcpu=mosw65816',
           '-mattr=+mos-a16,+mos-xy16', '-verify-machineinstrs',
           str(args.input), '-o', '-']
    print(shlex.join(cmd), flush=True)
    result = subprocess.run(cmd, capture_output=True, text=True)
    print(result.stderr, end='')
    if result.returncode:
        return result.returncode
    check = ['build/llvm-mos/bin/FileCheck', str(args.input)]
    print(shlex.join(check), flush=True)
    checked = subprocess.run(check, input=result.stdout, text=True,
                             capture_output=True)
    print(checked.stderr, end='')
    print('PASS' if checked.returncode == 0 else 'FAIL: near-index proof recovery')
    return checked.returncode


if __name__ == '__main__':
    raise SystemExit(main())
