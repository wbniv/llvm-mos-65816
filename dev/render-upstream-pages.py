#!/usr/bin/env python3
"""Render the status overview and dependency chart from the repository trackers."""

import argparse
import hashlib
import html
import os
from pathlib import Path
import re
import runpy
from urllib.parse import urlsplit, urlunsplit

from markdown_it import MarkdownIt


def markdown(text, source, output, flowchart):
    parser = MarkdownIt('commonmark').enable('table')
    tokens = parser.parse(text)
    for index, token in enumerate(tokens):
        if token.type == 'heading_open':
            title = tokens[index + 1].content
            slug = re.sub(r'[^\w -]', '', title.lower()).replace(' ', '-')
            token.attrSet('id', slug)
        if token.type == 'fence' and token.info == 'mermaid':
            token.type = 'html_block'
            token.content = ('<p><a href="' + html.escape(flowchart.name) + '">'
                             'Open the zoomable dependency flowchart</a></p>\n')
        for child in token.children or []:
            if child.type != 'link_open':
                continue
            url = urlsplit(child.attrGet('href'))
            if url.scheme or url.netloc or not url.path:
                continue
            target = (source.parent / url.path).resolve()
            if target.name == 'mos-upstream-flowchart.html':
                path = flowchart.name
            elif target.name == 'mos-upstream-status-2026-09-21.html':
                path = output.name
            elif target == source.parent / 'upstream-pending-work.md':
                path = ''
                url = url._replace(fragment=url.fragment or 'work')
            elif target == source.parent / 'upstream-contribution-status.md':
                path = ''
                url = url._replace(fragment=url.fragment or 'status')
            else:
                path = os.path.relpath(target, output.parent)
            child.attrSet('href', urlunsplit(('', '', path, url.query, url.fragment)))
    return parser.renderer.render(tokens, parser.options, {})


def status_page(root, output, flowchart):
    work = root / 'docs/upstream-pending-work.md'
    status = root / 'docs/upstream-contribution-status.md'
    work_text, status_text = work.read_text(), status.read_text()
    values = {
        'LOCAL_DATE': re.search(r'Local preparation updated (\d{4}-\d{2}-\d{2})', work_text)[1],
        'REMOTE_DATE': re.search(r'GitHub status last verified:\*\* (\d{4}-\d{2}-\d{2})', status_text)[1],
        'SOURCE_SHA': hashlib.sha256(work.read_bytes() + b'\0' + status.read_bytes()).hexdigest(),
        'FLOWCHART_LINK': html.escape(flowchart.name, quote=True),
        'WORK': markdown(work_text, work, output, flowchart),
        'STATUS': markdown(status_text.split('\n## Historical updates\n', 1)[0], status, output, flowchart),
    }
    page = (root / 'dev/templates/upstream-status.html').read_text()
    for key, value in values.items():
        page = page.replace('@@' + key + '@@', value)
    return page


def main():
    root = Path(__file__).resolve().parents[1]
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--legacy-tmp', action='store_true', help='Also refresh the original browser filenames in /tmp')
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    render_chart = runpy.run_path(str(root / 'dev/render-upstream-flowchart.py'))['render']
    pairs = [(root / 'docs/mos-upstream-flowchart.html', root / 'docs/mos-upstream-status-2026-09-21.html')]
    if args.legacy_tmp:
        pairs.append((Path('/tmp/llvm-mos-upstream-flowchart.html'), Path('/tmp/llvm-mos-upstream-status-2026-09-21.html')))
    for chart, overview in pairs:
        for output, content in [(chart, render_chart(root, chart)), (overview, status_page(root, overview, chart))]:
            if args.check:
                if not output.exists() or output.read_text() != content:
                    parser.exit(1, str(output) + ': stale; regenerate upstream pages\n')
                print(str(output) + ': current')
            else:
                output.write_text(content)
                print(output)


if __name__ == '__main__':
    main()
