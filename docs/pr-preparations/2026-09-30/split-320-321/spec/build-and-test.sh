#!/usr/bin/env bash
# Build the split worktree's current checkout in the dev container and run
# the MOS CodeGen/MC lit suites. Logs land in evidence/<label>/.
#
# usage: [PROBE_DIR=dir] build-and-test.sh LABEL
#   LABEL      evidence subdirectory name (e.g. 321-05)
#   PROBE_DIR  optional directory of test files to try against this build
set -euo pipefail
case "${1:-}" in -h|--help|"") sed -n '2,8p' "$0" | sed 's/^# \{0,1\}//'; exit 0;; esac
LABEL=$1; shift
ROOT=/home/will/llvm-mos-65816
SPLIT=$ROOT/build/split-320-321
EV=$SPLIT/evidence/$LABEL
mkdir -p "$EV"
cd "$ROOT"
ts() { date -u +%Y-%m-%dT%H:%M:%SZ; }
git -C "$SPLIT/source" rev-parse HEAD > "$EV/commit"
echo "$(ts) build start $(cat "$EV/commit")" | tee "$EV/build.log"
set +e
dev/container.sh -v "$SPLIT/source":/work/build/register-exhaustion-src \
  -v "$SPLIT/build":/work/build/0029-cross-target-build -- \
  sh -c 'ulimit -c 0; exec ninja -C /work/build/0029-cross-target-build -j3 llc opt llvm-mc llvm-objdump llvm-readobj llvm-readelf FileCheck not count split-file llvm-size llvm-as llvm-dis' \
  >> "$EV/build.log" 2>&1
rc=$?
set -e
echo "$(ts) build rc=$rc" | tee -a "$EV/build.log"
[ $rc -eq 0 ] || exit $rc
grep -E 'warning:' "$EV/build.log" | grep -E 'Target/MOS' | sort -u > "$EV/mos-warnings.txt" || true
sha256sum "$SPLIT/build/bin/llc" | awk '{print $1}' > "$EV/llc.sha256"
set +e
dev/container.sh -v "$SPLIT/source":/work/build/register-exhaustion-src \
  -v "$SPLIT/build":/work/build/0029-cross-target-build -v "$EV":/work/ev -- \
  sh -c 'ulimit -c 0; ulimit -v 2000000; exec timeout 3000 /work/build/0029-cross-target-build/bin/llvm-lit -v -o /work/ev/lit.json /work/build/register-exhaustion-src/llvm/test/CodeGen/MOS /work/build/register-exhaustion-src/llvm/test/MC/MOS' \
  > "$EV/lit.log" 2>&1
lrc=$?
set -e
echo "$(ts) lit rc=$lrc" | tee -a "$EV/build.log"
python3 - "$EV/lit.json" > "$EV/lit-summary.txt" <<'EOF'
import json, sys, collections
d = json.load(open(sys.argv[1]))
c = collections.Counter(t['code'] for t in d['tests'])
print(' '.join(f'{k}={v}' for k, v in sorted(c.items())))
for t in d['tests']:
    if t['code'] not in ('PASS', 'UNSUPPORTED', 'XFAIL'):
        print(t['code'], t['name'])
EOF
cat "$EV/lit-summary.txt"
# Probe: run later-stage test files against this build (copied into a
# temporary subdirectory of the MOS test suite, then removed).
if [ -n "${PROBE_DIR:-}" ] && [ -d "$PROBE_DIR" ]; then
  # CodeGen tests go under CodeGen/MOS, assembler tests (*.s) under MC/MOS.
  P="$SPLIT/source/llvm/test/CodeGen/MOS/zz-probe"; PM="$SPLIT/source/llvm/test/MC/MOS/zz-probe"
  rm -rf "$P" "$PM"; mkdir -p "$P" "$PM"
  for f in "$PROBE_DIR"/*; do case "$f" in *.s) cp "$f" "$PM"/;; *) cp "$f" "$P"/;; esac; done
  set +e
  dev/container.sh -v "$SPLIT/source":/work/build/register-exhaustion-src \
    -v "$SPLIT/build":/work/build/0029-cross-target-build -- \
    sh -c 'ulimit -c 0; ulimit -v 2000000; exec timeout 3000 /work/build/0029-cross-target-build/bin/llvm-lit -v /work/build/register-exhaustion-src/llvm/test/CodeGen/MOS/zz-probe /work/build/register-exhaustion-src/llvm/test/MC/MOS/zz-probe' \
    > "$EV/probe-lit.log" 2>&1
  set -e
  rm -rf "$P" "$PM"
  grep -E '^(PASS|FAIL|UNSUPPORTED|XFAIL|UNRESOLVED): ' "$EV/probe-lit.log" > "$EV/probe-summary.txt" || true
  cat "$EV/probe-summary.txt"
fi
exit $lrc
