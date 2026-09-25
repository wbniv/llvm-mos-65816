#!/usr/bin/env python3
"""Reproduce shift, register-pressure, and reentrant-attribute shapes.

Uses existing compiler binaries without modifying them. Retains generated inputs,
commands, compiler diagnostics, objects, IR, and a JSON report in --out. Runtime
inputs support HOST_MAIN and expose corpus_result for the emulator harness.
"""

import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess


def replace_once(text, old, new):
    if text.count(old) != 1:
        raise ValueError(f"Expected exactly one occurrence of {old!r}")
    return text.replace(old, new)


def main():
    root = Path(__file__).resolve().parent.parent
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--clang', type=Path,
                    default=root / 'build/llvm-mos-install/bin/mos-clang')
    ap.add_argument('--opt', type=Path, default=root / 'build/llvm-mos/bin/opt')
    ap.add_argument('--out', type=Path, default=root / 'build/older-defect-recheck')
    args = ap.parse_args()
    out = args.out.resolve()
    out.mkdir(parents=True, exist_ok=True)
    clang, opt = args.clang.absolute(), args.opt.absolute()
    commands, rows = [], []

    def run(argv, name):
        argv = [str(x) for x in argv]
        commands.append(argv)
        result = subprocess.run(argv, capture_output=True, text=True, timeout=180)
        (out / (name + '.log')).write_text(result.stdout + result.stderr)
        return result

    shift = (root / 'examples/65816/shift64seam.h').read_text()
    shift = replace_once(shift, 'uint64_t shift64seam_count',
                         'uint8_t shift64seam_count')
    if shift.count('uint64_t count)') != 3:
        raise ValueError('Expected three shift helper count parameters')
    shift = shift.replace('uint64_t count)', 'uint8_t count)')
    shift, count = re.subn(r'    shift64seam_count=\(uint64_t\)c8;[^\n]*',
                          '    shift64seam_count=c8;', shift)
    if count != 1:
        raise ValueError('Expected one volatile count assignment')
    shift = replace_once(shift, 'uint64_t c=shift64seam_count;',
                         'uint8_t c=shift64seam_count;')
    # Every legal count occurs in the 96-step model, including each limb boundary.
    shift, count = re.subn(
        r'static uint8_t shift64seam_amount\(uint16_t step\) \{.*?\n\}',
        'static uint8_t shift64seam_amount(uint16_t step) {\n'
        '    return (uint8_t)(step & 63u);\n}', shift, flags=re.S)
    if count != 1:
        raise ValueError('Expected one shift-count generator')
    (out / 'shift-narrow.h').write_text(shift)

    board = (root / 'examples/65816/bitboard64.h').read_text()
    for name in ('pop', 'ctz', 'clz'):
        board = replace_once(
            board, '__attribute__((noinline)) static uint8_t bitboard64_' + name,
            '__attribute__((always_inline)) static inline uint8_t bitboard64_' + name)
    (out / 'bitboard-inline.h').write_text(board)

    for name, header, model in [('shift', 'shift-narrow.h', 'shift64seam_model'),
                                ('bitboard', 'bitboard-inline.h', 'bitboard64_model')]:
        (out / (name + '-runtime.c')).write_text(
            f'#include "{header}"\n#ifdef HOST_MAIN\n#include <stdio.h>\n#endif\n'
            'volatile uint16_t corpus_result;\nint main(void) {\n#ifdef HOST_MAIN\n'
            f'  printf("0x%04X\\n", (unsigned){model}());\n#else\n'
            f'  corpus_result = {model}();\n'
            '  for (;;) __asm__ volatile("wai");\n#endif\n}\n')

    inputs = [(root / 'examples/65816/shift64seam-narrow.c',
               ('O0', 'O1', 'O2', 'O3', 'Os', 'Oz'))]
    inputs.append((root / 'dev/older-defects/shift-onehot.c', inputs[0][1]))
    inputs += [(out / (name + '-runtime.c'), inputs[0][1])
               for name in ('shift', 'bitboard')]
    inputs += [(root / 'examples/65816' / (name + '.c'), ('O1', 'Os'))
               for name in ('rcundef', 'rcundef2', 'a16regpress')]
    inputs += [(root / 'examples/snes/corpus' / (name + '_sim.c'), ('O1', 'Os'))
               for name in ('newton', 'trimerge', 'lsystem', 'gouraud',
                            'msquares', 'mandel-double')]
    for src, levels in inputs:
        for mode, features in [('default', []), ('a16', ['+mos-a16']),
                               ('xy16', ['+mos-a16', '+mos-xy16'])]:
            flags = [x for feature in features
                     for x in ('-Xclang', '-target-feature', '-Xclang', feature)]
            for level in levels:
                name = f'{src.stem}-{mode}-{level}'
                result = run([clang, '--target=mos', '-mcpu=mosw65816', '-' + level,
                              '-fno-lto', '-mllvm', '-verify-machineinstrs', *flags,
                              '-c', src, '-o', out / (name + '.o')], name)
                rows.append(dict(input=src.stem, mode=mode, optimization=level,
                                 returncode=result.returncode))
                print(name, 'PASS' if result.returncode == 0 else 'FAIL', flush=True)

    # Inspect optimized IR to ensure the runtime fixtures retain the target shapes.
    for name in ('shift', 'bitboard'):
        ir = out / (name + '-runtime.ll')
        result = run([clang, '--target=mos', '-mcpu=mosw65816', '-Os', '-S',
                      '-emit-llvm', out / (name + '-runtime.c'), '-o', ir], name + '-ir')
        result.check_returncode()
        text = ir.read_text()
        if name == 'shift':
            assert all(op + ' i64' in text for op in ('shl', 'lshr', 'ashr'))
            for function in ('left', 'right', 'arith'):
                assert re.search(r'define [^\n]*@shift64seam_' + function +
                                 r'\(i64[^\n]*, i8\b', text)
        else:
            body = re.search(r'define [^\n]*@bitboard64_step\([^\n]*\{(.*?)\n\}',
                             text, re.S).group(1)
            assert all('llvm.' + op + '.i64' in body for op in ('ctpop', 'cttz', 'ctlz'))
            assert not re.search(r'define [^\n]*@bitboard64_(pop|ctz|clz)\(', text)

    attributes = []
    src = root / 'docs/investigations/repro/upstream-issues-2026-09-20/reentrant.c'
    for cpu in ('mos6502', 'mosw65816'):
        for assume in (False, True):
            name = f'reentrant-{cpu}-assume{int(assume)}'
            ir, after = out / (name + '.ll'), out / (name + '-after.ll')
            result = run([clang, '--target=mos', '-mcpu=' + cpu, '-O1',
                          *(['-fnonreentrant'] if assume else []),
                          '-S', '-emit-llvm', src, '-o', ir], name)
            result.check_returncode()
            result = run([opt, '-passes=mos-nonreentrant,verify', '-S', ir,
                          '-o', after], name + '-opt')
            result.check_returncode()
            for stage, path in [('frontend', ir), ('after-pass', after)]:
                text = path.read_text()
                groups = dict(re.findall(r'^attributes #(\d+) = (.*)$', text, re.M))
                for function in ('force_frame', 'ordinary_frame'):
                    group = re.search(r'define [^\n]*@' + function +
                                      r'\([^\n]* #(\d+) \{', text).group(1)
                    attributes.append(dict(cpu=cpu, assume=assume, stage=stage,
                                           function=function, attributes=groups[group]))
    report = dict(clang_sha256=hashlib.sha256(clang.read_bytes()).hexdigest(),
                  opt_sha256=hashlib.sha256(opt.read_bytes()).hexdigest(),
                  compilations=rows, reentrant=attributes, commands=commands)
    (out / 'report.json').write_text(json.dumps(report, indent=2) + '\n')
    failures = sum(row['returncode'] != 0 for row in rows)
    print(f'{len(rows)} compilations, {failures} failures; reentrant IR retained')
    return int(failures != 0)


if __name__ == '__main__':
    raise SystemExit(main())
