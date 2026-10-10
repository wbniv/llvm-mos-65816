#!/usr/bin/env python3
"""Exercise publication gates and three-way replay using disposable Git repos."""

import importlib.util
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile
import unittest
from unittest import mock


SCRIPT = Path(__file__).with_name('repin-llvm-mos.py')
spec = importlib.util.spec_from_file_location('repin', SCRIPT)
repin = importlib.util.module_from_spec(spec)
spec.loader.exec_module(repin)


def git(repo, *args):
    return subprocess.check_output(['git', '-C', repo, *args], stderr=subprocess.PIPE).decode().strip()


def commit(repo, message):
    git(repo, 'add', '-A')
    git(repo, 'commit', '-qm', message)
    return git(repo, 'rev-parse', 'HEAD')


class RepinTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='repin-fixture-')
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name)
        self.upstream, self.root = self.base / 'upstream', self.base / 'project'
        for repo in [self.upstream, self.root]:
            repo.mkdir()
            git(repo, 'init', '-qb', 'main')
            git(repo, 'config', 'user.email', 'fixture@local')
            git(repo, 'config', 'user.name', 'Fixture')
            git(repo, 'config', 'commit.gpgsign', 'false')
        for name in ['native.txt', 'standalone.txt', 'generic.txt', 'folded.txt']:
            (self.upstream / name).write_text('base\n')
        self.aggregate = 'first=base\n' + 'unchanged\n' * 20 + 'last=base\n'
        (self.upstream / 'aggregate.txt').write_text(self.aggregate)
        self.old = commit(self.upstream, 'upstream baseline')
        self.patches = self.root / 'patches/llvm-mos'
        self.patches.mkdir(parents=True)
        self.make_patch('0001-aggregate', {'aggregate.txt': self.aggregate.replace('=base', '=local')})
        self.make_patch('0002-native', {'native.txt': 'native\n', 'folded.txt': 'folded\n'})
        self.make_patch('0003-standalone', {'standalone.txt': 'standalone\n'})
        self.make_patch('0006-filtered', {'generic.txt': 'generic\n', 'folded.txt': 'folded\n'})
        (self.root / 'dev').mkdir()
        (self.root / repin.PIN).write_text(self.old + '\n')
        (self.root / repin.BOOT).write_text('''#!/usr/bin/env bash
apply_patch() { local p="x"; git -C "$SRC" apply "$@" "$p"; }
  apply_patch 0001-aggregate
  apply_patch 0002-native
  apply_patch 0003-standalone
  apply_patch 0006-filtered \\
    --include='generic.txt'
''')
        (self.root / repin.REGEN).write_text('STANDALONE_MOSDIR=(\n  "$PATCHES/0003-standalone.patch"\n)\n')
        for script in [repin.BOOT, repin.REGEN]:
            (self.root / script).chmod(0o755)
        (self.root / 'dev/lit.sh').write_text('fixture lit gate\n')
        runner = self.root / 'dev/container.sh'
        runner.write_text('''#!/usr/bin/env python3
import os, pathlib, sys
root = pathlib.Path.cwd()
if (root / 'fail-validation').exists():
    sys.exit(7)
args = sys.argv
env = dict(x.split('=', 1) for x in args if x.startswith('LLVM_MOS_'))
source = root / env['LLVM_MOS_SOURCE'].removeprefix('/work/')
assert (source / 'native.txt').read_text() == 'native\\n'
assert (source / 'generic.txt').read_text() == 'generic\\n'
assert (source / 'folded.txt').read_text() == 'folded\\n'
assert (source / 'standalone.txt').read_text() == 'standalone\\n'
build = root / env['LLVM_MOS_BUILDDIR'].removeprefix('/work/') / 'bin'
build.mkdir(parents=True, exist_ok=True)
for name in ['clang', 'llc', 'ld.lld']:
    (build / name).write_text('fixture tool identity\\n')
''')
        runner.chmod(0o755)
        commit(self.root, 'tracked fixture inputs')
        (self.upstream / 'aggregate.txt').write_text(self.aggregate.replace('first=base', 'first=local'))
        (self.upstream / 'standalone.txt').write_text('standalone\n')
        (self.upstream / 'upstream-only.txt').write_text('upstream\n')
        self.target = commit(self.upstream, 'upstream supplies standalone and part of aggregate')
        self.before = {str(p.relative_to(self.root)): p.read_bytes()
                       for p in self.root.rglob('*') if p.is_file() and '.git' not in p.parts}

    def make_patch(self, name, changes):
        for path, data in changes.items():
            (self.upstream / path).write_text(data)
        diff = git(self.upstream, 'diff', '--binary', '--full-index')
        if name == '0002-native':
            diff = re.sub(r'^(?:diff --git|index) .*\n', '', diff, flags=re.M)
        (self.patches / (name + '.patch')).write_text('Original fixture credit\n\n' + diff + '\n')
        git(self.upstream, 'restore', '.')

    def invoke(self, *args, success=True):
        result = subprocess.run(['python3', SCRIPT, '--root', self.root, '--upstream', self.upstream, *args],
                                stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        self.assertEqual(result.returncode, 0 if success else 1, result.stdout + result.stderr)
        runs = sorted((self.root / '.scratch/repin').glob('*/state.json'))
        return repin.Run(runs[-1].parent) if runs else None

    def assert_inputs_unchanged(self):
        for path, data in self.before.items():
            self.assertEqual((self.root / path).read_bytes(), data, path)

    def test_validated_publication_and_retirement(self):
        run = self.invoke()
        self.assertEqual(run.state['phase'], 'published')
        self.assertEqual((self.root / repin.PIN).read_text().strip(), self.target)
        self.assertNotIn('apply_patch 0003-standalone', (self.root / repin.BOOT).read_text())
        self.assertNotIn('0003-standalone.patch', (self.root / repin.REGEN).read_text())
        self.assertEqual((self.root / repin.BOOT).stat().st_mode & 0o777, 0o755)
        self.assertEqual((self.root / repin.REGEN).stat().st_mode & 0o777, 0o755)
        self.assertEqual((self.patches / '0003-standalone.patch').read_bytes(), self.before['patches/llvm-mos/0003-standalone.patch'])
        aggregate = (self.patches / '0001-aggregate.patch').read_text()
        self.assertNotIn('+first=local', aggregate)
        self.assertIn('+last=local', aggregate)
        original = repin.sections(self.before['patches/llvm-mos/0006-filtered.patch'])[1]
        exported = repin.sections((self.patches / '0006-filtered.patch').read_bytes())[1]
        self.assertEqual(original['folded.txt'], exported['folded.txt'])
        self.assertTrue((self.root / run.state['receipt']).is_file())
        self.assertEqual(git(run.repo, 'rev-parse', 'HEAD^{tree}'), run.state['candidate_tree'])

    def test_hashed_defect_artifact_uses_vendor_copy(self):
        records = self.root / 'docs/defects'
        records.mkdir(parents=True)
        path = 'patches/llvm-mos/0006-filtered.patch'
        (records / 'fixture.json').write_text(json.dumps({'observations': [
            {'path': path, 'sha256': repin.digest((self.root / path).read_bytes())}]}))
        regen = self.root / repin.REGEN
        regen.write_text(regen.read_text() + 'reverse "$PATCHES/0006-filtered.patch"\n')
        commit(self.root, 'fixture protected regeneration artifact')
        run = self.invoke()
        self.assertEqual((self.root / path).read_bytes(), self.before[path])
        vendor = 'patches/llvm-mos/0006-filtered-vendor.patch'
        receipt = json.loads((self.root / run.state['receipt']).read_text())
        self.assertEqual(receipt['preserved_artifacts'], {path: vendor})
        self.assertIn('apply_patch 0006-filtered-vendor', (self.root / repin.BOOT).read_text())
        self.assertIn('$PATCHES/0006-filtered-vendor.patch', regen.read_text())
        self.assertEqual((self.root / vendor).read_bytes(), (run.directory / 'output/0006-filtered.patch').read_bytes())

    def test_protected_vendor_collision_leaves_inputs_unchanged(self):
        records = self.root / 'docs/defects'
        records.mkdir(parents=True)
        path = 'patches/llvm-mos/0006-filtered.patch'
        (records / 'fixture.json').write_text(json.dumps({'regression': {
            'path': path, 'sha256': repin.digest((self.root / path).read_bytes())}}))
        run = self.invoke('--prepare-only')
        collision = self.patches / '0006-filtered-vendor.patch'
        collision.write_text('retain existing destination\n')
        self.invoke('--continue', str(run.directory), success=False)
        self.assertEqual(collision.read_text(), 'retain existing destination\n')
        self.assert_inputs_unchanged()

    def test_prepare_only_and_resume(self):
        run = self.invoke('--prepare-only')
        self.assertEqual(run.state['phase'], 'verified')
        self.assert_inputs_unchanged()
        self.invoke('--continue', run.directory)
        self.assertEqual((self.root / repin.PIN).read_text().strip(), self.target)

    def test_conflict_is_retained_and_resumed(self):
        (self.upstream / 'native.txt').write_text('different native\n')
        self.target = commit(self.upstream, 'conflicting upstream contract')
        run = self.invoke(success=False)
        self.assertTrue(run.state['pending'])
        self.assert_inputs_unchanged()
        (run.repo / 'native.txt').write_text('native\n')
        git(run.repo, 'add', 'native.txt')
        self.invoke('--continue', run.directory)
        self.assertEqual((self.root / repin.PIN).read_text().strip(), self.target)

    def test_validation_failure_does_not_publish(self):
        (self.root / 'fail-validation').touch()
        run = self.invoke(success=False)
        self.assertEqual(run.state['phase'], 'verified')
        self.assert_inputs_unchanged()
        (self.root / 'fail-validation').unlink()
        self.invoke('--continue', run.directory)

    def test_changed_input_blocks_publication(self):
        run = self.invoke('--prepare-only')
        patch = self.patches / '0001-aggregate.patch'
        patch.write_text(patch.read_text() + '\n')
        self.invoke('--continue', run.directory, success=False)
        self.assertEqual((self.root / repin.PIN).read_text().strip(), self.old)

    def test_dirty_inputs_rejected(self):
        (self.root / repin.PIN).write_text('dirty\n')
        result = subprocess.run(['python3', SCRIPT, '--root', self.root, '--upstream', self.upstream],
                                capture_output=True, text=True)
        self.assertEqual(result.returncode, 1)
        self.assertIn('dirty pin/patch/bootstrap', result.stderr)
        self.assertEqual((self.root / repin.PIN).read_text(), 'dirty\n')

    def test_tampered_candidate_cannot_pass_a_different_build(self):
        run = self.invoke('--prepare-only')
        (run.directory / 'verify/native.txt').write_text('unexported implementation\n')
        self.invoke('--continue', run.directory, success=False)
        self.assert_inputs_unchanged()

    def test_baseline_cache_uses_commit_blobs_without_editing_cache(self):
        cache = self.root / 'vendor' / ('llvm-mos-' + self.old[:12])
        cache.parent.mkdir()
        cache.symlink_to(self.upstream, target_is_directory=True)
        before = git(self.upstream, 'status', '--porcelain')
        run = self.invoke('--prepare-only')
        self.assertGreater(run.state['cached_baseline_blobs'], 0)
        self.assertEqual(git(self.upstream, 'status', '--porcelain'), before)
        self.assert_inputs_unchanged()

    def test_build_cache_is_retained_without_external_alternates(self):
        run = self.invoke('--prepare-only')
        cache = self.root / 'vendor/llvm-mos'
        cache.parent.mkdir()
        git(self.upstream, 'clone', '--quiet', '--no-hardlinks', str(self.upstream), str(cache))
        marker = self.base / 'cache-only.txt'
        marker.write_text('immutable cache-only object\n')
        object_id = git(cache, 'hash-object', '-w', str(marker))
        external = cache / '.git/objects/info/alternates'
        external.write_text(str(self.upstream / '.git/objects') + '\n')
        before = {str(p.relative_to(cache)): p.read_bytes()
                  for p in (cache / '.git/objects').rglob('*') if p.is_file()}
        run.seed_build_cache()
        self.assertEqual(before, {str(p.relative_to(cache)): p.read_bytes()
                                  for p in (cache / '.git/objects').rglob('*') if p.is_file()})
        cache.rename(self.root / 'vendor/moved-cache')
        self.assertEqual(git(run.repo, 'cat-file', '-t', object_id), 'blob')
        self.assertTrue(run.state['build_cache_seeded'])
        self.assertFalse((Path(run.state['retained_build_object_stores'][0]) / 'info/alternates').exists())
        self.assert_inputs_unchanged()

    def test_missing_base_objects_are_fetched_as_a_complete_pack(self):
        run = self.invoke('--prepare-only')
        thin = self.base / 'thin-target'
        thin.mkdir()
        git(thin, 'init', '-q')
        git(thin, 'remote', 'add', 'origin', str(self.upstream))
        tree = git(self.upstream, 'rev-parse', self.target + '^{tree}')
        for kind, object_id in [('tree', tree), ('commit', self.target)]:
            data = subprocess.check_output(['git', '-C', self.upstream, 'cat-file', kind, object_id])
            copied = subprocess.check_output(['git', '-C', thin, 'hash-object', '-w', '-t', kind, '--stdin'], input=data).decode().strip()
            self.assertEqual(copied, object_id)
        missing = git(thin, 'rev-list', '--objects', '--missing=print', self.target)
        self.assertTrue(any(x.startswith('?') for x in missing.splitlines()))
        run.repo = thin
        run.ensure_full_base()
        present = git(thin, 'rev-list', '--objects', '--missing=print', self.target)
        self.assertFalse(any(x.startswith('?') for x in present.splitlines()))
        self.assertEqual(git(thin, 'rev-parse', self.target + '^{tree}'), tree)
        self.assert_inputs_unchanged()

    def test_private_checkouts_survive_run_relocation(self):
        run = self.invoke('--prepare-only')
        moved = self.base / 'moved-run'
        run.directory.rename(moved)
        result = subprocess.run(['git', '-C', moved / 'verify', 'cat-file', '-t', self.target],
                                env={**os.environ, 'GIT_NO_LAZY_FETCH': '1'},
                                stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.strip(), 'commit')
        self.assert_inputs_unchanged()

    def test_empty_aggregates_keep_bootstrap_placeholders(self):
        (self.upstream / 'aggregate.txt').write_text(self.aggregate.replace('=base', '=local'))
        (self.upstream / 'native.txt').write_text('native\n')
        (self.upstream / 'folded.txt').write_text('folded\n')
        self.target = commit(self.upstream, 'upstream supplies both aggregates')
        run = self.invoke()
        self.assertTrue(all(x['empty'] for x in run.state['patches'][:2]))
        self.assertIn('apply_patch 0001-aggregate', (self.root / repin.BOOT).read_text())
        self.assertIn('apply --allow-empty', (self.root / repin.BOOT).read_text())
        self.assertEqual(repin.sections((self.patches / '0001-aggregate.patch').read_bytes())[1], {})

    def test_publication_error_rolls_back_prior_writes(self):
        run = self.invoke('--prepare-only')
        run.validate()
        replace = Path.replace

        def fail_pin(path, destination):
            if str(destination).endswith(repin.PIN):
                raise OSError('fixture pin replacement failure')
            return replace(path, destination)

        with mock.patch.object(Path, 'replace', fail_pin):
            with self.assertRaises(OSError):
                run.publish()
        self.assert_inputs_unchanged()
        self.assertEqual(list((self.root / 'docs/upstream-status').glob('*.json')), [])
        self.assertEqual(list((self.root / 'dev').glob('*.repin-*')), [])

    def test_modified_export_cannot_publish_against_a_different_build(self):
        run = self.invoke('--prepare-only')
        export = run.directory / 'output/0001-aggregate.patch'
        export.write_text(export.read_text() + '\n')
        self.invoke('--continue', run.directory, success=False)
        self.assert_inputs_unchanged()

    def test_active_bootstrap_is_parsed_without_globbing(self):
        actual = repin.calls(SCRIPT.with_name('toolchain.sh').read_text())
        self.assertEqual([x['name'] for x in actual[:2]], ['0001-320-far-addrspace', '0002-321-accum16'])
        filtered = next(x for x in actual if x['name'] == '0006-320-packed24')
        self.assertEqual(len(filtered['flags']), 4)
        reduced = next(x for x in actual if x['name'] == '0038-mos-return-frame-address')
        self.assertEqual(reduced['flags'], ['-C1'])


if __name__ == '__main__':
    unittest.main()
