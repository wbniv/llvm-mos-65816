#!/usr/bin/env python3
"""Exercise defect closure requirements and staged-blob isolation."""

import copy
import hashlib
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


CHECKER = Path(__file__).with_name('check-defect-evidence.py')
spec = importlib.util.spec_from_file_location('evidence', CHECKER)
evidence = importlib.util.module_from_spec(spec)
spec.loader.exec_module(evidence)


class EvidenceTests(unittest.TestCase):
    def setUp(self):
        self.files = {'report.md': b'investigation', 'repro.ll': b'input',
                      'red.log': b'error: undefined register\n',
                      'green.log': b'PASS\n', 'changed.ll': b'different input',
                      'prior-work.txt': b'Searched records, reports, patches, and source; no related defect.\n'}

        def artifact(path):
            return {'path': path, 'sha256': hashlib.sha256(self.files[path]).hexdigest()}

        self.artifact = artifact
        baseline = dict(command='baseline-compiler repro.ll', working_directory='repo',
                        toolchain_location='archive/baseline', toolchain_sha256='a' * 64,
                        configuration={'cpu': 'mos6502', 'optimization': 'Os', 'lto': False},
                        input=artifact('repro.ll'), log=artifact('red.log'), exit_code=1,
                        failure_signature='error: undefined register')
        candidate = copy.deepcopy(baseline)
        candidate.update(command='candidate-compiler repro.ll', toolchain_location='archive/candidate',
                         toolchain_sha256='b' * 64, log=artifact('green.log'), exit_code=0)
        self.record = dict(schema=1, id='test', title='Test defect', status='fixed',
                           summary='Same input fails before the identified change and passes with it.',
                           report='report.md', reproducer_origin='original', attribution=['Test author'],
                           observations=[artifact('green.log')], baseline=baseline,
                           resolution=dict(change='patch-id', causal_explanation='Preserve the lane definition.',
                                           trigger_check='The physical read remains in the regression.',
                                           regression=artifact('repro.ll'), candidate=candidate))
        self.record['prior_work'] = dict(
            disposition='new_defect', search_terms=['undefined register', 'lane definition'],
            related_records=[], related_reports=[], related_changes=[],
            source_assessment='The inspected definition-erasure path lacks the proposed preservation.',
            binary_assessment='The archived comparison is built from the recorded source.',
            decision='No canonical record or existing repair matches this mechanism.',
            evidence=artifact('prior-work.txt'))

    def check(self, previous=None):
        evidence.validate(self.record, self.files.__getitem__, previous)

    def test_complete_fixed_record(self):
        self.check()

    def test_new_record_requires_prior_work(self):
        del self.record['prior_work']
        with self.assertRaisesRegex(ValueError, 'require a prior_work audit'):
            self.check()

    def test_committed_new_record_still_requires_prior_work(self):
        del self.record['prior_work']
        with self.assertRaisesRegex(ValueError, 'require a prior_work audit'):
            self.check(copy.deepcopy(self.record))

    def test_legacy_record_does_not_require_fabricated_audit(self):
        self.record['id'] = 'bitboard-inline-register-pressure'
        del self.record['prior_work']
        self.check()

    def test_committed_audit_cannot_be_removed(self):
        self.record['id'] = 'bitboard-inline-register-pressure'
        previous = copy.deepcopy(self.record)
        del self.record['prior_work']
        with self.assertRaisesRegex(ValueError, 'preserve the committed prior-work audit'):
            self.check(previous)

    def test_duplicate_disposition_requires_existing_record(self):
        self.record['prior_work']['disposition'] = 'duplicate'
        with self.assertRaisesRegex(ValueError, 'extend the canonical record'):
            self.check()

    def test_historical_migration_requires_original_report(self):
        self.record['prior_work']['disposition'] = 'historical_migration'
        with self.assertRaisesRegex(ValueError, 'needs the existing report'):
            self.check()
        self.record['prior_work']['related_reports'] = ['report.md']
        self.check()

    def test_distinct_defect_needs_canonical_reference_and_decision(self):
        audit = self.record['prior_work']
        audit['disposition'] = 'distinct_from_related'
        with self.assertRaisesRegex(ValueError, 'needs a related canonical record'):
            self.check()
        audit['related_records'] = ['docs/defects/other.json']
        self.files['docs/defects/other.json'] = b'{"id":"other"}'
        self.check()
        audit['decision'] = ''
        with self.assertRaisesRegex(ValueError, 'needs decision'):
            self.check()

    def test_related_defect_cannot_be_called_unrelated_new_discovery(self):
        self.record['prior_work']['related_records'] = ['docs/defects/other.json']
        with self.assertRaisesRegex(ValueError, 'explicit distinct_from_related decision'):
            self.check()

    def test_related_report_must_exist(self):
        self.record['prior_work']['related_reports'] = ['missing.md']
        with self.assertRaises(KeyError):
            self.check()

    def test_related_report_cannot_leave_repository(self):
        self.record['prior_work']['related_reports'] = ['../elsewhere.md']
        with self.assertRaisesRegex(ValueError, 'must stay inside the repo'):
            self.check()

    def test_audit_hash_is_verified(self):
        self.files['prior-work.txt'] = b'changed assessment'
        with self.assertRaisesRegex(ValueError, 'artifact hash mismatch'):
            self.check()

    def test_source_and_binary_assessments_are_required(self):
        for field in ['search_terms', 'source_assessment', 'binary_assessment']:
            with self.subTest(field=field):
                audit = self.record['prior_work']
                saved = audit[field]
                audit[field] = [] if field == 'search_terms' else ''
                with self.assertRaises(ValueError):
                    self.check()
                audit[field] = saved

    def test_fixed_without_red_baseline(self):
        del self.record['baseline']
        with self.assertRaisesRegex(ValueError, 'captured failing baseline'):
            self.check()

    def test_passing_baseline_is_not_a_fix(self):
        self.record['baseline']['exit_code'] = 0
        with self.assertRaisesRegex(ValueError, 'baseline must fail'):
            self.check()

    def test_unrelated_failure_is_not_red(self):
        self.record['baseline']['failure_signature'] = 'different failure'
        with self.assertRaisesRegex(ValueError, 'expected failure signature'):
            self.check()

    def test_changed_input_is_not_a_fix(self):
        self.record['resolution']['candidate']['input'] = self.artifact('changed.ll')
        with self.assertRaisesRegex(ValueError, 'inputs must match'):
            self.check()

    def test_changed_configuration_is_not_a_fix(self):
        self.record['resolution']['candidate']['configuration']['optimization'] = 'O0'
        with self.assertRaisesRegex(ValueError, 'configuration must match'):
            self.check()

    def test_failing_candidate_cannot_close(self):
        self.record['resolution']['candidate']['exit_code'] = 1
        with self.assertRaisesRegex(ValueError, 'candidate regression must pass'):
            self.check()

    def test_artifact_edits_are_detected(self):
        self.files['repro.ll'] = b'new input'
        with self.assertRaisesRegex(ValueError, 'artifact hash mismatch'):
            self.check()

    def test_baseline_cannot_be_replaced(self):
        previous = copy.deepcopy(self.record)
        self.record['baseline']['toolchain_location'] = 'another/archive'
        with self.assertRaisesRegex(ValueError, 'baseline is immutable'):
            self.check(previous)

    def test_not_reproduced_keeps_missing_evidence_explicit(self):
        self.record.update(status='not_reproduced')
        del self.record['baseline']
        del self.record['resolution']
        with self.assertRaisesRegex(ValueError, 'missing evidence'):
            self.check()
        self.record['unknowns'] = 'The original failing binary was not recovered.'
        self.check()

    def test_cause_and_trigger_are_required(self):
        del self.record['resolution']['causal_explanation']
        with self.assertRaisesRegex(ValueError, 'causal_explanation'):
            self.check()

    def test_staged_blobs_are_independent_of_worktree(self):
        with tempfile.TemporaryDirectory(prefix='defect-evidence-test-') as directory:
            root = Path(directory)
            subprocess.run(['git', 'init', '-q', str(root)], check=True)
            for path, data in self.files.items():
                (root / path).write_bytes(data)
            record = root / 'docs/defects/test.json'
            record.parent.mkdir(parents=True)
            record.write_text(json.dumps(self.record))
            subprocess.run(['git', '-C', str(root), 'add', '.'], check=True)
            # Index evidence must describe the commit even while other work edits the files.
            (root / 'repro.ll').write_bytes(b'concurrent unstaged edit')
            staged = subprocess.run([sys.executable, str(CHECKER), '--staged'], cwd=root,
                                    capture_output=True, text=True)
            self.assertEqual(staged.returncode, 0, staged.stderr)
            working = subprocess.run([sys.executable, str(CHECKER), '--worktree'], cwd=root,
                                     capture_output=True, text=True)
            self.assertNotEqual(working.returncode, 0)
            self.assertIn('artifact hash mismatch', working.stderr)

    def test_unstaged_audit_cannot_certify_new_staged_record(self):
        with tempfile.TemporaryDirectory(prefix='defect-triage-test-') as directory:
            root = Path(directory)
            subprocess.run(['git', 'init', '-q', str(root)], check=True)
            for path, data in self.files.items():
                (root / path).write_bytes(data)
            record_path = root / 'docs/defects/test.json'
            record_path.parent.mkdir(parents=True)
            incomplete = copy.deepcopy(self.record)
            del incomplete['prior_work']
            record_path.write_text(json.dumps(incomplete))
            subprocess.run(['git', '-C', str(root), 'add', '.'], check=True)
            record_path.write_text(json.dumps(self.record))
            staged = subprocess.run([sys.executable, str(CHECKER), '--staged'], cwd=root,
                                    capture_output=True, text=True)
            self.assertNotEqual(staged.returncode, 0)
            self.assertIn('require a prior_work audit', staged.stderr)
            working = subprocess.run([sys.executable, str(CHECKER), '--worktree'], cwd=root,
                                     capture_output=True, text=True)
            self.assertEqual(working.returncode, 0, working.stderr)


if __name__ == '__main__':
    unittest.main()
