#!/usr/bin/env python3
"""Export a packet's split-based patch series and write its round-trip record.

usage: packet-record.py NAME BASE HEAD ORIGINAL_CANDIDATE OUT_DIR
  NAME                packet label (evidence/pkt-NAME holds its build and suite)
  BASE                llvm-mos destination (06bc967d2668)
  HEAD                last commit of the packet on the split series
  ORIGINAL_CANDIDATE  the packet's previous candidate commit, for the tree delta
  OUT_DIR             packet directory; writes patches-split/ and
                      evidence/split-series.json
The round trip applies every exported patch to BASE in a temporary index and
checks each intermediate tree against the commit it came from.
"""
import hashlib, json, os, subprocess, sys, tempfile

REPO = '/home/will/llvm-mos-65816/build/split-320-321/source'
EV = '/home/will/llvm-mos-65816/build/split-320-321/evidence'


def git(*a, env=None, inp=None):
    return subprocess.run(['git', '-C', REPO, *a], check=True, capture_output=True,
                          text=True, env=env, input=inp).stdout.strip()


name, base, head, orig, out = sys.argv[1:6]
pdir = os.path.join(out, 'patches-split')
os.makedirs(pdir, exist_ok=True)
for f in os.listdir(pdir):
    os.remove(os.path.join(pdir, f))
files = git('format-patch', '-o', pdir, f'{base}..{head}').splitlines()
commits = git('rev-list', '--reverse', f'{base}..{head}').splitlines()
assert len(files) == len(commits)
env = dict(os.environ, GIT_INDEX_FILE=tempfile.mktemp())
git('read-tree', base, env=env)
steps = []
for f, c in zip(files, commits):
    git('apply', '--cached', f, env=env)
    t = git('write-tree', env=env)
    want = git('rev-parse', f'{c}^{{tree}}')
    steps.append({'patch': os.path.relpath(f, out), 'commit': c,
                  'subject': git('log', '-1', '--format=%s', c),
                  'tree': t, 'matches_commit_tree': t == want,
                  'sha256': hashlib.sha256(open(f, 'rb').read()).hexdigest()})
os.remove(env['GIT_INDEX_FILE'])
delta = git('diff', '--name-status', orig, head).splitlines()
lit = open(os.path.join(EV, f'pkt-{name}', 'lit-summary.txt')).readline().strip()
rec = {
    'destination': git('rev-parse', base),
    'head': git('rev-parse', head),
    'final_tree': git('rev-parse', f'{head}^{{tree}}'),
    'all_intermediate_trees_match': all(s['matches_commit_tree'] for s in steps),
    'original_candidate': git('rev-parse', orig),
    'tree_delta_vs_original_candidate': delta,
    'mos_suites': lit,
    'llc_sha256': open(os.path.join(EV, f'pkt-{name}', 'llc.sha256')).read().strip(),
    'series': steps,
}
os.makedirs(os.path.join(out, 'evidence'), exist_ok=True)
json.dump(rec, open(os.path.join(out, 'evidence', 'split-series.json'), 'w'), indent=1)
print(f'{name}: {len(steps)} patches, trees match: {rec["all_intermediate_trees_match"]}, '
      f'final {rec["final_tree"][:12]}, delta vs original: {len(delta)} paths, {lit}')
