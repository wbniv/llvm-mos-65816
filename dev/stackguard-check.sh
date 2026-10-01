#!/usr/bin/env bash
# dev/stackguard-check.sh — regression check for the soft-stack overlap guard in build/jgxcheck.
#
# The guard (tools/stackguard.h, armed from dev/jgxcheck.cpp through the WRAM write watch in
# dev/bsnes-jg-wramwatch.patch) fails any bsnes-jg run whose C soft stack reaches below the end of
# static data. This proves it flags a known overlap and stays silent and byte-identical otherwise:
#
#   1. dither -O3 (the ROM + map committed with docs/defects/snes-soft-stack-static-data-collision.json):
#      main's 313 B frame leaves min SP $1EC7 against __heap_start $1FAE -> FAIL, 231 B overlap, rc 4.
#      Bounds come from the lld map (the evidence has no ELF), so this leg needs no toolchain.
#   2. dither -O2 from the same evidence (82 B of headroom): no overlap, rc 0.
#   3. with mos-clang present: a tiny synthetic overlap (a VLA larger than low WRAM; bounds from the
#      ELF) -> FAIL even though its result value matches; a tiny clean program -> the PASS line is
#      byte-identical with the guard on and off, and the ELF and map give identical bounds.
#   4. JGX_STACKGUARD=require on a ROM with no metadata -> rc 2 (a skipped check cannot pass silently).
#
# Prereqs: build/jgxcheck with the patched core (dev/run.sh xcheck builds both). Host or container.
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: dev/run.sh stackguard   (or: dev/stackguard-check.sh)
Proves build/jgxcheck flags a known soft-stack/static-data overlap (the dither -O3 ROM from
docs/defects/evidence/2026-10-01-snes-soft-stack-collision/) and does not disturb a clean run.
Exit 0 = all checks pass. Needs build/jgxcheck + vendor/bsnes-jg/Database (dev/run.sh xcheck).
A synthetic-ELF leg also runs when build/llvm-mos-install and build/install exist.
EOF
}
case "${1:-}" in -h|--help) usage; exit 0 ;; esac

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
JGX="${JGX:-$ROOT/build/jgxcheck}"
DB="$ROOT/vendor/bsnes-jg/Database"
EV="$ROOT/docs/defects/evidence/2026-10-01-snes-soft-stack-collision"
TOOL="${MOS_TOOLCHAIN:-$ROOT/build/llvm-mos-install}/bin"
CFG="$ROOT/build/install/bin/mos-snes.cfg"
FRAMES="${STACKGUARD_CHECK_FRAMES:-60}"   # the overlap is reached in main's prologue; no long run needed
WORK="$(mktemp -d "${TMPDIR:-/tmp}/stackguard-check.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

[ -x "$JGX" ] || { echo "FATAL: no $JGX (run: dev/run.sh xcheck)"; exit 1; }
[ -d "$DB" ] || { echo "FATAL: $DB missing (run: dev/run.sh xcheck)"; exit 1; }

ulimit -c 0
pass=0; fail=0
ok()  { echo "  PASS  $*"; pass=$((pass + 1)); }
bad() { echo "  FAIL  $*"; fail=$((fail + 1)); }
ts()  { date -u +%Y-%m-%dT%H:%M:%SZ; }
echo "$(ts) ==> stackguard regression check (jgxcheck sha256 $(sha256sum "$JGX" | cut -c1-16)…, frames=$FRAMES)"

# run_jg ROM OFFSET WANT [ENV=VAL...]: run jgxcheck, capture stdout/stderr/rc into $WORK/{out,err,rc}.
run_jg() {
  local rom=$1 off=$2 want=$3; shift 3
  local rc=0
  env "$@" timeout 300 "$JGX" "$rom" "$DB" "$off" 2 "$want" "$FRAMES" >"$WORK/out" 2>"$WORK/err" || rc=$?
  echo "$rc" >"$WORK/rc"
}
rc() { cat "$WORK/rc"; }
sym_addr() { # sym_addr MAPFILE SYMBOL -> hex VMA of a map line ending in SYMBOL (corpus_result)
  awk -v s="$2" '$NF == s && NF >= 5 {print $1; exit}' "$1" || true
}

# --- 1. dither -O3: the known overlap (map-derived bounds) --------------------------------------
O3="$EV/baseline/O3-default"
a=$(sym_addr "$O3/rom.map" corpus_result)
run_jg "$O3/rom.sfc" "0x$a" 0x80C4 JGX_PROGRAM=dither JGX_CONFIG="-O3 default"
if [ "$(rc)" -ne 0 ] && grep -q 'soft stack overlaps static data by 231 B (program=dither, config=-O3 default)' "$WORK/out" &&
   grep -q 'STACKGUARD FAIL: dither \[-O3 default\] soft stack overlaps static data by 231 B' "$WORK/err" &&
   grep -q 'min soft SP \$1EC7' "$WORK/err" && grep -q 'end of static data \$1FAE' "$WORK/err"; then
  ok "dither -O3 flagged: rc=$(rc), 231 B overlap, min SP \$1EC7 < __heap_start \$1FAE (value gate also red: $(grep -o 'got=0x[0-9A-F]*' "$WORK/out" | head -1))"
else
  bad "dither -O3 not flagged as expected (rc=$(rc))"; cat "$WORK/out" "$WORK/err"
fi
run_jg "$O3/rom.sfc" 0x0 0x0 JGX_STACKGUARD_ONLY=1
if [ "$(rc)" -eq 4 ] && grep -q '^SMOKE: FAIL (stackguard: soft stack overlaps' "$WORK/out"; then
  ok "dither -O3 under JGX_STACKGUARD_ONLY=1: rc=4 (the engine's stack-only run fails on the overlap alone)"
else
  bad "dither -O3 stack-only run: rc=$(rc)"; cat "$WORK/out" "$WORK/err"
fi
run_jg "$O3/rom.sfc" "0x$a" 0x80C4 JGX_STACKGUARD=0
if [ "$(rc)" -eq 1 ] && ! grep -qi stackguard "$WORK/out" "$WORK/err"; then
  ok "JGX_STACKGUARD=0 restores the original harness output (value gate red only, no guard text)"
else
  bad "JGX_STACKGUARD=0 still reports the guard (rc=$(rc))"; cat "$WORK/out" "$WORK/err"
fi

# --- 2. dither -O2: tight but legal -------------------------------------------------------------
O2="$EV/contrast/O2-default"
run_jg "$O2/rom.sfc" 0x0 0x0 JGX_STACKGUARD_ONLY=1 JGX_STACKGUARD_LOG="$WORK/o2.tsv"
margin=$(cut -f8 "$WORK/o2.tsv" 2>/dev/null || true)
if [ "$(rc)" -eq 0 ] && [ -n "$margin" ] && [ "$margin" -ge 0 ]; then
  ok "dither -O2: no overlap, margin $margin B (min SP $(cut -f5 "$WORK/o2.tsv"), static end $(cut -f6 "$WORK/o2.tsv"))"
else
  bad "dither -O2 unexpected: rc=$(rc) margin='${margin:-}'"; cat "$WORK/out" "$WORK/err"
fi

# --- 3. synthetic ROMs (ELF-derived bounds) -------------------------------------------------------
if [ -x "$TOOL/mos-clang" ] && [ -f "$CFG" ]; then
  cat >"$WORK/clean.c" <<'EOF'
volatile unsigned short corpus_result;
volatile unsigned char odd_pad[3];   // odd-sized .bss: __heap_start = ALIGN(., 2) must agree between ELF and map
int main(void) { odd_pad[0] = 1; corpus_result = 0x1234; for (;;) { } }
EOF
  # A variable-length array of 7800 B (low WRAM is 7680 B): SP lands about 120 B below the end of static
  # data. The volatile stores keep the allocation; corpus_result is still written correctly afterwards.
  cat >"$WORK/overlap.c" <<'EOF'
volatile unsigned short corpus_result;
volatile unsigned short n = 7800;
int main(void) {
  unsigned char v[n];
  volatile unsigned char *p = v;   // volatile stores keep the allocation alive
  for (unsigned i = 1000; i < 7800; i += 251) p[i] = (unsigned char)i;
  corpus_result = 0x1234;
  for (;;) { }
}
EOF
  # A 300 B VLA freed on return: the epilogue adds 300 to the SP low byte first, and the carry makes the
  # intermediate (new low, old high) 200+ B BELOW the true SP. The guard must not see that torn pair.
  cat >"$WORK/torn.c" <<'EOF'
volatile unsigned short corpus_result;
volatile unsigned short n = 300;
__attribute__((noinline)) unsigned char fill(void) {
  unsigned char v[n];
  volatile unsigned char *p = v;
  for (unsigned i = 0; i < 300; i += 37) p[i] = (unsigned char)i;
  return p[37];
}
int main(void) {
  unsigned char s = 0;
  for (unsigned k = 0; k < 20; ++k) s = (unsigned char)(s + fill());
  corpus_result = 0x1234;
  for (;;) { }
}
EOF
  for p in clean overlap torn; do
    "$TOOL/mos-clang" --config "$CFG" -mcpu=mosw65816 -Os -Wl,-Map="$WORK/$p.map" -o "$WORK/$p.sfc" "$WORK/$p.c" 2>"$WORK/$p.cc.log" \
      || { bad "synthetic $p did not build"; cat "$WORK/$p.cc.log"; continue; }
    python3 "$ROOT/tools/snes-checksum.py" "$WORK/$p.sfc" >/dev/null
  done
  if [ -f "$WORK/clean.sfc" ] && [ -f "$WORK/overlap.sfc" ]; then
    ac=$(sym_addr "$WORK/clean.map" corpus_result); ao=$(sym_addr "$WORK/overlap.map" corpus_result)
    run_jg "$WORK/overlap.sfc" "0x$ao" 0x1234 JGX_PROGRAM=synthetic-vla JGX_CONFIG="default -Os"
    if [ "$(rc)" -eq 4 ] && grep -q 'got=0x1234 matched, but stackguard: soft stack overlaps static data by [0-9]* B (program=synthetic-vla, config=default -Os)' "$WORK/out" &&
       grep -q 'bounds=.*overlap.sfc.elf' "$WORK/err"; then
      ok "synthetic VLA overlap (ELF bounds): rc=4 although corpus_result == want; $(grep -o 'overlaps static data by [0-9]* B' "$WORK/err" | head -1)"
    else
      bad "synthetic VLA overlap not flagged (rc=$(rc))"; cat "$WORK/out" "$WORK/err"
    fi
    run_jg "$WORK/clean.sfc" "0x$ac" 0x1234 JGX_STACKGUARD_LOG="$WORK/clean-elf.tsv"
    cp "$WORK/out" "$WORK/clean-on.out"; cp "$WORK/err" "$WORK/clean-on.err"; on_rc=$(rc)
    run_jg "$WORK/clean.sfc" "0x$ac" 0x1234 JGX_STACKGUARD=0
    if [ "$on_rc" -eq 0 ] && [ "$(rc)" -eq 0 ] && cmp -s "$WORK/clean-on.out" "$WORK/out" &&
       cmp -s "$WORK/clean-on.err" "$WORK/err" && grep -q '^SMOKE: PASS off=' "$WORK/out"; then
      ok "clean program: stdout/stderr/rc byte-identical with the guard on and off ($(cat "$WORK/out"))"
    else
      bad "clean program output differs with the guard on"; diff "$WORK/clean-on.out" "$WORK/out" || true
    fi
    run_jg "$WORK/torn.sfc" "0x$(sym_addr "$WORK/torn.map" corpus_result)" 0x1234 JGX_STACKGUARD_LOG="$WORK/torn.tsv"
    tsp=$(cut -f5 "$WORK/torn.tsv" | tr -d '$')
    if [ "$(rc)" -eq 0 ] && [ "$((16#$tsp))" -ge $((0x2000 - 300 - 64)) ] && [ "$((16#$tsp))" -le $((0x2000 - 300)) ]; then
      ok "torn SP pair ignored: 300 B frame freed 20 times, min SP \$$tsp (a torn epilogue read would show about \$1E00)"
    else
      bad "torn-pair control: rc=$(rc) min SP \$${tsp:-?}"; cat "$WORK/out" "$WORK/err" "$WORK/torn.tsv"
    fi
    # The corpus engine (tools/a16_fuzz.py evaluate, MAME stubbed): off -> PASS exactly as before,
    # on -> FAIL naming the program and each configuration even though every value agrees.
    if FUZZ_ROOT="$ROOT" BSNES_FRAMES="$FRAMES" python3 - "$WORK/overlap.c" >"$WORK/engine.out" 2>&1 <<'PY'
import sys
import os
sys.path.insert(0, os.path.join(os.environ["FUZZ_ROOT"], "tools"))
import a16_fuzz as F
F.run_mame = lambda rom, addr, want, length: (want, "stub")
off = F.evaluate(sys.argv[1], 0x1234, True, lambda r, e: None, verify=False, stackguard=False)
on = F.evaluate(sys.argv[1], 0x1234, True, lambda r, e: None, verify=False, stackguard=True)
print("off:", off[0], off[1]); print("on:", on[0], on[1])
assert off[0] == "PASS", off
assert on[0] == "FAIL" and "SOFT-STACK OVERLAP" in on[1], on
for needle in ("a16@bsnes", "default@bsnes", "+mos-xy16@bsnes", "program=overlap", "config=default -Os", "config=+mos-xy16 -Os"):
    assert needle in on[1], needle
PY
    then
      ok "corpus engine: stackguard off -> PASS, on -> FAIL naming the program and all three configurations"
    else
      bad "corpus engine leg"; cat "$WORK/engine.out"
    fi
    mkdir "$WORK/noelf" && cp "$WORK/clean.sfc" "$WORK/clean.map" "$WORK/noelf/"
    run_jg "$WORK/noelf/clean.sfc" "0x$ac" 0x1234 JGX_STACKGUARD_LOG="$WORK/clean-map.tsv"
    if [ "$(cut -f4-9 "$WORK/clean-elf.tsv")" = "$(cut -f4-9 "$WORK/clean-map.tsv")" ] &&
       grep -q 'sfc.elf$' "$WORK/clean-elf.tsv" && grep -q 'map$' "$WORK/clean-map.tsv"; then
      ok "ELF and map bounds agree: $(cut -f4-8 "$WORK/clean-elf.tsv" | tr '\t' ' ')"
    else
      bad "ELF and map bounds differ"; cat "$WORK/clean-elf.tsv" "$WORK/clean-map.tsv"
    fi
  fi
else
  echo "  SKIP  synthetic ROM legs (no $TOOL/mos-clang or $CFG): the dither evidence legs above still ran"
fi

# --- 4. require: a missing bounds source is a failure, not a silent pass --------------------------
mkdir "$WORK/bare" && cp "$O3/rom.sfc" "$WORK/bare/rom.sfc"
run_jg "$WORK/bare/rom.sfc" 0x0 0x0 JGX_STACKGUARD=require
if [ "$(rc)" -eq 2 ] && grep -q 'cannot check rom: no ' "$WORK/err"; then
  ok "JGX_STACKGUARD=require with no ELF/map beside the ROM: rc=2"
else
  bad "require did not fail on missing metadata (rc=$(rc))"; cat "$WORK/out" "$WORK/err"
fi

echo "$(ts) ==> stackguard check: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
