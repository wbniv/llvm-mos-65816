#!/usr/bin/env python3
"""Render the review page and checksums from the adjacent source files.

Run with --check to verify generated artifacts without changing them.
"""

import argparse
import hashlib
import html
import json
from pathlib import Path
import re


ROOT = Path(__file__).resolve().parent


def read(name):
    return (ROOT / name).read_text()


def description(text):
    # PR bodies use paragraphs and inline code; escape all source HTML.
    return "\n".join(
        "<p>" + re.sub(r"`([^`]+)`", r"<code>\1</code>", html.escape(p)) + "</p>"
        for p in text.strip().split("\n\n")
    )


def diff(text):
    lines = []
    for line in text.splitlines():
        kind = "add" if line.startswith("+") else "del" if line.startswith("-") else "line"
        lines.append(f'<span class="{kind}">{html.escape(line)}</span>')
    return "<pre class=diff>" + "\n".join(lines) + "</pre>"


def render():
    heads = json.loads(read("heads.json"))
    parts = ['''<!doctype html>
<html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Upstream PR revisions — review</title>
<style>
body{font:16px/1.6 system-ui,sans-serif;max-width:1120px;margin:40px auto;padding:0 24px;background:#f6f8fa;color:#1f2328}
h1,h2,h3{line-height:1.3}a{color:#0969da}nav{display:flex;gap:20px;flex-wrap:wrap;margin:24px 0}
.notice{padding:16px 20px;background:#fff8c5;border:1px solid #d4a72c;border-radius:8px}
article,section{background:white;padding:24px;margin:24px 0;border:1px solid #d0d7de;border-radius:10px}
summary{cursor:pointer;font-weight:600;padding:12px 0}
pre{font:13px/1.6 ui-monospace,monospace;overflow:auto;background:#f6f8fa;padding:16px;border-radius:6px}
code{font-family:ui-monospace,monospace;overflow-wrap:anywhere}pre.record{white-space:pre-wrap;overflow-wrap:anywhere}
.add{background:#dafbe1}.del{background:#ffebe9}.diff span{display:inline-block;min-width:100%}
html{scroll-behavior:smooth}
</style></head><body><h1>Upstream PR revisions</h1>
<p>Generated from the current saved bundle. Source files: <a href="heads.json">heads</a>,
<a href="README.md">README</a>, <a href="review.md">review</a>.</p>
<div class="notice"><strong>Publication proceeds one PR at a time with Will’s approval.</strong>
Each PR’s publication status is shown below.</div>''']
    parts.append('<nav>' + ''.join(f'<a href="#pr{pr}">#{pr}</a>' for pr in heads)
                 + '<a href="#validation">Validation</a></nav>')
    for pr, entry in heads.items():
        parts.extend([
            f'<article id="pr{pr}"><h2>#{pr} — {html.escape(read(pr + "-title.txt").strip())}</h2>',
            f'<p><a href="{html.escape(entry["upstream_pr"], quote=True)}">Existing upstream PR</a></p>',
            f'<p>Status: {html.escape(entry["publication"])}</p>',
            f'<p>Proposed head: <code>{html.escape(entry["proposed_head"])}</code><br>',
            f'Submitted head: <code>{html.escape(entry["submitted_head"])}</code></p>',
            '<h3>Proposed description</h3>', description(read(pr + '-body.md')),
            f'<p><a href="{pr}-body.md">Description source</a> · <a href="{pr}-commits.patch">Commit patches</a></p>',
        ])
        for suffix, label in [('review-changes', 'Changes since the submitted PR'),
                              ('complete', 'Complete proposed diff')]:
            name = f'{pr}-{suffix}.patch'
            parts.extend([f'<details><summary>{label}</summary>',
                          f'<p><a href="{name}">Download diff</a></p>', diff(read(name)), '</details>'])
        parts.append('</article>')
    parts.extend(['<section id="validation"><h2>Validation record</h2>',
                  '<p><a href="validation.md">Validation source</a></p><pre class="record">',
                  html.escape(read('validation.md')), '</pre></section></body></html>\n'])
    return '\n'.join(parts).encode()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    page = render()
    sums = ''.join(
        hashlib.sha256(page if p.name == 'index.html' else p.read_bytes()).hexdigest()
        + '  ' + p.name + '\n'
        for p in sorted(ROOT.iterdir()) if p.is_file() and p.name != 'SHA256SUMS'
    ).encode()
    for name, data in [('index.html', page), ('SHA256SUMS', sums)]:
        if args.check:
            if (ROOT / name).read_bytes() != data:
                raise SystemExit(f'{name} is stale; run python3 {__file__}')
        else:
            (ROOT / name).write_bytes(data)
    print('Review page and checksums ' + ('verified.' if args.check else 'updated.'))


if __name__ == '__main__':
    main()
