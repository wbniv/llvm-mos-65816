#!/usr/bin/env bash
# Phase 0 (and post-Phase-1 delta) measurement for #321 A16-threading.
# Counts the redundant inter-op `sta __rcN ; lda __rcN` round-trips (the value
# stored to an Imag16 home and immediately reloaded into the same accumulator)
# in native-+mos-a16 -Os codegen, plus per-function .text bytes. Re-run after
# the Phase-1 peephole lands and diff to show the win.
#   docs/plans/2026-06-17-321-a16-threading.md
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLANG="$ROOT/build/llvm-mos-install/bin/mos-clang"
OBJDUMP="$ROOT/build/llvm-mos-install/bin/llvm-objdump"
A16=(-Xclang -target-feature -Xclang +mos-a16)
CFLAGS=(--target=mos -mcpu=mosw65816 "${A16[@]}" -Os)

usage() { echo "usage: $(basename "$0") [-h]"; echo "  measures redundant Imag16 round-trips in +mos-a16 -Os codegen"; exit 0; }
[[ "${1:-}" == "-h" || "${1:-}" == "--help" ]] && usage

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT

# Count `sta __rcN` immediately followed by `lda __rcN` (same operand) in an asm file.
count_roundtrips() {
  awk '
    /^[[:space:]]*sta[[:space:]]+__rc[0-9]+$/ { prev=$2; have=1; next }
    /^[[:space:]]*lda[[:space:]]+__rc[0-9]+$/ { if (have && $2==prev) n++; have=0; next }
    { have=0 }
    END { print n+0 }
  ' "$1"
}

# Total .text bytes across all .text* sections (hex Size column). Anchor on the
# name field ($2) so .rela.text.* relocation sections are NOT counted.
text_bytes() {
  "$OBJDUMP" --section-headers "$1" 2>/dev/null \
    | awk '$2 ~ /^\.text/ { s += strtonum("0x" $3) } END { print s+0 }'
}

measure() { # name  srcfile
  local name="$1" src="$2"
  "$CLANG" "${CFLAGS[@]}" -S "$src" -o "$tmp/x.s" 2>/dev/null
  "$CLANG" "${CFLAGS[@]}" -c "$src" -o "$tmp/x.o" 2>/dev/null
  printf '%-14s  roundtrips=%-3s  .text=%s B\n' "$name" "$(count_roundtrips "$tmp/x.s")" "$(text_bytes "$tmp/x.o")"
}

echo "=== synthetic dependent-chain shapes ==="
cat > "$tmp/chain3.c" <<'EOF'
unsigned short a,b,c,d,r;
void f(void){ unsigned short t=a+b; unsigned short u=t&c; r=u-d; }
EOF
measure chain3 "$tmp/chain3.c"

cat > "$tmp/chain5.c" <<'EOF'
unsigned short a,b,c,d,e,g,r;
void f(void){ unsigned short t=a+b; t=t&c; t=t-d; t=t|e; r=t^g; }
EOF
measure chain5 "$tmp/chain5.c"

cat > "$tmp/reuse.c" <<'EOF'
unsigned short a,b,c,r1,r2;
void f(void){ unsigned short t=a+b; r1=t&c; r2=t-c; }  /* t reused: store must stay */
EOF
measure reuse "$tmp/reuse.c"

cat > "$tmp/mixedlocal.c" <<'EOF'
unsigned short g;
unsigned short f(unsigned short a, unsigned short b, unsigned short c){
  unsigned short t=a+b; unsigned short u=t^c; return u-g; }
EOF
measure mixedlocal "$tmp/mixedlocal.c"

echo
echo "=== kernels (real code) ==="
for k in k_crc16 k_fxmul k_prng k_bits k_satadd k_isort; do
  f="$ROOT/examples/65816/$k.c"
  [[ -f "$f" ]] && measure "$k" "$f" || echo "$k: (missing)"
done
