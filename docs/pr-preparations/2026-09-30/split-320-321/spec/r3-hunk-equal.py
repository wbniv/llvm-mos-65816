#!/usr/bin/env python3
"""Check that a replayed commit makes the same change as the original (tokens).

usage: r3-hunk-equal.py REPO OLD_PARENT OLD NEW_PARENT NEW|WORKTREE -- PATH...
For each path, tokenizes the four versions (words, string literals and single
punctuation; whitespace and line breaks ignored), computes the token-level edit
of OLD_PARENT->OLD and of NEW_PARENT->NEW, and compares the lists of
(deleted tokens, inserted tokens). Equal lists mean the replay is the same
change up to formatting, even when its context was reformatted. WORKTREE reads
NEW from the working tree.
"""
import difflib, pathlib, re, subprocess, sys

TOK = re.compile(r'\w+|"(?:\\.|[^"\\\n])*"|\S')

def text(repo, rev, path):
    if rev == "WORKTREE":
        p = pathlib.Path(repo) / path
        return p.read_text() if p.exists() else ""
    r = subprocess.run(["git", "-C", repo, "show", f"{rev}:{path}"], capture_output=True, text=True)
    return r.stdout if r.returncode == 0 else ""

def edits(a, b):
    ta, tb = TOK.findall(a), TOK.findall(b)
    sm = difflib.SequenceMatcher(None, ta, tb, autojunk=False)
    return [(tuple(ta[i1:i2]), tuple(tb[j1:j2])) for op, i1, i2, j1, j2 in sm.get_opcodes() if op != "equal"]

if len(sys.argv) < 7 or "--" not in sys.argv:
    print(__doc__.strip()); sys.exit(0 if "-h" in sys.argv or "--help" in sys.argv else 2)
i = sys.argv.index("--")
repo, op, o, np_, n = sys.argv[1:i]
bad = 0
for p in sys.argv[i + 1:]:
    e1 = edits(text(repo, op, p), text(repo, o, p))
    e2 = edits(text(repo, np_, p), text(repo, n, p))
    ok = e1 == e2
    bad += not ok
    print(f"{'SAME' if ok else 'DIFF'}\t{p}\t{len(e1)} vs {len(e2)} edits")
    if not ok:
        for x, y in zip(e1, e2):
            if x != y:
                print("   old:", " ".join(x[0])[:200], "=>", " ".join(x[1])[:200]); print("   new:", " ".join(y[0])[:200], "=>", " ".join(y[1])[:200]); break
sys.exit(1 if bad else 0)
