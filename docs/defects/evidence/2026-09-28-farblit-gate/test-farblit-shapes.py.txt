#!/usr/bin/env python3
"""Exercise the Farblit gate with real compiler output and deliberate shape changes."""

import argparse
import importlib.util
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parent.parent
SPEC = importlib.util.spec_from_file_location('farblit_shapes', ROOT / 'dev/check-farblit-shapes.py')
CHECK = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = CHECK
SPEC.loader.exec_module(CHECK)


class ShapeTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.output = tempfile.TemporaryDirectory(prefix='farblit-shapes-')
        cls.cases = {}
        for fixture, filename in [('main', 'farblit.c'), ('pressure', 'farblit_press.c')]:
            source = ROOT / 'examples/65816' / filename
            for mode in ['a16', 'xy16']:
                flags = ['--target=mos', '-mcpu=mosw65816', '-Os', '-mllvm', '-verify-machineinstrs',
                         '-Xclang', '-target-feature', '-Xclang', '+mos-a16']
                if mode == 'xy16':
                    flags += ['-Xclang', '-target-feature', '-Xclang', '+mos-xy16']
                output = Path(cls.output.name) / f'{fixture}-{mode}.s'
                subprocess.run([str(TOOLCHAIN / 'bin/mos-clang'), *flags, '-gline-tables-only',
                                '-S', str(source), '-o', str(output)], check=True, capture_output=True)
                text = output.read_text()
                rows = CHECK.check_shapes(text, source, mode, fixture)
                cls.cases[fixture, mode] = (source, text, rows)

    @classmethod
    def tearDownClass(cls):
        cls.output.cleanup()

    def changed_access(self, probe, replacement, mode='a16', fixture='main', access=0):
        source, text, rows = self.cases[fixture, mode]
        lines = text.splitlines()
        line = rows[probe][access]['assembly_line'] - 1
        lines[line] = replacement(lines[line])
        return source, '\n'.join(lines)

    def rejects(self, source, text, probe, mode='a16', fixture='main'):
        with self.assertRaisesRegex(CHECK.ShapeError, probe):
            CHECK.check_shapes(text, source, mode, fixture)

    def test_all_modes_and_probes(self):
        for (fixture, mode), (source, text, rows) in self.cases.items():
            with self.subTest(fixture=fixture, mode=mode):
                self.assertEqual(set(rows), set(CHECK.expectations(mode, fixture)))
                self.assertTrue(all(a['source_line'] > 0 for group in rows.values() for a in group))

    def test_nonzero_file_identifiers(self):
        for (fixture, mode), (source, text, _) in self.cases.items():
            with self.subTest(fixture=fixture, mode=mode):
                text = re.sub(r'(\.(?:file|loc)\s+)(\d+)', lambda m: m[1] + str(int(m[2]) + 42), text)
                CHECK.check_shapes(text, source, mode, fixture)

    def test_missing_debug_file(self):
        source, text, _ = self.cases['main', 'a16']
        text = re.sub(r'(\.loc\s+)\d+', r'\g<1>999', text)
        self.rejects(source, text, 'unmarked far access')

    def test_missing_source_location(self):
        source, text, _ = self.cases['main', 'a16']
        text = re.sub(r'(\.loc\s+\d+\s+)\d+', r'\g<1>0', text)
        self.rejects(source, text, 'unmarked far access')

    def test_missing_access(self):
        source, text = self.changed_access('rd8', lambda _: '')
        self.rejects(source, text, 'rd8: expected')

    def test_duplicate_access(self):
        source, text = self.changed_access('rd8', lambda line: line + '\n' + line)
        self.rejects(source, text, 'rd8: expected')

    def test_byte_load_cannot_satisfy_native_word(self):
        source, text = self.changed_access('rdw', lambda line: '\tsep #32\n' + line)
        self.rejects(source, text, 'rdw: expected')

    def test_wrong_store_addressing(self):
        source, text = self.changed_access('wr8', lambda line: line.replace(',y', ''))
        self.rejects(source, text, 'wr8: expected')

    def test_y16_width_is_required_at_the_access(self):
        source, text = self.changed_access('rd16', lambda line: '\tsep #16\n' + line, mode='xy16')
        self.rejects(source, text, 'rd16: expected', mode='xy16')

    def test_pressure_pair_must_be_adjacent(self):
        source, text = self.changed_access('sample', lambda line: '\tldx __rc4\n' + line,
                                           mode='xy16', fixture='pressure')
        self.rejects(source, text, 'sample: Y16 access', mode='xy16', fixture='pressure')

    def test_branch_cannot_skip_the_y16_load(self):
        source, text, rows = self.cases['pressure', 'xy16']
        lines = text.splitlines()
        access = rows['sample'][0]['assembly_line'] - 1
        # A branch into the pair gives the access an additional predecessor.
        lines.insert(access, '.Lskip_index:')
        lines.insert(access - 1, '\tbeq .Lskip_index')
        self.rejects(source, '\n'.join(lines), 'sample: Y16 access', mode='xy16', fixture='pressure')

    def test_aggregate_counts_cannot_hide_a_lost_fold(self):
        source, text, rows = self.cases['main', 'a16']
        lines = text.splitlines()
        lost = rows['rd8'][0]['assembly_line'] - 1
        substitute = rows['cp8'][0]['assembly_line'] - 1
        lines[lost] = lines[lost].replace(',y', '')
        extra = lines[substitute] + ',y'
        lines[substitute] = extra + '\n' + extra
        text = '\n'.join(lines)
        self.assertGreaterEqual(len(re.findall(r'\blda\s+\[[^\]]+\],y', text)), 3)
        self.assertGreaterEqual(len(re.findall(r'\bsta\s+\[[^\]]+\],y', text)), 2)
        self.rejects(source, text, 'rd8: expected')

    def test_widths_follow_branches_and_joins(self):
        instructions = [CHECK.Instruction(op, operand, i + 1, (0, 1)) for i, (op, operand) in enumerate([
            ('beq', 'join'), ('rep', '#32'), ('lda', '[__rc4]'), ('rts', '')])]
        states, _ = CHECK.width_states(instructions, {'join': 2})
        self.assertEqual(states[2], {(8, 8), (16, 8)})

    def test_empty_disassembly_is_rejected(self):
        with self.assertRaisesRegex(CHECK.ShapeError, 'empty disassembly'):
            CHECK.disassembly_body('')

    def test_disassembly_keeps_relocations(self):
        first = 'object-one\nDisassembly of section .text.main:\n0: af 00 00 00 lda 0\n R_MOS_ADDR24 tbl\n'
        other_name = first.replace('object-one', 'object-two')
        different_target = first.replace('R_MOS_ADDR24 tbl', 'R_MOS_ADDR24 other')
        self.assertEqual(CHECK.disassembly_body(first), CHECK.disassembly_body(other_name))
        self.assertNotEqual(CHECK.disassembly_body(first), CHECK.disassembly_body(different_target))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--toolchain', type=Path, default=ROOT / 'build/llvm-mos-install')
    args, remaining = parser.parse_known_args()
    TOOLCHAIN = args.toolchain.resolve()
    unittest.main(argv=[sys.argv[0], *remaining])
