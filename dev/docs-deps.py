#!/usr/bin/env python3
"""Inventory document references, report change impact, and check declared derivatives."""

import argparse
from collections import defaultdict, deque
from datetime import datetime, timezone
import fnmatch
import hashlib
import html
from html.parser import HTMLParser
import json
from pathlib import Path, PurePosixPath
import posixpath
import re
import subprocess
import sys
from urllib.parse import unquote, urlsplit

MANIFEST = 'docs/document-dependencies.json'
INDEX = 'docs/document-dependencies.md'


class Tree:
    def __init__(self, root, staged=False):
        self.root, self.staged, self.cache = root, staged, {}
        args = ['git', 'ls-files', '-z', '--cached']
        if not staged:
            args += ['--others', '--exclude-standard']
        self.paths = set(subprocess.check_output(args, cwd=root).decode().split('\0')) - {''}
        if not staged:
            self.paths = {p for p in self.paths if (root / p).is_file()}

    def read(self, path):
        if path not in self.cache:
            if self.staged:
                self.cache[path] = subprocess.check_output(['git', 'show', ':' + path], cwd=self.root)
            else:
                self.cache[path] = (self.root / path).read_bytes()
        return self.cache[path]


def fingerprint(tree, sources):
    result = {}
    for spec in sources:
        pattern = spec if isinstance(spec, str) else spec['glob']
        paths = sorted(p for p in tree.paths if PurePosixPath(p).match(pattern))
        if not paths:
            raise ValueError('Missing dependency: ' + pattern)
        for path in paths:
            value = tree.read(path)
            if isinstance(spec, dict) and spec.get('fields'):
                data = json.loads(value)
                selected = {}
                for field in spec['fields']:
                    current = data
                    for part in field.split('.'):
                        current = current.get(part) if isinstance(current, dict) else None
                    selected[field] = current
                value = json.dumps(selected, sort_keys=True).encode()
            result[path] = hashlib.sha256(value).hexdigest()
    return result


def output_hashes(tree, outputs):
    return {p: hashlib.sha256(tree.read(p)).hexdigest() for p in outputs}


def assert_acyclic(edges):
    visiting, done = set(), set()

    def visit(node):
        if node in visiting:
            raise ValueError('Derived-document dependency cycle at ' + node)
        if node in done:
            return
        visiting.add(node)
        for dependency in edges.get(node, ()):
            visit(dependency)
        visiting.remove(node)
        done.add(node)

    for node in edges:
        visit(node)


def generation_order(tree, groups):
    owners = {output: group['id'] for group in groups for output in group['outputs']}
    pending = {group['id']: group for group in groups}
    completed, ordered = set(), []
    while pending:
        ready = [group for group in pending.values()
                 if all(owners[source] in completed for source in
                        fingerprint(tree, group['sources']) if source in owners)]
        if not ready:
            raise ValueError('Generated-document dependency cycle')
        for group in ready:
            ordered.append(group)
            completed.add(group['id'])
            del pending[group['id']]
    return ordered


def declarations(tree, manifest):
    edges, kinds = {}, {}
    if manifest.get('schema') != 1:
        raise ValueError('Unsupported document dependency schema')
    for group in manifest['generated']:
        dependencies = fingerprint(tree, group['sources'])
        for output in group['outputs']:
            if output in kinds:
                raise ValueError('Duplicate managed document: ' + output)
            kinds[output] = 'generated'
            edges[output] = set(dependencies)
    for review in manifest['maintained']:
        target = review['document']
        if target in kinds:
            raise ValueError('Duplicate managed document: ' + target)
        if target not in tree.paths:
            raise ValueError('Missing maintained document: ' + target)
        kinds[target] = 'maintained'
        edges[target] = set(fingerprint(tree, review['sources']))
    assert_acyclic(edges)
    return edges, kinds


class Links(HTMLParser):
    def __init__(self):
        super().__init__()
        self.links = []

    def handle_starttag(self, tag, attrs):
        for key, value in attrs:
            if key in {'href', 'src'} and value:
                self.links.append(value)


def references(path, text, root):
    links = re.findall(r'!?\[[^\]\n]*\]\((<[^>]+>|[^\s)]+)', text)
    links += re.findall(r'^\s*\[[^\]\n]+\]:\s*(<[^>]+>|\S+)', text, re.M)
    parser = Links()
    parser.feed(text)
    links += parser.links
    if path.endswith('.json'):
        def walk(value):
            if isinstance(value, dict):
                for child in value.values():
                    yield from walk(child)
            elif isinstance(value, list):
                for child in value:
                    yield from walk(child)
            elif isinstance(value, str) and re.match(r'^(docs|dev|patches|examples|tools|assets)/[^\s]+$', value):
                yield '/' + value
        links += list(walk(json.loads(text)))
    result = set()
    for link in links:
        try:
            url = urlsplit(html.unescape(link.strip('<>')))
        except ValueError:
            continue
        if url.scheme not in {'', 'file'} or url.netloc or not url.path:
            continue
        target = unquote(url.path)
        if url.scheme == 'file' or target.startswith(str(root) + '/'):
            try:
                target = str(Path(target).relative_to(root))
            except ValueError:
                continue
        elif target.startswith('/'):
            target = target.lstrip('/')
        else:
            target = posixpath.join(posixpath.dirname(path), target)
        target = posixpath.normpath(target)
        if not target.startswith('../') and target != path:
            result.add(target)
    return result


def inventory(tree, manifest):
    explicit, kinds = declarations(tree, manifest)
    excluded = manifest['discovery']['exclude']
    docs = sorted(p for p in tree.paths if
                  (p.endswith(('.md', '.rst')) or p.startswith('docs/') and p.endswith(('.html', '.json')))
                  and p not in {MANIFEST, INDEX}
                  and not any(fnmatch.fnmatch(p, pattern) for pattern in excluded))
    edges = {key: set(value) for key, value in explicit.items()}
    for path in docs:
        if kinds.get(path) != 'generated':
            edges.setdefault(path, set()).update(references(path, tree.read(path).decode(errors='replace'), tree.root))
        if path not in kinds:
            kinds[path] = 'dated record' if re.search(r'/(?:\d{4}-\d{2}-\d{2})(?:/|-)', path) else 'reference'
    return docs, edges, kinds


def reverse_edges(edges):
    reverse = defaultdict(set)
    for document, sources in edges.items():
        for source in sources:
            reverse[source].add(document)
    return reverse


def impacted(edges, sources):
    reverse = reverse_edges(edges)
    queue, found = deque(sources), {}
    seen = set(sources)
    while queue:
        source = queue.popleft()
        for document in sorted(reverse[source]):
            if document in seen:
                continue
            seen.add(document)
            found[document] = source
            queue.append(document)
    return found


def render_index(tree, manifest):
    docs, edges, kinds = inventory(tree, manifest)
    reverse = reverse_edges(edges)
    rows = [
        '# Document dependency inventory', '',
        'Generated by `python3 dev/docs-deps.py --write-index`. '
        'See [the workflow](howto-document-dependencies.md) and [explicit dependencies](document-dependencies.json).', '',
        f'{len(docs)} documents; {sum(len(v) for v in edges.values())} local reference/dependency edges. '
        'Links identify possible review impact; they do not prove that a document is current.', '',
        'Generated views have source/output hash checks. Maintained summaries have explicit review receipts. '
        'Other documents are inventoried without claiming a completed freshness audit. '
        'Dated records keep their historical evidence; review their current implications instead of rewriting the past.', '',
        'Raw defect evidence, transcripts, vendored trees, and editor history are excluded from prose discovery. '
        'They can still be dependency targets. Reference cycles are allowed; declared derivation cycles are rejected.', '',
        '| Document | Tracking | Local sources/references | Referenced by documents |',
        '|---|---|---:|---:|',
    ]
    for path in docs:
        target = posixpath.relpath(path, 'docs')
        rows.append(f'| [{path}](<{target}>) | {kinds[path]} | {len(edges.get(path, ()))} | {len(reverse[path])} |')
    rows += ['', '## Generated browser copies', '']
    for group in manifest['generated']:
        for mirror in group.get('local_copies', []):
            rows.append(f'- `{mirror}` — refreshed by `{group["id"]}`; not part of the staged Git snapshot.')
    return '\n'.join(rows) + '\n'


def check(tree, manifest):
    declarations(tree, manifest)
    problems = []
    for group in manifest['generated']:
        receipt = group.get('receipt', {})
        if receipt.get('sources') != fingerprint(tree, group['sources']):
            problems.append(group['id'] + ': source changed; regenerate')
        try:
            if receipt.get('outputs') != output_hashes(tree, group['outputs']):
                problems.append(group['id'] + ': generated output changed or is unrecorded')
        except (FileNotFoundError, subprocess.CalledProcessError):
            problems.append(group['id'] + ': generated output missing')
    for review in manifest['maintained']:
        receipt = review.get('receipt', {})
        if receipt.get('sources') != fingerprint(tree, review['sources']):
            problems.append(review['document'] + ': source status changed; review the summary')
        if not receipt.get('note') or not receipt.get('attribution'):
            problems.append(review['document'] + ': substantive review receipt missing')
    if INDEX not in tree.paths or tree.read(INDEX).decode() != render_index(tree, manifest):
        problems.append(INDEX + ': inventory changed; run --write-index')
    return problems


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--staged', action='store_true')
    parser.add_argument('--impact', nargs='+', metavar='PATH')
    parser.add_argument('--direct', action='store_true', help='Limit impact output to direct dependents')
    parser.add_argument('--refresh', action='store_true', help='Run registered generators and record their exact inputs/outputs')
    parser.add_argument('--write-index', action='store_true')
    parser.add_argument('--review', nargs='+', metavar='DOCUMENT')
    parser.add_argument('--note')
    parser.add_argument('--attribution')
    args = parser.parse_args()
    if args.staged and (args.refresh or args.review):
        parser.error('--staged cannot refresh outputs or acknowledge reviews')
    root = Path(subprocess.check_output(['git', 'rev-parse', '--show-toplevel'], text=True).strip())
    tree = Tree(root, args.staged)
    manifest = json.loads(tree.read(MANIFEST))
    if args.staged and args.write_index:
        (root / INDEX).write_text(render_index(tree, manifest))
        print(INDEX + ': generated from staged sources; stage it before running --staged')
        return 0
    if args.impact:
        _, edges, kinds = inventory(tree, manifest)
        for document, via in impacted(edges, args.impact).items():
            if args.direct and via not in args.impact:
                continue
            print(f'{kinds.get(document, "reference")}: {document} (via {via})')
        return 0
    if args.review:
        if not args.note or not args.attribution:
            parser.error('--review requires a substantive --note and verified --attribution')
        known = {entry['document']: entry for entry in manifest['maintained']}
        if set(args.review) - known.keys():
            parser.error('Unknown maintained document')
        for document in args.review:
            known[document]['receipt'] = {
                'sources': fingerprint(tree, known[document]['sources']),
                'reviewed_at': datetime.now(timezone.utc).isoformat(),
                'note': args.note, 'attribution': args.attribution,
            }
    if args.refresh:
        declarations(tree, manifest)
        for group in generation_order(tree, manifest['generated']):
            before = fingerprint(Tree(root), group['sources'])
            subprocess.run(group['command'], cwd=root, check=True)
            after = Tree(root)
            if before != fingerprint(after, group['sources']):
                raise ValueError('Source changed during generation: ' + group['id'])
            group['receipt'] = {'sources': before, 'outputs': output_hashes(after, group['outputs'])}
    if args.refresh or args.review:
        (root / MANIFEST).write_text(json.dumps(manifest, indent=2) + '\n')
    if args.write_index or args.refresh or args.review:
        tree = Tree(root)
        (root / INDEX).write_text(render_index(tree, manifest))
    tree = Tree(root, args.staged)
    problems = check(tree, manifest)
    for problem in problems:
        print(problem, file=sys.stderr)
    if problems:
        return 1
    print('Document dependencies: PASS (' + ('index' if args.staged else 'worktree') + ')')
    return 0


if __name__ == '__main__':
    try:
        raise SystemExit(main())
    except (ValueError, KeyError, FileNotFoundError) as error:
        raise SystemExit('Document dependencies: ' + str(error))
