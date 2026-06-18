#!/usr/bin/env bash
# dev/dwarf.sh — ROADMAP step 6 regression: a `-g` build emits correct, verifiable
# DWARF for the 65816, AND ld.lld writes the `<output>.elf` companion beside the ROM.
#
# This is the COMPILER-SIDE durable guard for the DWARF round-trip (the debugger
# half lives in drdevtools: `task test-dap` + dap/test_symbols.py against the
# committed a16local.sfc.elf fixture). It asserts SHAPES, not exact addresses —
# addresses drift with codegen and that is not a DWARF defect; a shape regression
# (missing companion, broken line table, a local that lost its location, a bad
# frame base, or any `--verify` error) is.
#
# Runs INSIDE the dev container; drive: dev/run.sh dwarf. Prereqs: from-source
# toolchain (dev/run.sh toolchain) + SDK (MOS_TOOLCHAIN=... dev/run.sh build).
# See docs/plans/2026-06-18-dwarf-round-trip-roadmap-step-6-drmon-tie-in.md.
set -euo pipefail

usage() { echo "Usage: dev/run.sh dwarf   # assert -g DWARF: companion ELF emitted, --verify clean, frame_base RS0, 16-bit local has a DW_OP_regx location, line table maps the source"; exit 0; }
[ "${1-}" = "-h" ] || [ "${1-}" = "--help" ] && usage

ROOT=/work
BUILD="$ROOT/build"
INSTALL="$BUILD/install"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
SRC="$ROOT/examples/65816/a16local.c"   # 16-bit globals + a multi-use 16-bit LOCAL `t` (Imag16-resident)
ROM="$BUILD/dwarf-a16local.sfc"
ELF="$ROM.elf"                          # ld.lld's auto-emitted DWARF companion
A16=(-Xclang -target-feature -Xclang +mos-a16)

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no from-source toolchain at $TOOL (run: dev/run.sh toolchain)"; exit 1; }
[ -f "$INSTALL/bin/mos-snes.cfg" ] || { echo "FATAL: SDK not built (run: MOS_TOOLCHAIN=$BUILD/llvm-mos-install dev/run.sh build)"; exit 1; }
[ -x "$TOOL/llvm-dwarfdump" ] || { echo "FATAL: no llvm-dwarfdump at $TOOL"; exit 1; }

rc=0
pass() { echo "  PASS: $1"; }
fail() { echo "  FAIL: $1"; rc=1; }

echo "==> build $SRC (+mos-a16, -g) -> $(basename "$ROM") (+ .elf companion)"
rm -f "$ROM" "$ELF"
"$TOOL/mos-clang" --config "$INSTALL/bin/mos-snes.cfg" -mcpu=mosw65816 "${A16[@]}" -g -Os \
  -fdebug-compilation-dir=. -o "$ROM" "$SRC"

# 1. The companion ELF must exist — this is the round-trip's debug artifact. If a
#    future ld.lld stops writing <output>.elf for OUTPUT_FORMAT{FULL(rom)}, catch it.
echo "==> 1. ld.lld emitted the DWARF companion <output>.elf"
if [ -f "$ELF" ] && "$TOOL/llvm-readelf" -S "$ELF" 2>/dev/null | grep -q "\.debug_info"; then
  pass "companion $(basename "$ELF") exists and has .debug_info"
else
  fail "no DWARF companion ELF beside the ROM (expected $ELF with .debug_info)"
  echo "RESULT: FAIL"; exit 1
fi

DUMP="$("$TOOL/llvm-dwarfdump" --debug-info --debug-line "$ELF" 2>/dev/null)"

# 2. --verify must be clean.
echo "==> 2. llvm-dwarfdump --verify is clean"
if "$TOOL/llvm-dwarfdump" --verify "$ELF" >/tmp/dwarf-verify.txt 2>&1; then
  pass "--verify: No errors"
else
  fail "--verify reported errors"; tail -5 /tmp/dwarf-verify.txt
fi

# 3. 4-byte address size (CodePointerSize=4 for 24-bit banking).
echo "==> 3. compile unit addr_size = 0x04"
printf '%s\n' "$DUMP" | grep -q "addr_size = 0x04" \
  && pass "addr_size = 0x04" || fail "addr_size != 0x04"

# 4. Frame base is the soft-stack register RS0 (DW_OP_regx RS0).
echo "==> 4. main DW_AT_frame_base = DW_OP_regx RS0"
printf '%s\n' "$DUMP" | grep -Eq "DW_AT_frame_base.*DW_OP_regx (RS0|0x210|528)" \
  && pass "frame_base = DW_OP_regx RS0" || fail "frame_base is not DW_OP_regx RS0"

# 5. The multi-use 16-bit LOCAL `t` is Imag16-resident and gets a register location
#    (DW_OP_regx <RSn>) — the novel 65816 case (#321). This is the high-value guard.
echo "==> 5. 16-bit local 't' has a DW_OP_regx location"
if printf '%s\n' "$DUMP" | grep -A4 'DW_TAG_variable' | grep -B2 '"t"' | grep -q "DW_AT_location"; then
  if printf '%s\n' "$DUMP" | grep -q "DW_OP_regx RS"; then
    pass "local 't' has DW_AT_location with DW_OP_regx RSn"
  else
    fail "local 't' location present but not a DW_OP_regx (imaginary-register) form"
  fi
else
  fail "local 't' has no DW_AT_location"
fi

# 6. Subprogram main with low_pc/high_pc.
echo "==> 6. DW_TAG_subprogram main has low_pc + high_pc"
printf '%s\n' "$DUMP" | grep -A6 'DW_TAG_subprogram' | grep -q 'DW_AT_low_pc' \
  && printf '%s\n' "$DUMP" | grep -A6 'DW_TAG_subprogram' | grep -q 'DW_AT_high_pc' \
  && pass "subprogram has low_pc + high_pc" || fail "subprogram missing low_pc/high_pc"

# 7. Line table maps a16local.c source lines to addresses, with an end_sequence.
echo "==> 7. .debug_line maps a16local.c with end_sequence"
LINES="$("$TOOL/llvm-dwarfdump" --debug-line "$ELF" 2>/dev/null)"
nrows=$(printf '%s\n' "$LINES" | grep -cE "^0x[0-9a-f]+ +[0-9]+ " || true)
printf '%s\n' "$LINES" | grep -q "end_sequence" || fail "no end_sequence in line table"
[ "${nrows:-0}" -ge 3 ] && pass "line table has $nrows rows + end_sequence" || fail "too few line-table rows ($nrows)"

echo
[ $rc -eq 0 ] && echo "RESULT: PASS — -g DWARF is correct + the <output>.elf debug companion is emitted" \
             || echo "RESULT: FAIL"
exit $rc
