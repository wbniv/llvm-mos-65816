#!/usr/bin/env python3
"""Check that two revisions differ only in comments and whitespace (N3/N4).

usage: r3-token-equal.py REPO OLD NEW
For every file that differs between OLD and NEW, strip // and /* */ comments
(outside string and character literals) and all whitespace, then compare.
TableGen files use the same comment syntax. Prints each file and SAME/DIFF;
exits 1 if any file differs in code.
"""
import subprocess, sys

def strip(src):
    out, i, n = [], 0, len(src)
    while i < n:
        c = src[i]
        if c in "\"'":
            j = i + 1
            while j < n and src[j] != c:
                j += 2 if src[j] == "\\" else 1
            out.append(src[i:j + 1]); i = j + 1
        elif src.startswith("//", i):
            j = src.find("\n", i); i = n if j < 0 else j
        elif src.startswith("/*", i):
            j = src.find("*/", i + 2); i = n if j < 0 else j + 2
        else:
            if not c.isspace():
                out.append(c)
            i += 1
    return "".join(out)

def main():
    if len(sys.argv) != 4:
        print(__doc__.strip()); sys.exit(0 if "-h" in sys.argv or "--help" in sys.argv else 2)
    repo, old, new = sys.argv[1:]
    files = subprocess.run(["git", "-C", repo, "diff", "--name-only", old, new],
                           check=True, capture_output=True, text=True).stdout.split()
    bad = 0
    for f in files:
        get = lambda r: subprocess.run(["git", "-C", repo, "show", f"{r}:{f}"],
                                       capture_output=True, text=True).stdout
        same = strip(get(old)) == strip(get(new))
        bad += not same
        print(f"{'SAME' if same else 'DIFF'}\t{f}")
    print(f"{len(files)} files, {bad} with code changes")
    sys.exit(1 if bad else 0)

main()
