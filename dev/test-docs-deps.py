#!/usr/bin/env python3
"""Exercise document invalidation, impact discovery, and staged-blob isolation."""

import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

TOOL = Path(__file__).with_name('docs-deps.py')
spec = importlib.util.spec_from_file_location('docs_deps', TOOL)
deps = importlib.util.module_from_spec(spec)
spec.loader.exec_module(deps)


class MemoryTree:
    def __init__(self, files):
        self.files = files
        self.root = Path('/repo')
        self.paths = set(files)

    def read(self, path):
        return self.files[path]


class DependencyTests(unittest.TestCase):
    def setUp(self):
        self.files = {'docs/source.md': b'# Source\n',
                      'docs/view.html': b'<h1>Source</h1>\n',
                      'docs/summary.md': b'Summary\n'}
        self.manifest = {
            'schema': 1, 'discovery': {'exclude': []},
            'generated': [{'id': 'page', 'sources': ['docs/source.md'],
                           'outputs': ['docs/view.html'], 'command': []}],
            'maintained': [{'document': 'docs/summary.md', 'sources': ['docs/source.md']}],
        }
        tree = MemoryTree(self.files)
        self.manifest['generated'][0]['receipt'] = {
            'sources': deps.fingerprint(tree, ['docs/source.md']),
            'outputs': deps.output_hashes(tree, ['docs/view.html']),
        }
        self.manifest['maintained'][0]['receipt'] = {
            'sources': deps.fingerprint(tree, ['docs/source.md']),
            'note': 'The summary states the source contract.', 'attribution': 'Test fixture',
        }
        self.files[deps.INDEX] = deps.render_index(tree, self.manifest).encode()

    def problems(self):
        return deps.check(MemoryTree(self.files), self.manifest)

    def test_changed_source_invalidates_view_and_summary(self):
        self.assertEqual(self.problems(), [])
        self.files['docs/source.md'] += b'Additional contract.\n'
        problems = self.problems()
        self.assertTrue(any('regenerate' in p for p in problems))
        self.assertTrue(any('review the summary' in p for p in problems))

    def test_editing_output_without_regeneration_is_detected(self):
        self.files['docs/view.html'] = b'<h1>Different result</h1>'
        self.assertTrue(any('generated output changed' in p for p in self.problems()))

    def test_new_document_requires_inventory_refresh(self):
        self.files['docs/new.md'] = b'[Source](source.md)\n'
        self.assertTrue(any('inventory changed' in p for p in self.problems()))

    def test_json_field_selection_and_new_matching_record(self):
        files = {'docs/defects/one.json': b'{"status":"confirmed","observations":[]}',
                 'docs/defects/evidence/one.json': b'{"status":"ignored"}'}
        sources = [{'glob': 'docs/defects/*.json', 'fields': ['status']}]
        before = deps.fingerprint(MemoryTree(files), sources)
        self.assertEqual(set(before), {'docs/defects/one.json'})
        files['docs/defects/one.json'] = b'{"status":"confirmed","observations":["log"]}'
        self.assertEqual(before, deps.fingerprint(MemoryTree(files), sources))
        files['docs/defects/one.json'] = b'{"status":"fixed"}'
        self.assertNotEqual(before, deps.fingerprint(MemoryTree(files), sources))
        files['docs/defects/two.json'] = b'{"status":"confirmed"}'
        self.assertEqual(len(deps.fingerprint(MemoryTree(files), sources)), 2)

    def test_missing_declared_input_and_derivation_cycle(self):
        with self.assertRaisesRegex(ValueError, 'Missing dependency'):
            deps.fingerprint(MemoryTree(self.files), ['docs/missing.md'])
        with self.assertRaisesRegex(ValueError, 'cycle'):
            deps.assert_acyclic({'a': {'b'}, 'b': {'a'}})

    def test_generators_run_after_their_sources(self):
        first = self.manifest['generated'][0]
        second = {'id': 'second', 'sources': ['docs/view.html'], 'outputs': ['docs/final.html']}
        order = deps.generation_order(MemoryTree(self.files), [second, first])
        self.assertEqual([g['id'] for g in order], ['page', 'second'])

    def test_references_and_transitive_impact_allow_citation_cycles(self):
        refs = deps.references('docs/report.md',
                               '[source](source.md#section)\n[x][reference]\n'
                               '[reference]: <../README.md>\n'
                               '<a href="nested/view.html">View</a>\n'
                               '[external](https://example.invalid/)\n'
                               '[space](<a%20b.md>)', Path('/repo'))
        self.assertEqual(refs, {'docs/source.md', 'README.md', 'docs/nested/view.html', 'docs/a b.md'})
        edges = {'summary': {'source', 'view'}, 'view': {'summary'}}
        self.assertEqual(set(deps.impacted(edges, ['source'])), {'summary', 'view'})

    def test_staged_check_ignores_unstaged_repairs(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            subprocess.run(['git', 'init', '-q', str(root)], check=True)
            for name, data in self.files.items():
                path = root / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(data)
            (root / deps.MANIFEST).write_text(json.dumps(self.manifest))
            subprocess.run(['git', 'add', '.'], cwd=root, check=True)

            def run(*args):
                return subprocess.run([sys.executable, str(TOOL), *args], cwd=root,
                                      capture_output=True, text=True)

            self.assertEqual(run('--staged').returncode, 0)
            (root / 'docs/new.md').write_text('New document\n')
            subprocess.run(['git', 'add', 'docs/new.md'], cwd=root, check=True)
            self.assertNotEqual(run('--staged').returncode, 0)
            self.assertEqual(run('--staged', '--write-index').returncode, 0)
            self.assertNotEqual(run('--staged').returncode, 0)
            subprocess.run(['git', 'add', deps.INDEX], cwd=root, check=True)
            self.assertEqual(run('--staged').returncode, 0)
            (root / 'docs/source.md').write_text('Changed contract\n')
            self.assertNotEqual(run().returncode, 0)
            self.assertEqual(run('--staged').returncode, 0)
            subprocess.run(['git', 'add', 'docs/source.md'], cwd=root, check=True)
            (root / 'docs/source.md').write_bytes(self.files['docs/source.md'])
            result = run('--staged')
            self.assertNotEqual(result.returncode, 0)
            self.assertIn('source changed', result.stderr)


if __name__ == '__main__':
    unittest.main()
