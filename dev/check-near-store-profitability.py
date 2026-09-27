#!/usr/bin/env python3
"""Check the same near-store code-generation input with an identified tool set."""
import argparse
from pathlib import Path
import shlex
import subprocess


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('tools', type=Path)
    parser.add_argument('input', type=Path)
    args = parser.parse_args()
    tool, source = args.tools.resolve(), args.input.resolve()
    failed = False
    for mode, features in [('default', []), ('a16', ['+mos-a16']),
                           ('xy16', ['+mos-a16', '+mos-xy16'])]:
        command = [str(tool / 'llc'), '-mtriple=mos', '-mcpu=mosw65816',
                   '-verify-machineinstrs',
                   *(['-mattr=' + ','.join(features)] if features else []),
                   str(source), '-o', '-']
        print(shlex.join(command), flush=True)
        result = subprocess.run(command, capture_output=True, text=True)
        print(result.stderr, end='')
        prefix = 'DEFAULT' if mode == 'default' else 'NATIVE'
        check = [str(tool / 'FileCheck'), str(source), '--check-prefixes=BYTE,' + prefix]
        print(shlex.join(check), flush=True)
        checked = subprocess.run(check, input=result.stdout, capture_output=True, text=True)
        print(checked.stderr, end='')
        ok = result.returncode == 0 and checked.returncode == 0
        failed |= not ok
        print(f'{mode}: {"PASS" if ok else "FAIL"}', flush=True)
    return int(failed)


if __name__ == '__main__':
    raise SystemExit(main())
