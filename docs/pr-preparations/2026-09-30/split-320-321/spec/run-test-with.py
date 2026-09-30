#!/usr/bin/env python3
"""Run one lit test's RUN lines with a chosen llc binary (red/green probes).

usage: run-test-with.py LLC TEST [TOOLS_DIR]
  LLC        llc binary to substitute for `llc`
  TEST       .ll/.mir test file
  TOOLS_DIR  directory with FileCheck, not, split-file and the other LLVM tools
             (default: the split build's bin/)
Supports the substitutions these tests use: %s, %t, %S. Each RUN line runs
under `bash -o pipefail` with ulimit -c 0, ulimit -v 2000000 and a 120 s
timeout. Prints PASS or FAIL and the first diagnostic; exit 0 on PASS.
Run it inside the dev container (paths under /work).
"""
import os, re, shutil, subprocess, sys, tempfile

if len(sys.argv) < 3 or sys.argv[1] in ('-h', '--help'):
    print(__doc__.strip()); sys.exit(0)
llc, test = sys.argv[1], sys.argv[2]
tools = sys.argv[3] if len(sys.argv) > 3 else '/work/build/split-320-321/build/bin'
runs, cur = [], ''
for line in open(test):
    m = re.match(r'\s*;\s*RUN:\s?(.*)$', line) or re.match(r'\s*#\s*RUN:\s?(.*)$', line)
    if not m:
        continue
    part = m.group(1).rstrip()
    if part.endswith('\\'):
        cur += part[:-1] + ' '
        continue
    runs.append(cur + part); cur = ''
tmp = tempfile.mkdtemp()
t = os.path.join(tmp, 't')
status, first = 'PASS', ''
for i, cmd in enumerate(runs, 1):
    cmd = cmd.replace('%s', test).replace('%t', t).replace('%S', os.path.dirname(test))
    cmd = re.sub(r'(?<![\w/.-])llc(?![\w.-])', llc, cmd)
    for tool in ('FileCheck', 'not', 'split-file', 'count', 'opt', 'llvm-mc', 'llvm-objdump',
                 'llvm-readobj', 'llvm-readelf', 'llvm-dwarfdump', 'llvm-as', 'llvm-dis',
                 'llvm-size'):
        cmd = re.sub(r'(?<![\w/.-])%s(?![\w.-])' % re.escape(tool), os.path.join(tools, tool), cmd)
    try:
        p = subprocess.run(['bash', '-o', 'pipefail', '-c',
                            'ulimit -c 0; ulimit -v 2000000; ' + cmd],
                           capture_output=True, text=True, timeout=120)
    except subprocess.TimeoutExpired:
        status, first = 'FAIL', f'RUN {i}: timeout'
        break
    if p.returncode != 0:
        status = 'FAIL'
        out = p.stdout + p.stderr
        for pat in (r'Assertion `[^\n]*', r'LLVM ERROR:[^\n]*', r'Bad machine code:[^\n]*',
                    r'error: [^\n]*', r'[^\n]*unable to[^\n]*'):
            mm = re.search(pat, out)
            if mm:
                first = f'RUN {i}: ' + mm.group(0)[:200]; break
        else:
            first = f'RUN {i}: exit {p.returncode}'
        break
shutil.rmtree(tmp, ignore_errors=True)
print(status, first)
sys.exit(0 if status == 'PASS' else 1)
