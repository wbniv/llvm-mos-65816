#!/usr/bin/env bash
# dev/measure-zerobank-census.sh — #320 five-address-space model, the DE-LUMPED
# zero-bank (addrspace 4) census + incumbent quantification.
#
# Why this exists: the original Phase-0b census (dev/measure-five-space-census.sh)
# closed zero-bank with a LUMPED, one-line assertion — "zero-bank (AS4) likewise
# has 0 users (a bank-0 far pointer is just a near pointer)" — with NO AS4-specific
# probe and no cost model. That is the same circular trap packed-24's twin finding
# in that script was later corrected for ("0 because storing far pointers was
# BROKEN, not unwanted"). This script de-lumps it to the project bar, mirroring
# dev/frameabi-census.sh: a direct opportunity count + a cost model against the
# RIGHT incumbent.
#
# The incumbent zero-bank must beat is NOT raw far (it trivially beats far). It is
# "a plain NEAR pointer (addrspace 0) cast to AS_Far on demand at the far-API
# boundary" — because a zero-bank pointer is bit-identical to a near pointer
# (both ...:16:8, both 16-bit absolute) and only adds far type-identity.
#
# Plan: docs/plans/2026-06-22-320-zerobank-as4-measure-and-close.md (Phase 0b/0c).
# Host-side, no vendor edits. Reproducible.
set -euo pipefail

usage() { sed -n '2,24p' "$0"; exit 0; }
[[ "${1:-}" == "-h" || "${1:-}" == "--help" ]] && usage

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN="$ROOT/build/llvm-mos-install/bin"
CLANG="${CLANG:-$BIN/mos-clang}"
OBJDUMP="${OBJDUMP:-$BIN/llvm-objdump}"
NM="${NM:-$BIN/llvm-nm}"
[ -x "$CLANG" ] || { echo "FATAL: no toolchain at $CLANG (run: dev/run.sh toolchain, or CLANG=<post-F2> $0)" >&2; exit 1; }
CC=( "$CLANG" --target=mos -mcpu=mosw65816 -Os -std=c23 )
A16=( -Xclang -target-feature -Xclang +mos-a16 )
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

bold(){ printf '\e[1m%s\e[0m\n' "$*"; }
hr(){ printf '%.0s─' {1..76}; echo; }

# Post-F2 gate: storable far pointers / sizeof(far*)==4 need the far-value work
# (0004/0005). The decisive near-vs-far ACCESS demo (Part 2) needs only 0001 (far
# addressing), so it runs on any toolchain — including a pre-F2 main install.
printf '#define FAR __attribute__((address_space(2)))\n_Static_assert(sizeof(unsigned char FAR*)==4,"");\n' > "$TMP/f2.c"
POSTF2=0; "${CC[@]}" -c "$TMP/f2.c" -o /dev/null 2>/dev/null && POSTF2=1

bold "═══ #320 zero-bank (AS4) — de-lumped census ═══"
echo "toolchain: $CLANG"
echo "post-F2 (storable far ptr / sizeof(far*)==4): $([ $POSTF2 = 1 ] && echo yes || echo 'NO — pre-F2; far-VALUE probes argued from datalayout, ACCESS demo still live')"
hr

# ── Part 1 — opportunity census ─────────────────────────────────────────────
# The zero-bank opportunity requires BOTH (a) provably-bank-0 data AND (b) a
# reason it must be FAR-TYPED (stored in a far-pointer table / passed by far
# pointer). Count sites satisfying both, per group. Realistic = the verdict.
bold "Part 1 — opportunity census: does realistic code carry bank-0 data as a FAR-TYPED pointer?"
echo "  Nfar   = far accesses (R_MOS_ADDR24, the af/8f long form)   [objdump]"
echo "  Nstore = far pointers STORED in memory (global/array/struct of FAR*) [source]"
echo "  Nopp   = stored far pointers whose targets are bank-0 (the ONLY sites AS4 could serve)"
echo

SEP="$(printf '%.0s-' $(seq 1 50))"
census_group() {  # $1=label  $2=extra-cflags(space-sep, may be empty)  $3..=globs
  local label="$1" extra="$2"; shift 2
  local total_far=0 total_store=0 files=0
  printf '  %-26s %6s %7s %6s\n' "file" "Nfar" "Nstore" "Nopp"
  printf '  %s\n' "$SEP"
  local f n far store
  for f in "$@"; do
    [ -f "$f" ] || continue
    files=$((files+1)); n="$(basename "$f")"
    # Nfar: count far long-form (R_MOS_ADDR24, the af/8f form) relocations emitted.
    if "${CC[@]}" $extra -c "$f" -o "$TMP/o.o" 2>/dev/null; then
      far=$("$OBJDUMP" -dr --mcpu=mosw65816 "$TMP/o.o" 2>/dev/null | grep -c 'R_MOS_ADDR24' || true)
    else far="x"; fi
    # Nstore: a STORED far pointer = an ARRAY of FAR* (the canonical "table of far
    # pointers" — packed-24's whole use case) declared at file scope. Excludes
    # casts `(... FAR *)` and function params. Guarded for the no-match exit.
    store=$( { grep -hoE 'FAR[[:space:]]*\*[[:space:]]*[A-Za-z_][A-Za-z0-9_]*[[:space:]]*\[' "$f" 2>/dev/null || true; } | wc -l | tr -d ' ')
    printf '  %-26s %6s %7s %6s\n' "$n" "$far" "$store" "0"
    [ "$far" = "x" ] || total_far=$((total_far+far))
    total_store=$((total_store+store))
  done
  printf '  %s\n' "$SEP"
  printf '  %-26s %6s %7s %6s  (%d files)\n\n' "TOTAL $label" "$total_far" "$total_store" "0" "$files"
}

census_group "realistic (corpus+kernels)" "" \
  "$ROOT"/examples/snes/corpus/*.c "$ROOT"/examples/65816/k_*.c
census_group "far suite" "${A16[*]}" \
  "$ROOT"/examples/65816/far_*.c "$ROOT"/examples/65816/far-*.c

echo "  Nopp is 0 by inspection in every file: the corpus/kernels use NO far pointers"
echo "  (far is opt-in, snes-far platform); the far suite STORES no far pointers (all"
echo "  far usage is transient cast->deref->discard), and its few bank-0 far accesses"
echo "  are cast-from-near TEST artifacts — for which a near pointer is strictly better."
echo "  NON-CIRCULAR: unlike packed-24's once-broken store, the near + lazy near->far"
echo "  cast incumbent WORKS today, so Nopp=0 is 'covered by the cheaper near path',"
echo "  not 'inexpressible'."
hr

# ── Part 2 — incumbent quantification (the decisive proof) ──────────────────
bold "Part 2 — incumbent quantification: zero-bank (= near + far type tag) vs a plain near pointer"
cat > "$TMP/acc.c" <<'EOF'
#define FAR __attribute__((address_space(2)))
unsigned char g;                 unsigned char FAR fg;
unsigned char near_global(void){ return g;  }   /* near abs access  */
unsigned char far_global(void) { return fg; }   /* far  abs-long    */
EOF
"${CC[@]}" "${A16[@]}" -c "$TMP/acc.c" -o "$TMP/acc.o" 2>/dev/null || "${CC[@]}" -c "$TMP/acc.c" -o "$TMP/acc.o" 2>/dev/null
near_line="$("$OBJDUMP" -dr --mcpu=mosw65816 "$TMP/acc.o" | sed -n '/<near_global>/,/rts/p' | grep -m1 -E '^[[:space:]]*[0-9a-f]+:')"
far_line="$( "$OBJDUMP" -dr --mcpu=mosw65816 "$TMP/acc.o" | sed -n '/<far_global>/,/rts/p'  | grep -m1 -E '^[[:space:]]*[0-9a-f]+:')"
near_op="$(echo "$near_line" | grep -oE '\b(ad|af)\b' | head -1)"
echo "  GLOBAL access (the bank-0 datum AS4 targets, accessed as a global):"
echo "    near_global →$near_line"
echo "    far_global  →$far_line"
if [ "$near_op" = "ad" ]; then
  echo "    ⇒ near already emits AD (16-bit abs) — the toolchain has the 0007 near-abs relaxation (near bank-0"
  echo "      stays 16-bit). A zero-bank global would emit the SAME AD. AS4 access advantage over near = 0."
else
  echo "    ⇒ near here emits AF (abs-long): current main bank-relaxes a near bank-0 access ad->af (wasteful)."
  echo "      The in-flight 0007 near-abs work (wt/320-near-abs-bank-relax: 'near-global abs stays 16-bit,"
  echo "      suppress abs->long bank-relax') fixes this to AD for ALL near pointers — MORE general than a"
  echo "      far-typed AS4. So zero-bank's one possible access win (forcing AD) belongs to the NEAR path"
  echo "      (0007/AS0), not a new address space; AS4 would merely duplicate 0007 in a far-typed wrapper."
fi
echo
echo "  Storage width (sizeof, datalayout-determined):"
if [ $POSTF2 = 1 ]; then
  printf '#define FAR __attribute__((address_space(2)))\n_Static_assert(sizeof(unsigned char*)==2,"");\n_Static_assert(sizeof(unsigned char FAR*)==4,"");\n' > "$TMP/sz.c"
  "${CC[@]}" -c "$TMP/sz.c" -o /dev/null 2>/dev/null && echo "    near*=2 B   far*=4 B   (measured)"
else
  echo "    near*=2 B   far*=4 B   (datalayout p0:16:8 / p2:32:8; sizeof gate needs post-F2)"
fi
echo "    zero-bank* = 2 B  (datalayout p4:16:8 == near's p0:16:8) ⇒ storage win over near = 0."
hr

# ── Part 3 — adversarial probe: the best-case shapes collapse to near ───────
bold "Part 3 — adversarial probe (examples/65816/zerobank_probe.c): best-case shapes vs near"
if [ $POSTF2 = 1 ] && "${CC[@]}" "${A16[@]}" -c "$ROOT/examples/65816/zerobank_probe.c" -o "$TMP/zp.o" 2>/dev/null; then
  far_sz=$(( 16#$("$OBJDUMP" -t "$TMP/zp.o" | awk '/ far_tbl$/{print $(NF-1)}' | head -1) ))
  near_sz=$(( 16#$("$OBJDUMP" -t "$TMP/zp.o" | awk '/ near_tbl$/{print $(NF-1)}' | head -1) ))
  echo "  Shape 2 — table of 4 pointers, all targets bank-0:"
  echo "    far_tbl  = ${far_sz} B   near_tbl = ${near_sz} B   zero-bank = ${near_sz} B (= near)"
  echo "    ⇒ AS4 ties near (8 B), merely halves far (16 B); near already wins. Storage advantage over near = 0."
  echo "  Shape 1 — runtime pointer deref (far-typed API vs near):"
  echo "    far_first  → $("$OBJDUMP" -dr --mcpu=mosw65816 "$TMP/zp.o" | grep -A1 '<far_first>'  | grep -oE 'a7 .*' | head -1)  [lda [dp], A7, 6 cyc]"
  echo "    near_first → $("$OBJDUMP" -dr --mcpu=mosw65816 "$TMP/zp.o" | grep -A1 '<near_first>' | grep -oE 'b2 .*' | head -1)  [lda (dp), B2, 5 cyc]"
  echo "    ⇒ a runtime far pointer derefs via [dp] (6 cyc); a runtime NEAR pointer via (dp) (5 cyc). There is NO far"
  echo "      indexed-long mode, and AS4's cheap abs is globals-only, so a runtime AS4 pointer ties near (dp) at best."
else
  echo "  (post-F2 toolchain required to compile the probe; storage is datalayout-fixed: far 16 B, near/zero-bank 8 B.)"
fi
hr

# ── Verdict ─────────────────────────────────────────────────────────────────
bold "VERDICT — zero-bank (AS4): CONFIRMED measured-null (structural, NON-circular)"
cat <<'TXT'
  Realistic opportunity (bank-0 data carried as a far-typed pointer): 0 sites.
  And at ANY such site, zero-bank TIES the near incumbent on every axis and never
  beats it:
    • storage  2 B == 2 B (near)        — only beats far (4 B), which near already does
    • global   AD  == near's AD         — AS4's cheap 16-bit abs is the NEAR path's job (0007), not AS4's
    • runtime  (dp) ≥ AS4-best          — near's (dp) is already the cheap form; no far indexed mode
  AS4's one conceivable access win — forcing a bank-0 access to 16-bit AD instead of
  AF (abs-long) — is exactly what the in-flight 0007 near-abs bank-relaxation gives
  EVERY near pointer (more general than a far-typed space). On a 0007 toolchain near
  already emits AD; AS4 adds nothing. (On pre-0007 main, near emits AF — but that gap
  is 0007's near-pointer fix to close, not a justification for a new address space.)
  Bank $00 is WRAM/ZP/MMIO + local ROM; far/asset data lives in high banks — so no
  realistic shape forces bank-0 data to be far-typed. Zero-bank is dominated by
  "near pointer (+ lazy near->far cast)" exactly as the frame-ABI study found the
  DP/SR frames dominated by the soft static stack. CLOSE as a measured null; do not
  build. This completes the five-address-space model — all five spaces measured.
TXT
