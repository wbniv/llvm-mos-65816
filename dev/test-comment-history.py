#!/usr/bin/env python3
"""Exercise the comment gate against isolated Git indexes."""

from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


CHECK = Path(__file__).with_name('check-comment-history.py')


class CommentHistoryTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.git('init', '-q')
        self.git('config', 'core.hooksPath', '/dev/null')
        self.git('config', 'user.name', 'Comment gate test')
        self.git('config', 'user.email', 'test@example.invalid')

    def git(self, *args):
        subprocess.run(['git', *args], cwd=self.root, check=True, capture_output=True)

    def stage(self, path, text):
        (self.root / path).write_text(text)
        self.git('add', '--', path)

    def check(self, expected):
        result = subprocess.run([sys.executable, str(CHECK)], cwd=self.root, text=True, capture_output=True)
        self.assertEqual(result.returncode, expected, result.stdout + result.stderr)
        return result.stderr

    def test_reviewer_example_and_wrapping(self):
        self.stage('regression.ll', '; Before the fix, collectCandidates() accumulated benefits in a\n; DenseMap.\n')
        self.assertIn('regression.ll:1', self.check(1))
        self.stage('regression.ll', '; Before the\n; fix, collection was unordered.\n')
        self.check(1)

    def test_current_reason_and_noncomment_strings(self):
        self.stage('code.cpp', '// Iteration order must be deterministic.\nconst char *s = "Before the fix // was broken";\n')
        self.stage('test.py', 'text = "# Before the fix"\n# Equal benefits retain deterministic ordering.\n')
        self.stage('notes.md', 'Before the fix, candidate order varied.\n')
        self.check(0)

    def test_inline_and_block_comments(self):
        self.stage('code.cpp', 'int x; // Previously this was broken.\n')
        self.check(1)
        self.stage('code.cpp', '/* Before the\n * fix, the code was broken. */\n')
        self.check(1)

    def test_only_staged_content(self):
        self.stage('code.cpp', '// Before the fix, ordering varied.\n')
        (self.root / 'code.cpp').write_text('// Iteration order must be deterministic.\n')
        self.check(1)
        self.git('add', 'code.cpp')
        (self.root / 'code.cpp').write_text('// Before the fix, ordering varied.\n')
        self.check(0)

    def test_unchanged_comment_does_not_block(self):
        self.stage('code.cpp', '// Previously this was broken.\nint x;\n')
        self.git('commit', '-qm', 'baseline')
        self.stage('code.cpp', '// Previously this was broken.\nint y;\n')
        self.check(0)

    def test_patch_bundle_checks_only_added_comments(self):
        prefix = 'diff --git a/test.ll b/test.ll\n--- a/test.ll\n+++ b/test.ll\n@@ -1 +1 @@\n'
        self.stage('review.patch', prefix + '-; Before the fix, ordering varied.\n+; Iteration order must be deterministic.\n')
        self.check(0)
        self.stage('review.patch', prefix + '-; Iteration order must be deterministic.\n+; Before the fix, ordering varied.\n')
        self.assertIn('review.patch:6', self.check(1))


if __name__ == '__main__':
    unittest.main()
