#!/usr/bin/env python3
"""Validate compiler-defect records and their retained evidence."""

import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
import re
import subprocess
import sys


STATUSES = {'confirmed', 'not_reproduced', 'workaround', 'fixed', 'invalid',
            'contract_clarification'}
SHA256 = re.compile(r'[0-9a-f]{64}\Z')
RECORD = re.compile(r'docs/defects/[a-z0-9][a-z0-9-]*\.json\Z')
# Only these established records may omit a prior-work audit. New IDs must
# identify their relationship to existing reports, implementations, and builds.
LEGACY_RECORDS = frozenset({
    'bitboard-inline-register-pressure',
    'gisel-inline-asm-register-bounds',
    'llvm-reduce-parallel-mir-crash',
    'mos-bank-relax-section-offset',
    'mos-coalescing-rc-undef',
    'mos-float-vector-legalization',
    'mos-trunc-imag8-i1',
    'mos-vector-o0-status-scavenge',
    'mos-zp-index-same-width-trunc',
    'reentrant-attribute-contract',
    'selectiondag-inline-asm-nonstandard-integer',
    'selectiondag-inline-asm-register-bounds',
    'selectiondag-inline-asm-vector-parts',
    'shift64-narrow-count',
})


def require(condition, message):
    if not condition:
        raise ValueError(message)


def nonempty(value):
    return isinstance(value, str) and bool(value.strip())


def artifact(value, read):
    require(isinstance(value, dict), 'artifact must be an object')
    path, digest = value.get('path'), value.get('sha256')
    require(nonempty(path) and not PurePosixPath(path).is_absolute()
            and '..' not in PurePosixPath(path).parts, 'artifact path must stay inside the repo')
    require(isinstance(digest, str) and SHA256.fullmatch(digest),
            f'{path}: missing SHA-256')
    data = read(path)
    require(hashlib.sha256(data).hexdigest() == digest, f'{path}: artifact hash mismatch')
    return data


def check_run(run, read, red):
    require(isinstance(run, dict), 'missing baseline/candidate run')
    for field in ('command', 'toolchain_location', 'working_directory'):
        require(nonempty(run.get(field)), f'run needs {field}')
    require(isinstance(run.get('configuration'), dict) and run['configuration'],
            'run needs explicit target/optimization/pass configuration')
    require(isinstance(run.get('toolchain_sha256'), str)
            and SHA256.fullmatch(run['toolchain_sha256']), 'run needs toolchain SHA-256')
    artifact(run.get('input'), read)
    log = artifact(run.get('log'), read).decode(errors='replace')
    code = run.get('exit_code')
    require(type(code) is int, 'run needs an integer regression-runner exit_code')
    if red:
        require(code != 0, 'baseline must fail; a passing baseline cannot prove a fix')
        signature = run.get('failure_signature')
        require(nonempty(signature) and signature in log,
                'baseline log must contain the expected failure signature')
    else:
        require(code == 0, 'candidate regression must pass')


def check_prior_work(record, read, previous):
    audit = record.get('prior_work')
    if audit is None:
        require(not previous or previous.get('prior_work') is None,
                'preserve the committed prior-work audit')
        require(record['id'] in LEGACY_RECORDS,
                'new defect records require a prior_work audit; reconcile existing reports and patches')
        return
    require(isinstance(audit, dict), 'prior_work must be an object')
    disposition = audit.get('disposition')
    require(disposition in {'new_defect', 'historical_migration', 'distinct_from_related'},
            'repeat sightings must extend the canonical record; choose an evidence-backed disposition')
    for field in ('search_terms', 'related_records', 'related_reports', 'related_changes'):
        values = audit.get(field)
        require(isinstance(values, list) and all(nonempty(x) for x in values),
                f'prior_work needs a {field} list')
        require(len(set(values)) == len(values), f'prior_work {field} contains duplicate entries')
    require(audit['search_terms'], 'prior_work needs actual search terms')
    for field in ('source_assessment', 'binary_assessment', 'decision'):
        require(nonempty(audit.get(field)), f'prior_work needs {field}')
    if disposition == 'historical_migration':
        require(audit['related_reports'], 'historical_migration needs the existing report')
    if disposition == 'distinct_from_related':
        require(audit['related_records'], 'distinct_from_related needs a related canonical record')
    if audit['related_records']:
        require(disposition == 'distinct_from_related',
                'related canonical records require an explicit distinct_from_related decision')
    for path in audit['related_records']:
        require(RECORD.fullmatch(path), 'related record must use a canonical defect path')
        require(Path(path).stem != record['id'], 'a prior-work audit cannot refer to itself')
        related = json.loads(read(path))
        require(isinstance(related, dict) and related.get('id') == Path(path).stem,
                f'{path}: related record id must match its filename')
    for path in audit['related_reports']:
        require(not PurePosixPath(path).is_absolute() and '..' not in PurePosixPath(path).parts,
                'related report path must stay inside the repo')
        read(path)
    artifact(audit.get('evidence'), read)


def validate(record, read, previous=None):
    require(isinstance(record, dict) and record.get('schema') == 1, 'expected schema 1')
    for field in ('id', 'title', 'summary', 'report'):
        require(nonempty(record.get(field)), f'missing {field}')
    require(record.get('status') in STATUSES, 'unknown status')
    require(record.get('reproducer_origin') in {'original', 'reduced', 'reconstructed', 'unknown'},
            'label the reproducer origin')
    require(isinstance(record.get('attribution'), list) and record['attribution']
            and all(nonempty(x) for x in record['attribution']), 'missing attribution')
    report = record['report']
    require(not PurePosixPath(report).is_absolute() and '..' not in PurePosixPath(report).parts,
            'report path must stay inside the repo')
    read(report)
    evidence = record.get('observations')
    require(isinstance(evidence, list) and evidence, 'retain observation artifacts')
    for item in evidence:
        artifact(item, read)
    if record['status'] == 'not_reproduced':
        require(nonempty(record.get('unknowns')), 'not_reproduced needs explicit missing evidence')

    baseline = record.get('baseline')
    if baseline is not None:
        check_run(baseline, read, red=True)
    if record['status'] in {'confirmed', 'workaround', 'fixed'}:
        require(baseline is not None, 'this status requires a captured failing baseline')
    if record['status'] == 'fixed':
        resolution = record.get('resolution')
        require(isinstance(resolution, dict), 'fixed needs a resolution')
        for field in ('change', 'causal_explanation', 'trigger_check'):
            require(nonempty(resolution.get(field)), f'fixed needs {field}')
        regression = resolution.get('regression')
        artifact(regression, read)
        candidate = resolution.get('candidate')
        check_run(candidate, read, red=False)
        require(baseline['input']['sha256'] == candidate['input']['sha256']
                == regression['sha256'], 'red, green, and regression inputs must match')
        require(baseline['configuration'] == candidate['configuration'],
                'red/green target, optimization, and pass configuration must match')
        require(baseline['toolchain_sha256'] != candidate['toolchain_sha256'],
                'identify distinct baseline and candidate toolchains')
    if record['status'] == 'invalid':
        require(nonempty(record.get('invalidation_reason')),
                'invalid needs a specific evidence-backed reporting error')
    check_prior_work(record, read, previous)
    if previous and previous.get('baseline') is not None:
        require(baseline == previous['baseline'],
                'captured baseline is immutable; append observations/additional_runs to the canonical record')


def git(root, *args):
    return subprocess.check_output(['git', '-C', str(root), *args], stderr=subprocess.PIPE)


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    mode = ap.add_mutually_exclusive_group(required=True)
    mode.add_argument('--staged', action='store_true', help='read index blobs, as the hook does')
    mode.add_argument('--worktree', action='store_true', help='include unstaged/untracked records')
    args = ap.parse_args()
    root = Path(git(Path.cwd(), 'rev-parse', '--show-toplevel').decode().strip())
    paths = git(root, 'ls-files', '-z').decode().split('\0') if args.staged else [
        str(p.relative_to(root)) for p in (root / 'docs/defects').rglob('*.json')]
    records = {p for p in paths if RECORD.fullmatch(p)}
    # Noncanonical record names must not silently escape validation.
    invalid = [p for p in paths if p.startswith('docs/defects/')
               and not p.startswith('docs/defects/evidence/') and p.endswith('.json')
               and not RECORD.fullmatch(p)]
    failures = [f'{p}: use docs/defects/<lowercase-id>.json' for p in invalid]
    try:
        old_paths = git(root, 'ls-tree', '-r', '--name-only', 'HEAD', '--', 'docs/defects').decode().splitlines()
    except subprocess.CalledProcessError:
        old_paths = []
    old_records = {p for p in old_paths if RECORD.fullmatch(p)}
    failures.extend(f'{p}: preserve defect records; change status instead of deleting'
                    for p in old_records - records)

    def read(path):
        if args.staged:
            return git(root, 'show', ':' + path)
        resolved = (root / path).resolve()
        require(resolved.is_relative_to(root), f'{path}: path leaves repository')
        return resolved.read_bytes()

    for path in sorted(records):
        try:
            record = json.loads(read(path))
            require(isinstance(record, dict), 'record must be an object')
            require(record.get('id') == Path(path).stem, 'id must match filename')
            previous = json.loads(git(root, 'show', 'HEAD:' + path)) if path in old_records else None
            validate(record, read, previous)
        except (ValueError, OSError, subprocess.CalledProcessError, TypeError, KeyError) as error:
            failures.append(f'{path}: {error}')
    for message in failures:
        print(message, file=sys.stderr)
    if failures:
        print('Defect evidence: FAIL. See docs/howto-defect-evidence.md.', file=sys.stderr)
        return 1
    print(f'Defect evidence: PASS ({len(records)} records, {"index" if args.staged else "worktree"})')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
