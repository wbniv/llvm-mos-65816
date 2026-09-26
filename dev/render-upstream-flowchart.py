#!/usr/bin/env python3
"""Render the tracker’s Mermaid diagram as a zoomable HTML page."""

import argparse
import hashlib
import html
import os
from pathlib import Path
import re


def render(root, output):
    source = root / 'docs/upstream-pending-work.md'
    status = root / 'docs/upstream-contribution-status.md'
    text = source.read_text(encoding='utf-8')
    section = text.split('\n## Flowchart\n', 1)[1].split('\n## ', 1)[0]
    diagrams = re.findall(r'```mermaid\n(.*?)\n```', section, re.S)
    if len(diagrams) != 1:
        raise ValueError('The Flowchart section must contain one Mermaid block')
    local_date = re.search(r'Local preparation updated (\d{4}-\d{2}-\d{2})', text)
    remote_date = re.search(
        r'GitHub status last verified:\*\* (\d{4}-\d{2}-\d{2})',
        status.read_text(encoding='utf-8'))
    if not local_date or not remote_date:
        raise ValueError('Both trackers must record their snapshot dates')
    values = {
        'DIAGRAM': diagrams[0],
        'SOURCE_SHA': hashlib.sha256(source.read_bytes()).hexdigest(),
        'SOURCE_LINK': os.path.relpath(source, output.parent),
        'STATUS_LINK': ('llvm-' if output.name.startswith('llvm-') else '')
        + 'mos-upstream-status-2026-09-21.html',
        'LOCAL_DATE': local_date[1],
        'REMOTE_DATE': remote_date[1],
    }
    page = (root / 'dev/templates/upstream-flowchart.html').read_text(encoding='utf-8')
    for key, value in values.items():
        marker = '@@' + key + '@@'
        if page.count(marker) != 1:
            raise ValueError('Template must contain exactly one ' + marker)
        page = page.replace(marker, html.escape(value, quote=True))
    return page


def main():
    root = Path(__file__).resolve().parents[1]
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, default=root / 'docs/mos-upstream-flowchart.html')
    parser.add_argument('--check', action='store_true', help='Fail if the HTML needs regeneration')
    args = parser.parse_args()
    output = args.output.resolve()
    expected = render(root, output)
    if args.check:
        if not output.exists() or output.read_text(encoding='utf-8') != expected:
            parser.exit(1, str(output) + ': stale; run dev/render-upstream-flowchart.py\n')
        print(str(output) + ': current')
    else:
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_text(expected, encoding='utf-8')
        print(str(output))


if __name__ == '__main__':
    main()
