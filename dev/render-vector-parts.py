#!/usr/bin/env python3
"""Render the SelectionDAG vector report with collapsed session and compiler transcripts."""

from html import escape
from pathlib import Path
import re

from markdown_it import MarkdownIt


def markdown(text):
    parser = MarkdownIt('commonmark').enable('table')
    tokens = parser.parse(text)
    for index, token in enumerate(tokens):
        if token.type == 'heading_open':
            title = tokens[index + 1].content
            token.attrSet('id', re.sub(r'[^\w -]', '', title.lower()).replace(' ', '-'))
    return parser.renderer.render(tokens, parser.options, {})


root = Path(__file__).resolve().parents[1]
source = root / 'docs/investigations/2026-09-25-selectiondag-vector-parts.md'
transcript = root / 'docs/transcripts/2026-09-25-selectiondag-vector-parts.md'
evidence = root / 'docs/defects/evidence/2026-09-25-aarch64-vector-asm'
logs = '\n'.join((evidence / name).read_text() for name in
                 ['baseline-runner.log', 'candidate-runner.log'])
page = '''<!doctype html>
<html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>SelectionDAG vector parts — patch 0059</title>
<style>
:root{color-scheme:light dark;font-family:system-ui,sans-serif;line-height:1.6}
body{max-width:1040px;margin:32px auto;padding:0 24px;background:#f8fafc;color:#202938}
nav{font-size:.9rem;margin-bottom:24px}a{color:#1754b8}h1{line-height:1.2}
h2{margin-top:2em}code{background:#e8edf5;padding:2px 5px;border-radius:4px}
table{border-collapse:collapse;width:100%}th,td{border:1px solid #cdd7e5;padding:9px 12px;text-align:left}
details{margin:24px 0;padding:16px 20px;border:1px solid #cdd7e5;border-radius:8px;background:#fff}
summary{cursor:pointer;font-weight:650}pre{white-space:pre-wrap;overflow-wrap:anywhere;font-size:.85rem}
@media(prefers-color-scheme:dark){body{background:#111722;color:#e1e8f2}a{color:#92bdff}
code{background:#263347}details{background:#172130}th,td,details{border-color:#34445a}}
</style></head><body>
<nav><a href="../mos-upstream-status-2026-09-21.html">Upstream status</a> ·
<a href="../mos-upstream-flowchart.html">Dependency flowchart</a> ·
<a href="#transcript">Work-session transcript</a></nav>
'''
page += markdown(source.read_text())
page += '<details id="transcript"><summary>Work-session transcript</summary>\n'
page += markdown(transcript.read_text()) + '</details>\n'
page += '<details><summary>Compiler diagnostic transcript — baseline and candidate</summary><pre>'
page += escape(logs) + '</pre></details>\n</body></html>\n'
output = source.with_suffix('.html')
output.write_text(page)
print(output)
