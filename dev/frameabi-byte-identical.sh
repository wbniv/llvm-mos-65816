#!/usr/bin/env bash
# dev/frameabi-byte-identical.sh — P0 guardrail for the frame-ABI study
# (docs/plans/2026-06-20-321-frame-abi-build-all-three-and-measure.md).
#
# Compile the corpus + kernels host-side at -Os in DEFAULT (8-bit) and +mos-a16,
# and print a sha256 manifest of each object's disassembly. Run BEFORE and AFTER a
# compiler change (e.g. adding the off-by-default +mos-dp-frame/+mos-sr-frame
# features) and diff — identical manifests prove the change did NOT perturb the
# default / +mos-a16 codegen that ships:
#
#   dev/frameabi-byte-identical.sh > /tmp/before.txt    # pre-change toolchain
#   ... edit vendor/ + dev/run.sh toolchain ...
#   dev/frameabi-byte-identical.sh > /tmp/after.txt     # post-change toolchain
#   diff /tmp/before.txt /tmp/after.txt && echo BYTE-IDENTICAL
#
# Host-side (no Docker): the container-built mos-clang runs on the host. Override
# CLANG/OBJDUMP to point at a different install.
set -euo pipefail

if [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
  echo "Usage: dev/frameabi-byte-identical.sh   # sha256 disasm manifest of corpus+kernels (default + a16)"
  exit 0
fi

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
T="$ROOT/build/llvm-mos-install/bin"
CLANG="${CLANG:-$T/mos-clang}"
OBJDUMP="${OBJDUMP:-$T/llvm-objdump}"
[ -x "$CLANG" ] || { echo "FATAL: no from-source toolchain at $CLANG (run: dev/run.sh toolchain)" >&2; exit 1; }

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT

srcs="$( { ls "$ROOT"/examples/snes/corpus/*.c "$ROOT"/examples/65816/k_*.c; } 2>/dev/null | sort || true )"
for src in $srcs; do
  name="$(basename "$src")"
  for variant in default a16; do
    flags=(-Os)
    [ "$variant" = a16 ] && flags+=(-Xclang -target-feature -Xclang +mos-a16)
    if "$CLANG" --target=mos -mcpu=mosw65816 "${flags[@]}" -c -o "$tmp/o.o" "$src" 2>"$tmp/err"; then
      h="$("$OBJDUMP" -d --mcpu=mosw65816 "$tmp/o.o" | tail -n +3 | sha256sum | cut -d' ' -f1)"
      printf '%-8s %-14s %s\n' "$variant" "$name" "$h"
    else
      printf '%-8s %-14s COMPILE-FAIL\n' "$variant" "$name"
    fi
  done
done
