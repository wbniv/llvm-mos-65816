#!/usr/bin/env python3
"""Build a docs/pr-preparations/*/NNNN-pr-preview.html page from a PR-draft markdown
file and its patch, using an existing preview as the style template.

usage: pr-preview.py --template T.html --md PR.md --patch P.patch --number NNNN \
                     --notice "text" --aside aside.html --out OUT.html
The markdown subset rendered: paragraphs, ``` fenced code, "- " bullet lists,
`inline code`, **bold**, and a leading "# " title (used as the <h1>).
"""
import argparse, hashlib, html, re
ap = argparse.ArgumentParser()
for a in ("template", "md", "patch", "number", "notice", "aside", "out"):
    ap.add_argument("--" + a, required=True)
args = ap.parse_args()

def inline(t):
    t = html.escape(t, quote=False)
    t = re.sub(r"`([^`]+)`", r"<code>\1</code>", t)
    t = re.sub(r"\*\*([^*]+)\*\*", r"<strong>\1</strong>", t)
    return t

def render_md(md):
    lines = md.splitlines(); out = []; i = 0; title = None
    while i < len(lines):
        l = lines[i]
        if l.startswith("# ") and title is None:
            title = l[2:].strip(); i += 1; continue
        if l.startswith("```"):
            j = i + 1; buf = []
            while j < len(lines) and not lines[j].startswith("```"): buf.append(lines[j]); j += 1
            out.append("<pre><code>" + html.escape("\n".join(buf), quote=False) + "</code></pre>"); i = j + 1; continue
        if l.startswith("- "):
            items = []
            while i < len(lines) and (lines[i].startswith("- ") or (lines[i].startswith("  ") and items)):
                if lines[i].startswith("- "): items.append(lines[i][2:])
                else: items[-1] += "\n" + lines[i].strip()
                i += 1
            out.append("<ul>" + "".join(f"<li>{inline(it)}</li>" for it in items) + "</ul>"); continue
        if not l.strip(): i += 1; continue
        buf = []
        while i < len(lines) and lines[i].strip() and not lines[i].startswith(("```", "- ", "# ")):
            buf.append(lines[i]); i += 1
        out.append("<p>" + inline("\n".join(buf)) + "</p>")
    return title, "\n".join(out)

def render_files(patch_text):
    files = re.split(r"^(?=diff --git )", patch_text, flags=re.M); out = []
    for f in files:
        if not f.startswith("diff --git "): continue
        m = re.match(r"diff --git a/(\S+) b/(\S+)", f); rows = []
        for line in f.splitlines()[1:]:
            cls = ""
            if line.startswith("+"): cls = "addition"
            elif line.startswith("-"): cls = "deletion"
            elif line.startswith("@@"): cls = "hunk"
            rows.append(f'<tr class="{cls}"><td class="code">{html.escape(line, quote=False)}</td></tr>')
        out.append(f'<details class="file" open><summary>{html.escape(m.group(2))}</summary><div class="scroll"><table class="diff">' + "".join(rows) + "</table></div></details>")
    return len(out), "".join(out)

md = open(args.md, encoding="utf-8").read(); patch = open(args.patch, "rb").read()
title, article = render_md(md); nfiles, files_html = render_files(patch.decode("utf-8"))
page = open(args.template, encoding="utf-8").read()
page = re.sub(r"<title>.*?</title>", f"<title>{html.escape(title)}</title>", page, count=1, flags=re.S)
page = re.sub(r"<h1>.*?</h1><p><span class=\"pill\">Local draft</span> Patch <code>\d+</code></p>",
              f'<h1>{html.escape(title)}</h1><p><span class="pill">Local draft</span> Patch <code>{args.number}</code></p>', page, count=1, flags=re.S)
page = re.sub(r'<div class="notice">.*?</div>', f'<div class="notice"><strong>Draft preview — not submitted.</strong> {html.escape(args.notice)}</div>', page, count=1, flags=re.S)
page = re.sub(r'Files changed \(\d+\)', f'Files changed ({nfiles})', page)
s = page.index('<div class="body">', page.index('id="description"')) + len('<div class="body">'); e = page.index("</div></article>", s)
page = page[:s] + article + page[e:]
s = page.index("<aside>"); e = page.index("</aside>", s) + len("</aside>")
page = page[:s] + "<aside>" + open(args.aside, encoding="utf-8").read().strip() + "</aside>" + page[e:]
s = page.index('<section id="files">'); e = page.index("</section>", s) + len("</section>")
page = page[:s] + '<section id="files"><h2>Files changed</h2>' + files_html + "</section>" + page[e:]
sha = hashlib.sha256(patch).hexdigest()
page = re.sub(r"(Patch SHA-256: <code>)[0-9a-f]{64}(</code>)", rf"\g<1>{sha}\g<2>", page)
open(args.out, "w", encoding="utf-8").write(page)
print(f"{args.out}: {nfiles} files, sha256 {sha[:12]}…")
