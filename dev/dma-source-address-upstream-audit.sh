#!/usr/bin/env bash
set -euo pipefail

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
CASE="$ROOT/test/upstream/dma-source-address"
OUT=${TMPDIR:-/tmp}/dma-source-address-upstream-audit
CLANG="$ROOT/build/llvm-mos-install/bin/mos-clang"
LLC="$ROOT/build/upstream-llc/bin/llc"

for tool in "$CLANG" "$LLC"; do
  test -x "$tool" || { echo "SKIP: missing $tool"; exit 77; }
done
mkdir -p "$OUT"

"$CLANG" -target mos -Os -S -emit-llvm "$CASE/dma-source-address.c" -o "$OUT/test.ll"
"$LLC" -O2 -verify-machineinstrs -stop-before=finalize-isel \
  "$OUT/test.ll" -o "$OUT/test.mir"
"$LLC" -O2 -verify-machineinstrs "$OUT/test.ll" -o "$OUT/test.s"
"$CLANG" -target mos -Os -c "$CASE/dma-source-address.c" -o "$OUT/test.o"
"$CLANG" -target mos -Os -c "$CASE/callee-good.c" -o "$OUT/good.o"
"$CLANG" -target mos -c "$CASE/callee-bad.s" -o "$OUT/bad.o"
"$CLANG" -target mos -Os -c "$CASE/linked-object.c" -o "$OUT/linked-object.o"
"$ROOT/build/llvm-mos-install/bin/ld.lld" -T "$CASE/link.ld" -e program_dma \
  "$OUT/test.o" "$OUT/good.o" "$OUT/linked-object.o" -o "$OUT/good.elf"

"$ROOT/build/upstream-llc/bin/llvm-readobj" --relocations --symbols "$OUT/test.o" > "$OUT/test.readobj"
"$ROOT/build/upstream-llc/bin/llvm-readobj" --relocations --symbols "$OUT/bad.o" > "$OUT/bad.readobj"
"$ROOT/build/upstream-llc/bin/llvm-objdump" -dr "$OUT/test.o" > "$OUT/test.objdump"
"$ROOT/build/upstream-llc/bin/llvm-objdump" -d --print-imm-hex "$OUT/good.elf" > "$OUT/good.objdump"

grep -q 'linked_object' "$OUT/test.readobj"
grep -q 'abi_conforming_call' "$OUT/test.readobj"
grep -q '#\$a5' "$OUT/good.objdump"
grep -q '#\$91' "$OUT/good.objdump"
grep -q '__rc0' "$OUT/bad.readobj"

echo "PASS: pristine upstream accepts the ABI-conforming address-across-call case"
echo "CONTROL: callee-bad.s explicitly violates the __rc0 software-stack ABI"
echo "PASS: linked bytes materialize linked_object at 0x91a5 as low=0xa5 high=0x91"
echo "Evidence: $OUT/{test.ll,test.mir,test.s,test.readobj,test.objdump,good.elf,good.objdump,bad.o,bad.readobj}"
