#!/usr/bin/env python3
"""Emit the cumulative patch for one stage of a split commit series.

usage: stage.py DIFF SPEC STAGE > stage.patch
       stage.py DIFF SPEC --check      # every +/- line has a tag; list tags

DIFF is a unified diff (base -> monolithic end state). SPEC assigns each
changed line of DIFF to the stage (commit number) that introduces it:

  file PATH TAG            default tag for every +/- line of that file
  range FIRST LAST TAG     +/- lines FIRST..LAST (DIFF line numbers) -> TAG
  interim AFTER FROM TO    the following indented block ("| text" lines) is
  | text                   added after DIFF line AFTER for stages FROM <= k < TO

Later spec lines override earlier ones. For stage k, a '+' line whose tag is
<= k is kept, a '-' line whose tag is <= k is kept, a '-' line whose tag is
> k becomes context, and a '+' line whose tag is > k is dropped. Interim
lines let an intermediate stage carry a line the end state does not have
(for example a condition that later gains a clause). Stage "max" equals the
monolithic end state by construction.
"""
import re
import sys


def parse_spec(path):
    files, ranges, interims = {}, [], []
    lines = open(path).read().split('\n')
    i = 0
    while i < len(lines):
        raw = lines[i]
        s = raw.strip()
        i += 1
        if not s or s.startswith('#'):
            continue
        f = s.split()
        if f[0] == 'file':
            files[f[1]] = int(f[2])
        elif f[0] == 'range':
            ranges.append((int(f[1]), int(f[2]), int(f[3])))
        elif f[0] == 'interim':
            after, lo, hi = int(f[1]), int(f[2]), int(f[3])
            block = []
            while i < len(lines) and lines[i].startswith('|'):
                t = lines[i][1:]
                block.append(t[1:] if t.startswith(' ') else t)
                i += 1
            interims.append((after, lo, hi, block))
        else:
            sys.exit(f'bad spec line: {raw}')
    return files, ranges, interims


def main():
    diff_path, spec_path, stage_arg = sys.argv[1:4]
    files, ranges, interims = parse_spec(spec_path)
    diff = open(diff_path).read().split('\n')
    if diff and diff[-1] == '':
        diff.pop()

    # Tag every +/- line.
    tags = {}
    cur_file = None
    in_hunk = False
    for n, line in enumerate(diff, 1):
        if line.startswith('diff --git'):
            cur_file = line.split(' b/', 1)[1]
            in_hunk = False
            continue
        if line.startswith('@@'):
            in_hunk = True
            continue
        if not in_hunk:
            continue
        if line[:1] in '+-':
            tags[n] = files.get(cur_file)
    for lo, hi, t in ranges:
        for n in range(lo, hi + 1):
            if n in tags:
                tags[n] = t
    missing = [n for n, t in tags.items() if t is None]
    if missing:
        sys.exit(f'untagged diff lines: {missing[:20]}')

    inter_after = {}
    for after, lo, hi, block in interims:
        inter_after.setdefault(after, []).append((lo, hi, block))

    if stage_arg == '--check':
        used = sorted(set(tags.values()))
        print('tags:', used)
        for t in used:
            nplus = sum(1 for n, v in tags.items() if v == t and diff[n-1][0] == '+')
            nminus = sum(1 for n, v in tags.items() if v == t and diff[n-1][0] == '-')
            print(f'  {t:3d}: +{nplus} -{nminus}')
        return
    k = 10**9 if stage_arg == 'max' else int(stage_arg)

    out = []
    header = []           # file header lines being buffered
    file_hunks = []       # list of (old_start, body_lines)
    is_new = False

    def flush_file():
        if not header:
            return
        kept = [(os_, b) for os_, b in file_hunks
                if any(l[:1] in '+-' for l in b)]
        if not kept:
            return
        out.extend(header)
        delta = 0
        for old_start, body in kept:
            old_n = sum(1 for l in body if l[:1] in ' -')
            new_n = sum(1 for l in body if l[:1] in ' +')
            if is_new:
                out.append(f'@@ -0,0 +1,{new_n} @@')
            else:
                new_start = old_start + delta
                if old_n == 0:
                    ostart = old_start
                else:
                    ostart = old_start
                out.append(f'@@ -{ostart},{old_n} +{new_start},{new_n} @@')
            out.extend(body)
            delta += new_n - old_n

    hunk_re = re.compile(r'^@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@')
    cur_body = None
    for n, line in enumerate(diff, 1):
        if line.startswith('diff --git'):
            if cur_body is not None:
                file_hunks.append(cur_body)
                cur_body = None
            flush_file()
            header, file_hunks, is_new = [line], [], False
            continue
        if cur_body is None and not line.startswith('@@'):
            header.append(line)
            if line.startswith('new file mode') or line == '--- /dev/null':
                is_new = True
            continue
        if line.startswith('@@'):
            if cur_body is not None:
                file_hunks.append(cur_body)
            m = hunk_re.match(line)
            cur_body = (int(m.group(1)), [])
            # interim lines may be anchored on the hunk header itself
            for lo, hi, block in inter_after.get(n, []):
                if lo <= k < hi:
                    cur_body[1].extend('+' + t for t in block)
            continue
        body = cur_body[1]
        c = line[:1]
        if c == ' ' or line == '':
            body.append(line if line else ' ')
        elif c == '\\':
            if body and body[-1][:1] in ' +-':
                body.append(line)
        elif c == '+':
            if tags[n] <= k:
                body.append(line)
        elif c == '-':
            body.append(line if tags[n] <= k else ' ' + line[1:])
        for lo, hi, block in inter_after.get(n, []):
            if lo <= k < hi:
                body.extend('+' + t for t in block)
    if cur_body is not None:
        file_hunks.append(cur_body)
    flush_file()
    sys.stdout.write('\n'.join(out) + '\n')


if __name__ == '__main__':
    main()
