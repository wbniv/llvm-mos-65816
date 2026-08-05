#!/usr/bin/env bash
set -euo pipefail
ROOT=/work;BUILD="$ROOT/build";TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin";CFG="$BUILD/install/bin/mos-snes-hirom.cfg";SRC="$ROOT/examples/snes/farptrcmp.c";ASM="$BUILD/bankwalk-table.s";VENDOR="$ROOT/vendor/bsnes-jg";A16=(-Xclang -target-feature -Xclang +mos-a16);XY16=(-Xclang -target-feature -Xclang +mos-a16 -Xclang -target-feature -Xclang +mos-xy16)
rm -f "$BUILD/farptrcmp.natural-pass"
cc -DHOST -O2 "$ROOT/tools/farptrcmp-sim.c" -o "$BUILD/farptrcmp-sim";EXPECT=$("$BUILD/farptrcmp-sim"|grep -oE '0x[0-9A-Fa-f]{4}'|head -1);python3 "$ROOT/tools/gen-bankwalk-asm.py" "$ASM";echo "==> host oracle: $EXPECT";for mode in a16 xy16;do feat=("${A16[@]}");[ "$mode" = xy16 ]&&feat=("${XY16[@]}");"$TOOL/mos-clang" --config "$CFG" -mcpu=mosw65816 "${feat[@]}" -Os -mllvm -verify-machineinstrs -Wl,-Map="$BUILD/farptrcmp-$mode.map" -o "$BUILD/farptrcmp-$mode.sfc" "$SRC" "$ASM";python3 "$ROOT/tools/snes-checksum.py" --hirom "$BUILD/farptrcmp-$mode.sfc">/dev/null;done
# -verify-machineinstrs must run where codegen runs. --config defaults to LTO, under which -c
# emits bitcode (no codegen), so the flag on the build loop above verifies NOTHING (the
# wt/321-nmitally vacuous-verify finding; see dev/nmitally.sh). Verify on an explicit -fno-lto
# object and prove the output is a real object, not bitcode.
"$TOOL/mos-clang" --config "$CFG" -mcpu=mosw65816 "${A16[@]}" -Os -fno-lto -mllvm -verify-machineinstrs -c "$SRC" -o "$BUILD/farptrcmp.o";"$TOOL/llvm-objdump" -h "$BUILD/farptrcmp.o" >/dev/null 2>&1||{ echo "FAIL: -verify-machineinstrs emitted no real object (vacuous verify)";exit 1;};echo "    PASS: -verify-machineinstrs clean (real object emitted)"
rc=0;export SMOKE_SETTLE=480;export SMOKE_SECONDS=12;source "$ROOT/dev/_emu.sh";require_bios||exit $?;for mode in a16 xy16;do run_assert "$BUILD/farptrcmp-$mode.sfc" "$BUILD/farptrcmp-$mode.map" corpus_result "$EXPECT"||rc=1;VMA=$(awk '$NF=="corpus_result"{print $1;exit}' "$BUILD/farptrcmp-$mode.map");"$BUILD/jgxcheck" "$BUILD/farptrcmp-$mode.sfc" "$VENDOR/Database" "0x$VMA" 2 "$EXPECT" 480 "$BUILD/farptrcmp-$mode-jg.png"||rc=1;done
if [ "$rc" = 0 ]; then
  grep -Eq 'const FAR uint8_t[[:space:]]*\*[[:space:]]*p\[8\]' "$ROOT/examples/65816/farptrcmp.h"
  grep -Eq 'p\[j[[:space:]]*-[[:space:]]*1\][[:space:]]*>[[:space:]]*k' "$ROOT/examples/65816/farptrcmp.h"
  grep -Eq 'p\[i\][[:space:]]*-[[:space:]]*p\[i[[:space:]]*-[[:space:]]*1\]' "$ROOT/examples/65816/farptrcmp.h"
  bash "$ROOT/dev/write-natural-rom-receipt.sh" farptrcmp "$BUILD/farptrcmp-a16.sfc"
  echo "RESULT: PASS — FarPtrCmp host == a16 == xy16 == $EXPECT"
else
  echo FAIL
fi
exit "$rc"
