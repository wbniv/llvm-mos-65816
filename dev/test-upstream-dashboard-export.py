#!/usr/bin/env python3
"""Check evidence publication links against the selected Git file set."""

import importlib.util
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch


SOURCE = Path(__file__).with_name('export-upstream-dashboard.py')
SPEC = importlib.util.spec_from_file_location('dashboard', SOURCE)
dashboard = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(dashboard)


class PublicationTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory(prefix='dashboard-export-test-')
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        subprocess.run(['git', 'init', '-q', str(self.root)], check=True)
        self.root_patch = patch.object(dashboard, 'ROOT', self.root)
        self.root_patch.start()
        self.addCleanup(self.root_patch.stop)
        self.path = 'docs/evidence.md'
        (self.root / 'docs').mkdir()
        (self.root / self.path).write_text('Retained evidence.\n')

    def stage(self):
        subprocess.run(['git', '-C', str(self.root), 'add', self.path], check=True)

    def test_untracked_evidence_has_no_public_link(self):
        self.assertIsNone(dashboard.public_link(self.path))

    def test_same_commit_evidence_has_public_link_without_head(self):
        self.stage()
        self.assertEqual(dashboard.public_link(self.path), dashboard.PUBLIC_REPO + self.path)

    def test_missing_evidence_is_rejected(self):
        with self.assertRaisesRegex(ValueError, 'missing evidence path'):
            dashboard.public_link('docs/missing.md')

    def test_normalized_note_tracks_publication_eligibility(self):
        item = {'id': 'test', 'evidencePaths': [self.path]}
        self.assertTrue(dashboard.normalize(item)['evidenceNote'])
        self.stage()
        rendered = dashboard.normalize(item)
        self.assertEqual(rendered['evidenceNote'], '')
        self.assertEqual(rendered['evidenceUrls'], [dashboard.PUBLIC_REPO + self.path])


if __name__ == '__main__':
    unittest.main()
