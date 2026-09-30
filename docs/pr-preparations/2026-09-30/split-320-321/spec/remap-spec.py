#!/usr/bin/env python3
"""Carry a stage spec over to a regenerated diff.

usage: remap-spec.py OLD_DIFF NEW_DIFF OLD_SPEC NEW_SPEC [FILE=TAG ...]

stage.py specs name DIFF line numbers. When the monolithic diff is
regenerated (here: with the native-width pressure-set change), every line
number after the first edit moves. This aligns OLD_DIFF with NEW_DIFF
(difflib, no autojunk), rewrites the numbers of every `range` and `interim`
line of OLD_SPEC, and writes NEW_SPEC.

Changed lines that exist only in NEW_DIFF get the tag given for their file on
the command line (FILE=TAG); a file without one keeps its `file` default and
is reported. The new ranges are appended after the carried-over spec, so they
override it.

Checks (exit 1 on failure): every +/- line of OLD_DIFF maps to NEW_DIFF with
the same tag, and every +/- line of NEW_DIFF has a tag.
"""
import difflib
import importlib.util
import os
import re
import sys


def load_stage():
    here = os.path.dirname(os.path.abspath(__file__))
    spec = importlib.util.spec_from_file_location('stage', os.path.join(here, 'stage.py'))
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def read(path):
    lines = open(path).read().split('\n')
    if lines and lines[-1] == '':
        lines.pop()
    return lines


def tags_of(diff, files, ranges):
    """Tag of every +/- line (1-based), and the file each changed line is in."""
    tags, where = {}, {}
    cur, in_hunk = None, False
    for n, line in enumerate(diff, 1):
        if line.startswith('diff --git'):
            cur, in_hunk = line.split(' b/', 1)[1], False
            continue
        if line.startswith('@@'):
            in_hunk = True
            continue
        if in_hunk and line[:1] in '+-':
            tags[n] = files.get(cur)
            where[n] = cur
    for lo, hi, t in ranges:
        for n in range(lo, hi + 1):
            if n in tags:
                tags[n] = t
    return tags, where


def main():
    old_diff, new_diff, old_spec, new_spec = sys.argv[1:5]
    extra = dict(a.split('=', 1) for a in sys.argv[5:])
    stage = load_stage()
    old, new = read(old_diff), read(new_diff)
    fwd = {}
    sm = difflib.SequenceMatcher(None, old, new, autojunk=False)
    for tag, i1, i2, j1, j2 in sm.get_opcodes():
        if tag == 'equal':
            for k in range(i2 - i1):
                fwd[i1 + k + 1] = j1 + k + 1

    def m(n):
        if n not in fwd:
            sys.exit(f'old diff line {n} has no counterpart in the new diff: {old[n-1]!r}')
        return fwd[n]

    def m_edge(lo, hi, step):
        # A range may start or end on a hunk header, which moves; use the
        # nearest line inside the range that has a counterpart.
        n = lo if step > 0 else hi
        while lo <= n <= hi:
            if n in fwd:
                return fwd[n]
            n += step
        sys.exit(f'range {lo} {hi} has no line with a counterpart')

    out = []
    for raw in open(old_spec).read().split('\n'):
        f = raw.split()
        if f and f[0] == 'range':
            lo, hi = int(f[1]), int(f[2])
            out.append(f'range {m_edge(lo, hi, 1)} {m_edge(lo, hi, -1)} {f[3]}')
        elif f and f[0] == 'interim':
            out.append(f'interim {m(int(f[1]))} {f[2]} {f[3]}')
        else:
            out.append(raw)
    while out and out[-1] == '':
        out.pop()

    files, ranges, _ = stage.parse_spec(old_spec)
    otags, _ = tags_of(old, files, ranges)
    # New-only changed lines, grouped into runs per file.
    mapped = set(fwd.values())
    files_n = dict(files)
    probe = [l for l in out]
    tmp = new_spec + '.tmp'
    open(tmp, 'w').write('\n'.join(probe) + '\n')
    files_n, ranges_n, _ = stage.parse_spec(tmp)
    for path, t in extra.items():
        if path not in files_n:
            files_n[path] = int(t)
            out.append(f'file {path} {t}')
    ntags, nwhere = tags_of(new, files_n, ranges_n)
    added = sorted(n for n in ntags if n not in mapped)
    runs, unassigned = [], []
    for n in added:
        path = nwhere[n]
        if path not in extra:
            unassigned.append((n, path))
            continue
        t = int(extra[path])
        if runs and runs[-1][1] == n - 1 and runs[-1][2] == t:
            runs[-1][1] = n
        else:
            runs.append([n, n, t])
    if runs:
        out.append('')
        out.append('# Native-width pressure sets: lines only in the regenerated diff.')
        for lo, hi, t in runs:
            out.append(f'range {lo} {hi} {t}')
    open(tmp, 'w').write('\n'.join(out) + '\n')
    files_n, ranges_n, _ = stage.parse_spec(tmp)
    ntags, _ = tags_of(new, files_n, ranges_n)
    os.replace(tmp, new_spec)

    bad = 0
    # A changed line the alignment could not pair (it moved within its hunk)
    # is accepted when the same text is a new-only line with the same tag.
    moved = {(new[k - 1], ntags.get(k)) for k in added}
    for n, t in otags.items():
        if n not in fwd and (old[n - 1], t) in moved:
            print(f'moved: old {n} ({t}) {old[n-1]!r}')
            continue
        if ntags.get(fwd.get(n)) != t:
            print(f'TAG CHANGED: old {n} ({t}) -> new {fwd.get(n)} ({ntags.get(fwd.get(n))}): {old[n-1]!r}')
            bad = 1
    for n, t in ntags.items():
        if t is None:
            print(f'UNTAGGED new line {n}: {new[n-1]!r}')
            bad = 1
    for n, path in unassigned:
        print(f'new-only line {n} in {path} keeps its file default {ntags.get(n)}')
    print(f'{len(otags)} old changed lines carried; {len(added)} new-only changed lines '
          f'({len(runs)} ranges); result {"OK" if not bad else "FAILED"}')
    sys.exit(bad)


if __name__ == '__main__':
    main()
