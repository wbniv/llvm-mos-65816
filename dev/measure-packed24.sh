#!/usr/bin/env bash
# dev/measure-packed24.sh — #320 packed-24 Task A: the storage-vs-access net-bytes table.
#
# The justification for AS_FarPacked (3-byte far pointer) is "saves 1 byte/pointer on
# TABLES of far pointers." This sweeps a realistic shape — a static table of N far
# pointers into a bank-$01 blob, walked at runtime in a 16-bit-ambient loop and the
# derefs summed — compiled both AS_Far (4-byte) and AS_FarPacked (3-byte), and reports
# the NET bytes (table storage saved MINUS any extra access code) per N, so the
# break-even table size is explicit (lesson #2/#3: measure the realized win, don't
# assume the synthetic -25%).
#
# Finding (2026-06-22): packed wins ~N bytes at EVERY N (break-even N>=1) — the indexed
# walk's access code is equal (far loads only 3 of its 4 table bytes; the x3-vs-x4 stride
# is a constant), so the feared x3-index / byte-2-long cost does NOT apply to indexed
# table access (only to direct single-slot access; see the productionization handoff B).
#
# Drive from the host: dev/run.sh measure-packed24.   Runs inside the dev container.
set -euo pipefail
usage() { echo "Usage: dev/run.sh measure-packed24   # packed-24 (3B) vs far (4B) far-ptr table: net bytes + break-even"; exit 0; }
[ "${1-}" = "-h" ] || [ "${1-}" = "--help" ] && usage

ROOT=/work
TOOL="${MOS_TOOLCHAIN:-$ROOT/build/llvm-mos-install}/bin"
A16=(-Xclang -target-feature -Xclang +mos-a16)
[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no toolchain at $TOOL (dev/run.sh toolchain)"; exit 1; }
SCRATCH="$(mktemp -d)"; trap 'rm -rf "$SCRATCH"' EXIT

# Emit a far-ptr-table TU: N pointers into an extern bank-$01 blob (extern -> the walk
# can't be const-folded), walked at runtime. SLOT = FAR (4B) or PACKED (3B).
gen() { local N=$1 SLOT=$2 i
  echo "#define FAR __attribute__((address_space(2)))"
  echo "#define PACKED __attribute__((address_space(3)))"
  echo "extern const FAR unsigned char blob[];"
  printf 'const %s unsigned char *const table[%d] = {' "$SLOT" "$N"
  for ((i=0;i<N;i++)); do printf ' (const %s unsigned char *)&blob[%d],' "$SLOT" "$i"; done
  echo " };"
  echo "volatile unsigned char sink;"
  echo "void walk(void){ unsigned s=0; for(unsigned i=0;i<$N;i++) s += *(const FAR unsigned char *)table[i]; sink=(unsigned char)s; }"
}
# .text.walk size (mawk has no strtonum -> bash 16#).
twalk() { local h; h="$("$TOOL/llvm-objdump" --section-headers "$1" | awk '$2==".text.walk"{print $3; exit}')"; echo "$((16#${h:-0}))"; }
tbl()   { local h; h="$("$TOOL/llvm-nm" --print-size "$1" | awk '/ table$/{print $2; exit}')"; echo "$((16#${h:-0}))"; }

printf '%4s | %8s %8s | %9s %9s | %8s %s\n' N far_tbl pkd_tbl far_walk pkd_walk netB winner
printf '%4s-+-%8s-%8s-+-%9s-%9s-+-%8s-%s\n' ---- -------- -------- --------- --------- -------- ------
for N in 1 2 4 8 16 32 64; do
  gen "$N" FAR    > "$SCRATCH/f.c"; gen "$N" PACKED > "$SCRATCH/p.c"
  "$TOOL/mos-clang" --target=mos -mcpu=mosw65816 "${A16[@]}" -Os -std=c23 -c "$SCRATCH/f.c" -o "$SCRATCH/f.o"
  "$TOOL/mos-clang" --target=mos -mcpu=mosw65816 "${A16[@]}" -Os -std=c23 -c "$SCRATCH/p.c" -o "$SCRATCH/p.o"
  ft=$(tbl "$SCRATCH/f.o"); pt=$(tbl "$SCRATCH/p.o"); fw=$(twalk "$SCRATCH/f.o"); pw=$(twalk "$SCRATCH/p.o")
  net=$(( (ft+fw) - (pt+pw) ))   # >0 => packed total smaller (wins)
  win=$([ "$net" -gt 0 ] && echo packed || { [ "$net" -lt 0 ] && echo far || echo tie; })
  printf '%4s | %8s %8s | %9s %9s | %+8s %s\n' "$N" "$ft" "$pt" "$fw" "$pw" "$net" "$win"
done
echo
echo "netB > 0 => AS_FarPacked is smaller overall (table saved - extra access code). Break-even = smallest N with netB>0."
