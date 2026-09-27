#!/usr/bin/env python3
"""Check carry-sequence counting against structural controls and retained code."""

import importlib.util
from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location('carry_counts', ROOT / 'dev/count-carry-saves.py')
COUNTS = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(COUNTS)


class CarryCountsTest(unittest.TestCase):
    def test_register_forms_and_relocations(self):
        text = '''00000000 <f>:
  0: a9 01        \tlda\t#$1
  2: b0 02        \tbcs\t$6 <f+0x6>
  4: a9 00        \tlda\t#$0
  6: a2 01        \tldx\t#$1
  8: b0 02        \tbcs\t$c <f+0xc>
  a: a2 00        \tldx\t#$0
  c: a0 01        \tldy\t#$1
  e: b0 02        \tbcs\t$12 <f+0x12>
 10: a0 00        \tldy\t#$0
 12: ad 00 00     \tlda\t$0
                     00000013: R_MOS_ADDR16 object
 15: c9 01        \tcmp\t#$1
'''
        value = COUNTS.count(text)['f']
        self.assertEqual(value['materialization_addresses'], ['0x0', '0x6', '0xc'])
        self.assertEqual(value['cmp1_candidates'], 1)

    def test_wrong_destination_and_branch_distance(self):
        text = '''00000000 <f>:
  0: a0 01        \tldy\t#$1
  2: b0 02        \tbcs\t$6 <f+0x6>
  4: a2 00        \tldx\t#$0
  6: a0 01        \tldy\t#$1
  8: b0 04        \tbcs\t$e <f+0xe>
  a: a0 00        \tldy\t#$0
'''
        self.assertEqual(COUNTS.count(text)['f']['materializations'], 0)

    def test_function_boundary(self):
        text = '''00000000 <f>:
  0: a0 01        \tldy\t#$1
  2: b0 02        \tbcs\t$6 <f+0x6>
00000004 <g>:
  4: a0 00        \tldy\t#$0
'''
        self.assertTrue(all(v['materializations'] == 0 for v in COUNTS.count(text).values()))

    def test_preserved_controls(self):
        evidence = ROOT / 'docs/defects/evidence/2026-09-26-mos-carry-scheduling'
        for stage, shape, expected in [('baseline', 'sum', (17, 18)),
                                       ('baseline', 'rot', (12, 12)),
                                       ('dynamic', 'sum', (0, 0)),
                                       ('dynamic', 'rot', (0, 0))]:
            with self.subTest(stage=stage, shape=shape):
                value = COUNTS.count((evidence / stage / (shape + '-a16') / 'normal.o.dis').read_text())['f']
                self.assertEqual((value['materializations'], value['cmp1_candidates']), expected)


if __name__ == '__main__':
    unittest.main()
