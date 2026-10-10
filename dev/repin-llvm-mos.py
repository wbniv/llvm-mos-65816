#!/usr/bin/env python3
"""Replay the active bootstrap stack onto a fetched upstream revision."""

import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import re
import shlex
import subprocess
import sys
import tempfile


PIN = 'dev/llvm-mos-pin'
BOOT = 'dev/toolchain.sh'
REGEN = 'dev/regen-patch.sh'


def digest(data):
    return hashlib.sha256(data).hexdigest()


def protected_patches(root):
    """Hashed patch artifacts in defect records retain their recorded bytes."""
    paths = set()

    def visit(value):
        if isinstance(value, dict):
            path = value.get('path', '')
            if isinstance(path, str) and path.startswith('patches/llvm-mos/') and 'sha256' in value:
                paths.add(path)
            for child in value.values():
                visit(child)
        elif isinstance(value, list):
            for child in value:
                visit(child)

    for record in (root / 'docs/defects').glob('*.json'):
        visit(json.loads(record.read_text()))
    return paths


def calls(text):
    """Keep each shell call's literal text for exact removal on retirement."""
    result, pending = [], ''
    for line in text.splitlines(keepends=True):
        pending += line
        if line.rstrip('\n').endswith('\\'):
            continue
        logical = pending.replace('\\\n', ' ')
        if logical.lstrip().startswith('apply_patch '):
            words = shlex.split(logical)
            if not re.fullmatch(r'[0-9]{4}-[\w.-]+', words[1]):
                raise ValueError('Unsupported bootstrap patch name: ' + words[1])
            if any(not (x.startswith('--include=') or re.fullmatch(r'-C\d+', x))
                   for x in words[2:]):
                raise ValueError('Unsupported apply options: ' + logical)
            result.append({'name': words[1], 'flags': words[2:], 'call': pending})
        pending = ''
    if not result or len({x['name'] for x in result}) != len(result):
        raise ValueError('Expected unique literal apply_patch calls in bootstrap')
    return result


def sections(data):
    text = data.decode()
    tokens = re.finditer(r'^diff --git [^\n]+$|^--- (?:a/[^\n]+|/dev/null)\n\+\+\+ (?:b/[^\n]+|/dev/null)$', text, re.M)
    starts, git_pair = [], False
    for match in tokens:
        if match.group().startswith('diff --git '):
            path = shlex.split(match.group())[3].removeprefix('b/')
            starts.append((match.start(), path))
            git_pair = True
        elif git_pair:
            git_pair = False
        else:
            old, new = match.group().splitlines()
            path = (old[4:].removeprefix('a/') if new[4:] == '/dev/null'
                    else new[4:].removeprefix('b/')).split('\t')[0]
            starts.append((match.start(), path))
    result = {}
    for i, (start, path) in enumerate(starts):
        result[path] = text[start:starts[i + 1][0] if i + 1 < len(starts) else len(text)]
    return text[:starts[0][0]] if starts else text, result


class Run:
    def __init__(self, directory):
        self.directory = directory.resolve()
        self.state_file = self.directory / 'state.json'
        self.state = json.loads(self.state_file.read_text())
        self.root = Path(self.state['root'])
        self.repo = self.directory / 'candidate'
        self.log = self.directory / 'commands.log'

    def save(self):
        tmp = self.state_file.with_suffix('.tmp')
        tmp.write_text(json.dumps(self.state, indent=2) + '\n')
        tmp.replace(self.state_file)

    def command(self, args, cwd=None, check=True, capture=True, input_data=None):
        args = [str(x) for x in args]
        with self.log.open('a') as log:
            log.write('$ ' + shlex.join(args) + '\n')
            log.flush()
            proc = subprocess.run(args, cwd=cwd, stdout=subprocess.PIPE if capture else log,
                                  stderr=log, input=input_data, env={**os.environ, 'GIT_EDITOR': 'true',
                                                   'GIT_TERMINAL_PROMPT': '0'})
            if capture:
                log.write(proc.stdout.decode(errors='replace'))
            log.write(f'\nexit: {proc.returncode}\n')
        if check and proc.returncode:
            raise RuntimeError(f'Command failed ({proc.returncode}): {shlex.join(args)}; see {self.log}')
        return proc

    def git(self, *args, check=True, repo=None):
        return self.command(['git', '-C', repo or self.repo, *args], check=check)

    def value(self, *args):
        return self.git(*args).stdout.decode().strip()

    def unchanged(self):
        for path, expected in self.state['inputs'].items():
            if digest((self.root / path).read_bytes()) != expected:
                raise RuntimeError(f'Input changed during run: {path}; tracked files were not updated')

    def exports_unchanged(self):
        for name, expected in self.state['export_sha256'].items():
            if digest((self.directory / 'output' / name).read_bytes()) != expected:
                raise RuntimeError('Exported patch changed after verification: ' + name)

    def sparse(self, repo):
        patterns = ''.join('/' + p + '\n' for p in self.state['sparse_paths']).encode()
        self.command(['git', '-C', repo, 'sparse-checkout', 'set', '--no-cone', '--stdin'],
                     input_data=patterns)

    def checkout(self, path, sparse=False):
        """Each private checkout shares only this run's retained object store."""
        self.command(['git', 'init', '--quiet', path])
        objects = path / '.git/objects/info/alternates'
        objects.write_text(os.path.relpath(self.repo / '.git/objects', path / '.git/objects') + '\n')
        shallow = self.repo / '.git/shallow'
        if shallow.exists():
            (path / '.git/shallow').write_bytes(shallow.read_bytes())
        self.git('remote', 'add', 'origin', self.state['upstream'], repo=path)
        self.git('config', 'remote.origin.promisor', 'true', repo=path)
        self.git('config', 'remote.origin.partialclonefilter', 'blob:none', repo=path)
        self.git('config', 'http.lowSpeedLimit', '1024', repo=path)
        self.git('config', 'http.lowSpeedTime', '60', repo=path)
        if sparse:
            self.sparse(path)
        self.git('checkout', '--quiet', '--detach', self.state['target'], repo=path)

    def seed_baseline_cache(self):
        caches = [self.root / 'vendor' / ('llvm-mos-' + self.state['old_pin'][:12]),
                  self.root / 'vendor/llvm-mos']
        copied = 0
        for path in self.state['sparse_paths']:
            for cache in caches:
                if not (cache / '.git').exists():
                    continue
                blob = self.command(['env', 'GIT_NO_LAZY_FETCH=1', 'git', '-C', cache,
                                     'show', self.state['old_pin'] + ':' + path], check=False)
                if blob.returncode == 0:
                    self.command(['git', '-C', self.repo, 'hash-object', '-w', '--stdin'],
                                 input_data=blob.stdout)
                    copied += 1
                    break
        self.state['cached_baseline_blobs'] = copied

    def seed_build_cache(self):
        """Retain local immutable objects so full checkout fetches only misses."""
        if self.state.get('build_cache_seeded'):
            return
        stores = []
        for index, cache in enumerate([self.root / 'vendor' / ('llvm-mos-' + self.state['old_pin'][:12]),
                                       self.root / 'vendor/llvm-mos']):
            objects = cache / '.git/objects'
            if not objects.is_dir():
                continue
            retained = self.directory / ('build-objects-' + str(index))
            retained.mkdir(exist_ok=True)
            # Exclude info/alternates: every referenced store must be retained
            # inside this run, independent of the shared cache's lifetime.
            for source in objects.iterdir():
                if source.is_dir() and (source.name == 'pack' or re.fullmatch(r'[0-9a-f]{2}', source.name)):
                    destination = retained / source.name
                    destination.mkdir(exist_ok=True)
                    self.command(['cp', '-a', '--reflink=auto', str(source) + '/.', destination])
            stores.append(str(retained))
        if stores:
            (self.repo / '.git/objects/info/alternates').write_text(
                ''.join(os.path.relpath(x, self.repo / '.git/objects') + '\n' for x in stores))
        self.state['build_cache_seeded'] = True
        self.state['retained_build_object_stores'] = stores
        self.save()

    def ensure_full_base(self):
        inventory = self.git('rev-list', '--objects', '--missing=print', self.state['target']).stdout
        if any(line.startswith(b'?') for line in inventory.splitlines()):
            # A complete shallow pack lets the server traverse one revision,
            # rather than assemble a request for thousands of individual blobs.
            self.git('-c', 'http.lowSpeedTime=300', 'fetch', '--quiet', '--depth=1',
                     '--refetch', '--no-filter', 'origin', self.state['target'])

    def replay(self):
        self.unchanged()
        entries = self.state['patches']
        while self.state['index'] < len(entries):
            entry = entries[self.state['index']]
            if self.state.get('pending'):
                if self.value('diff', '--name-only', '--diff-filter=U'):
                    raise RuntimeError('Resolve and stage candidate conflicts, then use --continue')
                pick = self.git('cherry-pick', '--continue', check=False)
            else:
                self.state['parent'] = self.value('rev-parse', 'HEAD')
                self.state['pending'] = True
                self.save()
                pick = self.git('cherry-pick', entry['commit'], check=False)
            if pick.returncode:
                if self.value('diff', '--name-only', '--diff-filter=U'):
                    raise RuntimeError(f'Conflict in {entry["name"]}; resolve and git add in {self.repo}')
                if (self.git('diff', '--cached', '--quiet', check=False).returncode == 0
                        and self.git('diff', '--quiet', check=False).returncode == 0
                        and self.git('rev-parse', '--verify', 'CHERRY_PICK_HEAD', check=False).returncode == 0):
                    self.git('cherry-pick', '--skip')
                else:
                    raise RuntimeError(f'Replay failed for {entry["name"]}; see {self.log}')
            entry['result'] = self.value('rev-parse', 'HEAD')
            entry['empty'] = entry['result'] == self.state['parent']
            diff = self.git('diff', '--binary', '--full-index', self.state['parent'], entry['result']).stdout
            prefix, original = sections((self.directory / 'inputs' / entry['path']).read_bytes())
            _, updated = sections(diff)
            self.state['sparse_paths'] = sorted(set(self.state['sparse_paths']) | updated.keys())
            if entry['flags']:
                for path in entry['selected_paths']:
                    original.pop(path, None)
                original.update(updated)
                body = ''.join(original.values())
            else:
                body = ''.join(updated.values())
            # Keep headers and excluded hunks; only the active replayed paths change.
            output = (prefix + body).encode()
            (self.directory / 'output' / Path(entry['path']).name).write_bytes(output)
            self.state['index'] += 1
            self.state['pending'] = False
            self.save()
        self.state['phase'] = 'exported'
        self.save()

    def verify(self):
        verify = self.directory / 'verify'
        if verify.exists():
            verify = Path(tempfile.mkdtemp(prefix='verify-', dir=self.directory))
        self.checkout(verify, sparse=True)
        for entry in self.state['patches']:
            if not entry['empty']:
                self.git('apply', '--allow-empty', *entry['flags'],
                         self.directory / 'output' / Path(entry['path']).name, repo=verify)
        self.git('add', '-A', repo=verify)
        replay_tree = self.value('rev-parse', 'HEAD^{tree}')
        apply_tree = self.git('write-tree', repo=verify).stdout.decode().strip()
        if apply_tree != replay_tree:
            raise RuntimeError('Fresh application differs from the replayed candidate')
        self.state['candidate_tree'] = replay_tree
        self.state['verify_directory'] = verify.name
        self.state['candidate_commit'] = self.value('rev-parse', 'HEAD')
        self.state['export_sha256'] = {p.name: digest(p.read_bytes())
                                       for p in (self.directory / 'output').iterdir()}
        self.state['phase'] = 'verified'
        self.save()

    def validate(self):
        self.unchanged()
        self.exports_unchanged()
        verify = self.directory / self.state['verify_directory']
        self.git('add', '-A', repo=verify)
        if self.git('write-tree', repo=verify).stdout.decode().strip() != self.state['candidate_tree']:
            raise RuntimeError('Verified source changed; refusing to validate a different candidate')
        # Configure/build may edit their source cache. Each attempt starts from
        # the frozen exported tree and keeps the independent replay untouched.
        self.seed_build_cache()
        self.ensure_full_base()
        source_dir = Path(tempfile.mkdtemp(prefix='build-source-', dir=self.directory))
        self.checkout(source_dir)
        self.git('read-tree', '--reset', '-u', self.state['candidate_commit'], repo=source_dir)
        relative = self.directory.relative_to(self.root)
        source = '/work/' + str(relative / source_dir.name)
        build = '/work/build/repin/' + self.directory.name + '/' + source_dir.name
        env = ['env', 'LLVM_MOS_PIN=' + self.state['target'],
               'LLVM_MOS_SOURCE=' + source, 'LLVM_MOS_BUILDDIR=' + build,
               'LLVM_MOS_INSTALL=' + build + '/install']
        for script in [BOOT, 'dev/lit.sh']:
            print('Validation:', script, flush=True)
            self.command([self.root / 'dev/container.sh', '--', *env, 'bash', script],
                         cwd=self.root, capture=False)
        tested_diff = self.git('diff', '--binary', '--full-index', 'HEAD', repo=source_dir).stdout
        (self.directory / 'validated-source.diff').write_bytes(tested_diff)
        self.state['validated_source_diff_sha256'] = digest(tested_diff)
        binaries = self.root / 'build' / 'repin' / self.directory.name / source_dir.name / 'bin'
        self.state['binary_sha256'] = {str(binaries / name): digest((binaries / name).read_bytes())
                                       for name in ['clang', 'llc', 'ld.lld']}
        self.state['phase'] = 'validated'
        self.save()

    def publish(self):
        self.unchanged()
        self.exports_unchanged()
        changed = {}
        boot = (self.directory / 'inputs' / BOOT).read_text()
        regen = (self.directory / 'inputs' / REGEN).read_text()
        retired = []
        protected = protected_patches(self.root)
        preserved = {}
        for entry in self.state['patches']:
            if entry['empty'] and not entry['name'].startswith(('0001-', '0002-')):
                retired.append(entry['name'])
                boot = boot.replace(entry['call'], '')
                # Remove whole-artifact reverse applications; filtered companions
                # may still contain folded implementation and are retained on disk.
                if not entry['flags']:
                    regen = ''.join(line for line in regen.splitlines(keepends=True)
                                    if f'$PATCHES/{entry["name"]}.patch' not in line)
                continue
            destination = entry['path']
            if destination in protected:
                destination = str(Path(destination).with_name(entry['name'] + '-vendor.patch'))
                if (self.root / destination).exists():
                    raise RuntimeError('Protected artifact vendor destination already exists: ' + destination)
                preserved[entry['path']] = destination
                boot = boot.replace(entry['call'], entry['call'].replace(entry['name'], entry['name'] + '-vendor', 1))
                regen = regen.replace(f'$PATCHES/{entry["name"]}.patch',
                                      f'$PATCHES/{entry["name"]}-vendor.patch')
            changed[destination] = (self.directory / 'output' / Path(entry['path']).name).read_bytes()
        boot = boot.replace('git -C "$SRC" apply "$@" "$p"',
                            'git -C "$SRC" apply --allow-empty "$@" "$p"')
        if any(x['empty'] and x['name'].startswith(('0001-', '0002-')) for x in self.state['patches']):
            regen = re.sub(r'(?m)^([ \t]*git [^\n]*?) apply (?!--allow-empty(?: |$))',
                           r'\1 apply --allow-empty ', regen)
        changed[BOOT], changed[REGEN] = boot.encode(), regen.encode()
        changed[PIN] = (self.state['target'] + '\n').encode()
        receipt_path = f'docs/upstream-status/repin-{self.directory.name}.json'
        receipt = {'old_pin': self.state['old_pin'], 'pin': self.state['target'],
                   'upstream': self.state['upstream'], 'ref': self.state['ref'],
                   'candidate_tree': self.state['candidate_tree'], 'retired_applications': retired,
                   'preserved_artifacts': preserved,
                   'input_sha256': self.state['inputs'],
                   'output_sha256': {p: digest(b) for p, b in changed.items()},
                   'run_directory': str(self.directory), 'commands': str(self.log),
                   'binary_sha256': self.state['binary_sha256'],
                   'validated_source_diff_sha256': self.state['validated_source_diff_sha256'],
                   'validation': 'Independent patch replay, isolated compiler build and MOS CodeGen/MC suites passed.',
                   'limitations': 'No new runtime/performance result or historical defect closure. Review affected maintained docs before committing.'}
        changed[receipt_path] = (json.dumps(receipt, indent=2) + '\n').encode()
        backups = {p: (self.root / p).read_bytes() if (self.root / p).exists() else None for p in changed}
        written = []
        try:
            for path in [p for p in changed if p != PIN] + [PIN]:
                dest = self.root / path
                dest.parent.mkdir(parents=True, exist_ok=True)
                fd, name = tempfile.mkstemp(prefix=dest.name + '.repin-', dir=dest.parent)
                temp = Path(name)
                try:
                    with os.fdopen(fd, 'wb') as output:
                        output.write(changed[path])
                    if dest.exists():
                        temp.chmod(dest.stat().st_mode & 0o777)
                    else:
                        temp.chmod(0o644)
                    written.append(path)
                    temp.replace(dest)
                finally:
                    temp.unlink(missing_ok=True)
        except BaseException:
            for path in reversed(written):
                if backups[path] is None:
                    (self.root / path).unlink(missing_ok=True)
                else:
                    (self.root / path).write_bytes(backups[path])
            raise
        self.state['phase'] = 'published'
        self.state['receipt'] = receipt_path
        self.save()
        print(f'Updated pin to {self.state["target"]}; receipt: {receipt_path}')
        print('Review git diff and run document impact/review/refresh before committing. No commit or push was made.')


def start(root, upstream, ref):
    root = root.resolve()
    entries = calls((root / BOOT).read_text())
    paths = [PIN, BOOT, REGEN] + ['patches/llvm-mos/' + x['name'] + '.patch' for x in entries]
    dirty = subprocess.check_output(['git', '-C', root, 'status', '--porcelain', '--', *paths])
    if dirty:
        raise RuntimeError('Commit or preserve dirty pin/patch/bootstrap inputs before starting:\n' + dirty.decode())
    directory = Path(tempfile.mkdtemp(prefix=datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ-'),
                                     dir=root / '.scratch' / 'repin'))
    inputs = {}
    for path in paths:
        data = (root / path).read_bytes()
        dest = directory / 'inputs' / path
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_bytes(data)
        inputs[path] = digest(data)
    state = {'root': str(root), 'old_pin': (root / PIN).read_text().strip(),
             'upstream': upstream, 'ref': ref, 'inputs': inputs, 'patches': entries,
             'index': 0, 'phase': 'starting'}
    state['sparse_paths'] = sorted({path for entry in entries
                                    for path in sections((root / 'patches/llvm-mos' / (entry['name'] + '.patch')).read_bytes())[1]})
    (directory / 'state.json').write_text(json.dumps(state, indent=2) + '\n')
    run = Run(directory)
    print('Run directory:', directory, flush=True)
    (directory / 'output').mkdir()
    run.command(['git', 'init', '--quiet', run.repo])
    run.git('config', 'user.name', 'llvm-mos patch replay')
    run.git('config', 'user.email', 'patch-replay@local')
    run.git('config', 'commit.gpgsign', 'false')
    # Replay commits belong to a private checkout with its own hooks; the root
    # repository's checks still govern the resulting tracked patch changes.
    run.git('config', 'core.hooksPath', str(run.repo / '.git/hooks'))
    run.git('config', 'core.quotePath', 'false')
    run.git('remote', 'add', 'origin', upstream)
    run.git('config', 'remote.origin.promisor', 'true')
    run.git('config', 'remote.origin.partialclonefilter', 'blob:none')
    run.git('config', 'http.lowSpeedLimit', '1024')
    run.git('config', 'http.lowSpeedTime', '60')
    run.sparse(run.repo)
    run.seed_baseline_cache()
    run.git('fetch', '--quiet', '--filter=blob:none', '--depth=1', 'origin', ref)
    run.state['target'] = run.value('rev-parse', 'FETCH_HEAD^{commit}')
    run.git('fetch', '--quiet', '--filter=blob:none', '--depth=1', 'origin', state['old_pin'])
    run.git('checkout', '--quiet', '--detach', state['old_pin'])
    for entry in run.state['patches']:
        entry['path'] = 'patches/llvm-mos/' + entry['name'] + '.patch'
        run.git('apply', '--allow-empty', *entry['flags'], directory / 'inputs' / entry['path'])
        run.git('add', '-A')
        entry['selected_paths'] = run.git('diff', '--cached', '--name-only', '-z').stdout.decode().strip('\0').split('\0')
        run.git('commit', '--quiet', '--allow-empty', '-m', 'Replay artifact ' + entry['name'])
        entry['commit'] = run.value('rev-parse', 'HEAD')
    run.git('checkout', '--quiet', '--detach', run.state['target'])
    run.state['phase'] = 'replay'
    run.save()
    return run


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=Path(__file__).resolve().parent.parent)
    parser.add_argument('--upstream', default='https://github.com/llvm-mos/llvm-mos.git')
    parser.add_argument('--ref', default='main')
    parser.add_argument('--continue', dest='resume', type=Path, metavar='RUN_DIRECTORY')
    parser.add_argument('--prepare-only', action='store_true', help='verify replay without building or publishing')
    args = parser.parse_args()
    run = None
    try:
        if args.resume:
            run = Run(args.resume)
        else:
            (args.root / '.scratch' / 'repin').mkdir(parents=True, exist_ok=True)
            run = start(args.root, args.upstream, args.ref)
        phase = run.state['phase']
        if phase in ('verified', 'validated') and 'export_sha256' not in run.state:
            # A receipt without export hashes must earn them through fresh
            # application before its candidate can enter the build gate.
            run.state['phase'] = phase = 'exported'
            run.save()
        if phase == 'starting':
            raise RuntimeError('Initial preparation failed; retained inputs/logs can be inspected. Start a new run.')
        if phase == 'published':
            print('Run already published:', run.state['receipt'])
            return 0
        if phase == 'replay':
            run.replay()
        if run.state['phase'] == 'exported':
            run.verify()
        if args.prepare_only:
            print(f'Candidate verified; current pin unchanged. Resume with --continue {run.directory}')
            return 0
        if run.state['phase'] == 'verified':
            run.validate()
        if run.state['phase'] == 'validated':
            run.publish()
        return 0
    except (RuntimeError, ValueError, OSError, subprocess.CalledProcessError) as exc:
        print(str(exc), file=sys.stderr)
        if run:
            print(f'After resolving the failure: {sys.executable} {Path(__file__).resolve()} --continue {run.directory}', file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main())
