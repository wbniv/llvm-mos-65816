#!/usr/bin/env python3
"""Render the carry-scheduling plan beside its Markdown source."""

import hashlib
import html
from pathlib import Path
import re

from markdown_it import MarkdownIt


root = Path(__file__).resolve().parents[1]
source = root / 'docs/plans/2026-09-26-mos-carry-scheduling.md'
output = source.with_suffix('.html')
parser = MarkdownIt('commonmark').enable('table')
tokens = parser.parse(source.read_text())
for index, token in enumerate(tokens):
    if token.type == 'heading_open':
        title = tokens[index + 1].content
        token.attrSet('id', re.sub(r'[^\w -]', '', title.lower()).replace(' ', '-'))
body = parser.renderer.render(tokens, parser.options, {})
digest = hashlib.sha256(source.read_bytes()).hexdigest()
output.write_text('''<!doctype html>
<html lang="en"><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>MOS carry scheduling — implementation and results</title>
<style>
body{font:17px/1.65 system-ui,sans-serif;color:#202938;background:#fafbfc;
max-width:1120px;margin:40px auto;padding:0 24px 80px}
h1,h2,h3{line-height:1.25;scroll-margin-top:20px}h2{margin-top:2.5em}
a{color:#175eb5}nav{display:flex;flex-wrap:wrap;gap:20px;margin-bottom:28px}
table{display:block;overflow-x:auto;border-collapse:collapse;margin:24px 0;
font-size:15px;background:white}th,td{border:1px solid #cdd5df;padding:10px 14px;
vertical-align:top}th{background:#edf2f7;text-align:left}
code{font-size:.9em;background:#eef1f5;padding:2px 4px;border-radius:3px}
pre{overflow:auto;background:#eef1f5;padding:16px}pre code{padding:0}
li{margin:8px 0}blockquote{border-left:3px solid #9db4cd;margin-left:0;padding-left:20px}
@media print{body{font-size:11pt;max-width:none}nav{display:none}table{font-size:9pt}}
</style>
<nav><a href="#7-implementation-and-measured-outcome">Implementation and results</a>
<a href="#8-completed-validation-and-packaging">Validation</a>
<a href="#9-remaining-work">Remaining work</a>
<a href="''' + html.escape(source.name, quote=True) + '''">Markdown source</a></nav>
<main>''' + body + '</main>\n<!-- Source SHA-256: ' + digest + ' -->\n</html>\n')
print(output)
