#!/usr/bin/env bash
# dev/rebuild-web-roms.sh — batch-recompile SNES demo ROMs for the web, IN ONE CONTAINER.
#
# Runs inside the llvm-mos-65816-dev image (invoke via: dev/run.sh rebuild-web-roms <slug>...).
# For each slug it maps slug->source .c, auto-derives the feature flag from that demo's dev/<src>.sh
# (so +mos-a16 vs default-8 stays correct without hardcoding), compiles build/<slug>.sfc with -Os, and
# fixes the SNES checksum. NO gate / emulator / render — that is the slow part and is unnecessary for a
# gate-neutral change (e.g. a shared title-font swap). Verify one representative demo with the full
# dev/run.sh <demo> gate separately.
#
#   dev/run.sh rebuild-web-roms boids maze cosmzoom ...      # explicit slugs
#   dev/run.sh rebuild-web-roms @/work/build/web-roms.list   # or a newline/space list file
#
# Outputs build/<slug>.sfc for each. Host side then copies them to the site (see
# docs/howto-bulk-rebuild-republish-web-roms.md).
set -euo pipefail

case "${1-}" in -h|--help|"")
  echo "Usage: dev/run.sh rebuild-web-roms <slug>... | @<listfile>"
  echo "  Batch-compiles build/<slug>.sfc for each demo slug (no gate). Auto feature flag per demo."
  exit 0;; esac

ROOT=/work
BUILD="$ROOT/build"
TOOL="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin"
CFG="$BUILD/install/bin/mos-snes.cfg"

[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no toolchain at $TOOL (run: dev/run.sh toolchain)"; exit 1; }
[ -f "$CFG" ]           || { echo "FATAL: SDK/snes not built (run: dev/run.sh build)"; exit 1; }

# slug -> source basename, only where they differ from the slug.
declare -A SRCMAP=( [3d-wireframe]=wireframe [buddhabrot]=buddha [space-invaders]=invaders )
# slug -> extra cflags. mandel-double is at the exact 32 KB bank edge, so it can't absorb the ~4 KB
# font16 table → build it with the legacy no-table title path (chunky font, but it fits).
declare -A EXTRA_CFLAGS=( [mandel-double]="-DTITLE_FONT16_OFF" )
# slug -> binary asset extensions (in examples/snes/) objcopy'd to .o and linked (e.g. gfx/palette blobs).
declare -A ASSET_EXTS=( [space-invaders]="pic pal" )
OBJCOPY="${MOS_TOOLCHAIN:-$BUILD/llvm-mos-install}/bin/llvm-objcopy"

# Every demo is built +mos-a16 -Os. The battery is a 5-way differential
# (host==default==+mos-a16==+mos-xy16), so the corpus/gate hash is MODE-INVARIANT — an a16 rebuild keeps
# each demo's manifest self-check hash even for demos originally shipped default-8. No -verify-machineinstrs
# (some demos ride the documented a16-rc-undef -verify known issue; the ROM codegen is correct regardless).
# Any demo that genuinely won't build in a16 falls back to default-8 automatically.
A16=(-Xclang -target-feature -Xclang +mos-a16)

# Expand a leading @listfile into its words.
SLUGS=()
for a in "$@"; do
  if [ "${a#@}" != "$a" ]; then
    f="${a#@}"; [ -f "$f" ] || { echo "FATAL: list file $f not found"; exit 1; }
    # shellcheck disable=SC2207
    SLUGS+=( $(tr ',' ' ' < "$f") )
  else
    SLUGS+=( "$a" )
  fi
done

ok=0; fail=0; skip=0; failed=""
for slug in "${SLUGS[@]}"; do
  src="${SRCMAP[$slug]:-$slug}"
  c="$ROOT/examples/snes/$src.c"
  if [ ! -f "$c" ]; then echo "SKIP  $slug (no examples/snes/$src.c)"; skip=$((skip+1)); continue; fi

  # Binary assets (gfx/palette blobs) → objcopy to .o and link.
  assets=(); asfail=0
  for ext in ${ASSET_EXTS[$slug]:-}; do
    if ( cd "$ROOT/examples/snes" && "$OBJCOPY" -I binary -O elf32-mos \
           --rename-section ".data=.rodata.${src}_${ext},alloc,load,readonly,data,contents" \
           "$src.$ext" "$BUILD/$slug.$ext.o" ) 2>>"$BUILD/$slug.buildlog"; then
      assets+=("$BUILD/$slug.$ext.o")
    else echo "FAIL  $slug  (asset $src.$ext objcopy)"; asfail=1; fi
  done
  if [ "$asfail" = 1 ]; then fail=$((fail+1)); failed="$failed $slug"; continue; fi

  # shellcheck disable=SC2086
  xtra=( ${EXTRA_CFLAGS[$slug]:-} )
  mode=a16
  if ! "$TOOL/mos-clang" --config "$CFG" -mcpu=mosw65816 "${A16[@]}" -Os "${xtra[@]}" \
        -o "$BUILD/$slug.sfc" "$c" "${assets[@]}" 2>"$BUILD/$slug.buildlog"; then
    # a16 didn't build — fall back to default-8 (still hash-identical by the differential).
    mode=default8
    if ! "$TOOL/mos-clang" --config "$CFG" -mcpu=mosw65816 -Os "${xtra[@]}" \
          -o "$BUILD/$slug.sfc" "$c" "${assets[@]}" 2>>"$BUILD/$slug.buildlog"; then
      echo "FAIL  $slug  (a16 + default8 both failed; see build/$slug.buildlog)"
      fail=$((fail+1)); failed="$failed $slug"; continue
    fi
  fi
  python3 "$ROOT/tools/snes-checksum.py" "$BUILD/$slug.sfc" >/dev/null
  echo "OK    $slug  (src=$src, $mode${xtra:+ ${EXTRA_CFLAGS[$slug]}}${assets:+ +assets})"
  ok=$((ok+1))
done

echo "---- rebuild-web-roms: $ok ok, $fail fail, $skip skip ----"
[ -n "$failed" ] && echo "FAILED:$failed"
[ "$fail" -eq 0 ]
