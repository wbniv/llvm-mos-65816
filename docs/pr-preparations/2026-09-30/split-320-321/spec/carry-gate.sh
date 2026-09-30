#!/usr/bin/env bash
# Build the split worktree's checkout and run the MOS CodeGen/MC suites.
#
# usage: carry-gate.sh LABEL [build|lit|both]
#   LABEL  evidence subdirectory (build/split-320-321/evidence/LABEL)
# The ninja build (-j3) runs under flock on build/.heavy-build.lock so heavy
# builds serialize across agents; lit runs outside the lock with ulimit -c 0,
# ulimit -v 2000000 and a timeout. After a build the llc is frozen as a hard
# link at build/split-320-321/llc/LABEL and its sha256 recorded.
set -euo pipefail
case "${1:-}" in -h|--help|"") sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'; exit 0;; esac
LABEL=$1; WHAT=${2:-both}
ROOT=/home/will/llvm-mos-65816
SPLIT=$ROOT/build/split-320-321
EV=$SPLIT/evidence/$LABEL
mkdir -p "$EV"
cd "$ROOT"
ts() { date -u +%Y-%m-%dT%H:%M:%SZ; }
MOUNTS=(-v "$SPLIT/source":/work/build/register-exhaustion-src -v "$SPLIT/build":/work/build/0029-cross-target-build)
if [ "$WHAT" != lit ]; then
  git -C "$SPLIT/source" rev-parse HEAD > "$EV/commit"
  git -C "$SPLIT/source" status --porcelain > "$EV/dirty.txt"
  echo "$(ts) free: $(free -g | awk '/Mem:/{print $7}') GB available; waiting for lock" | tee "$EV/build.log"
  set +e
  flock -w 14400 "$ROOT/build/.heavy-build.lock" \
    dev/container.sh "${MOUNTS[@]}" -- \
    sh -c 'ulimit -c 0; exec ninja -C /work/build/0029-cross-target-build -j3 llc opt llvm-mc llvm-objdump llvm-readobj llvm-readelf llvm-dwarfdump FileCheck not count split-file llvm-size llvm-as llvm-dis' \
    >> "$EV/build.log" 2>&1 </dev/null
  rc=$?
  set -e
  echo "$(ts) build rc=$rc commit $(cat "$EV/commit")" | tee -a "$EV/build.log"
  [ $rc -eq 0 ] || exit $rc
  grep -E 'warning:' "$EV/build.log" | grep -E 'Target/MOS' | sort -u > "$EV/mos-warnings.txt" || true
  sha256sum "$SPLIT/build/bin/llc" | awk '{print $1}' > "$EV/llc.sha256"
  rm -f "$SPLIT/llc/$LABEL"; ln "$SPLIT/build/bin/llc" "$SPLIT/llc/$LABEL"
  echo "llc $(cat "$EV/llc.sha256") warnings $(wc -l < "$EV/mos-warnings.txt")"
fi
if [ "$WHAT" != build ]; then
  set +e
  dev/container.sh "${MOUNTS[@]}" -v "$EV":/work/ev -- \
    sh -c 'ulimit -c 0; ulimit -v 2000000; exec timeout 3000 /work/build/0029-cross-target-build/bin/llvm-lit -j4 -v -o /work/ev/lit.json /work/build/register-exhaustion-src/llvm/test/CodeGen/MOS /work/build/register-exhaustion-src/llvm/test/MC/MOS' \
    > "$EV/lit.log" 2>&1 </dev/null
  lrc=$?
  set -e
  echo "$(ts) lit rc=$lrc" >> "$EV/build.log"
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
  exit $lrc
fi
