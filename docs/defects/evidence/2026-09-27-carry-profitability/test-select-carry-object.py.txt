#!/usr/bin/env python3
"""Check the size selector's tie and storage-budget contracts."""

import importlib.util
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location(
    'selection', Path(__file__).with_name('select-carry-object.py'))
selection = importlib.util.module_from_spec(spec)
spec.loader.exec_module(selection)


def cost(file_bytes, writable_bytes=10):
    return {'file_bytes': file_bytes, 'writable_bytes': writable_bytes}


class SelectionTests(unittest.TestCase):
    def test_baseline_wins_equal_size(self):
        self.assertEqual(selection.choose({'off': cost(100), 'always': cost(100, 9)}), 'off')

    def test_writable_growth_needs_explicit_opt_out(self):
        alternatives = {'off': cost(100), 'always': cost(90, 11)}
        self.assertEqual(selection.choose(alternatives), 'off')
        self.assertEqual(selection.choose(alternatives, True), 'always')

    def test_gate_can_beat_original_preference(self):
        self.assertEqual(selection.choose({'off': cost(100), 'always': cost(95),
                                           'gated': cost(90)}), 'gated')

    def test_candidate_ties_preserve_policy_order(self):
        self.assertEqual(selection.choose({'off': cost(100), 'always': cost(90),
                                           'gated': cost(90)}), 'always')


if __name__ == '__main__':
    unittest.main()
