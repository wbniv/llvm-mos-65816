#!/usr/bin/env bash
# dev/release-test-inner.sh — runs INSIDE the clean-room rig (dev/Dockerfile.release-test).
#
# Acquires the *published* 65816 compiler (NOT the dev build — this container has no
# /work/build), compiles the reference Mandelbrot (mandel-display is far/+mos-a16-only;
# k_mandel builds both default-8bit and +mos-a16), runs each ROM headless in bsnes-jg
# (embedded SPC700 IPL → no BIOS, no sound), and asserts the WRAM corpus_result CRC
# matches the host oracle. Dumps a real emulator-rendered PNG per build. Prints a
# method×build result table; non-zero exit on any FAIL.
#
# Env knobs (set by dev/test-release.sh):
#   METHOD   = local | apt | tarball     (where mos-snes-clang comes from)
#   PROGRAM  = mandel-display | k_mandel  (default mandel-display)
#   A16      = both | 1 | 0               (which builds; default both — mandel-display forces a16-only)
#   FRAMES   = <n>                        (emulated frames before sampling; default per program)
#   PRODUCT_PAGE / APT_URL / APT_KEY_URL  (endpoints; defaults below)
# Inputs mounted by the runner:
#   /artifact/src.tar.xz                  (METHOD=local: the freshly-built tarball)
#   /out                                  (writable: PNGs + logs)
set -euo pipefail

case "${1-}" in -h|--help)
  echo "Usage: METHOD=local|apt|tarball PROGRAM=mandel-display|k_mandel [A16=both|1|0] [FRAMES=n] /opt/rig/inner.sh"
  echo "  (runs inside the clean-room rig image; normally driven by dev/test-release.sh)"
  exit 0;; esac

METHOD="${METHOD:-local}"
PROGRAM="${PROGRAM:-mandel-display}"
A16="${A16:-both}"
PRODUCT_PAGE="${PRODUCT_PAGE:-https://indri.studio/apps/llvm-mos-65816/}"
APT_URL="${APT_URL:-https://apt.indri.studio}"
APT_KEY_URL="${APT_KEY_URL:-$APT_URL/key.gpg}"

RIG=/opt/rig
OUT=/out
mkdir -p "$OUT"
WORK="$(mktemp -d)"
# The container runs as root (apt install + /opt writes need it); hand the /out
# artifacts (PNGs) back to the invoking host user so they aren't root-owned.
trap 'chown -R "${HOST_UID:-0}:${HOST_GID:-0}" "$OUT" 2>/dev/null || true; rm -rf "$WORK"' EXIT

# Colour only on a real TTY — under `docker run` (no -t) stdout is a pipe, so the
# host runner tees a clean, uncoloured compile log.
if [ -t 1 ]; then
  c_grn=$'\e[32m'; c_red=$'\e[31m'; c_dim=$'\e[2m'; c_rst=$'\e[0m'; c_bold=$'\e[1m'
else
  c_grn=''; c_red=''; c_dim=''; c_rst=''; c_bold=''
fi
say()  { printf '%s\n' "$*"; }
step() { printf '\n%s==> %s%s\n' "$c_bold" "$*" "$c_rst"; }
ts()   { date -u +%Y-%m-%dT%H:%M:%SZ; }   # ISO 8601 UTC (SRC convention)

# --- resolve the program ----------------------------------------------------
case "$PROGRAM" in
  mandel-display) SRC="$RIG/fixtures/snes/mandel-display.c"; FRAMES="${FRAMES:-1800}"; ORACLE=display
                  # The far/16-bit tester is +mos-a16-only: its high-WRAM escape buffer needs the
                  # far G_PTR_ADD the default-8bit target can't legalize. Collapse A16=both -> a16-only
                  # so the gate doesn't attempt (and fail) a default-8bit build. (k_mandel keeps both.)
                  [ "$A16" = both ] && { A16=1; say "  note: mandel-display is far/a16-only — testing +mos-a16 only"; } ;;
  k_mandel)       SRC="$RIG/fixtures/65816/k_mandel.c";      FRAMES="${FRAMES:-200}";  ORACLE=gate ;;
  *) say "FATAL: unknown PROGRAM='$PROGRAM' (use mandel-display | k_mandel)"; exit 2 ;;
esac
[ -f "$SRC" ] || { say "FATAL: fixture missing: $SRC"; exit 2; }
STARTED="$(ts)"; HOST_ARCH="$(uname -m)"; HOST_CPUS="$(nproc)"
UBUNTU="$( . /etc/os-release 2>/dev/null && printf '%s' "$PRETTY_NAME" )"
say "${c_bold}clean-room release test${c_rst}  METHOD=$METHOD  PROGRAM=$PROGRAM  A16=$A16  FRAMES=$FRAMES"
say "  started $STARTED  (host $HOST_ARCH, $HOST_CPUS CPU; ${UBUNTU:-?}; bsnes-jg ${RIG_BSNES_VER:-?})"

# --- C. sound-free assertion (cheap guard) ----------------------------------
step "sound-free check (no APU / SPC700 / \$2140-\$2143)"
if grep -niE 'apu|spc|214[0-3]|sound|audio' "$SRC"; then
  say "${c_red}FATAL: reference program references sound/APU — violates the no-BIOS clean-room constraint${c_rst}"
  exit 2
fi
say "  ${c_grn}OK${c_rst} — no sound/APU references"

# --- 2. acquire the published compiler --------------------------------------
step "acquire the published compiler (METHOD=$METHOD)"
acquire_from_tarball() { # <tarball>
  local tb="$1" dst=/opt/published
  rm -rf "$dst"; mkdir -p "$dst"
  tar -C "$dst" -xJf "$tb"
  # mos-snes-clang is a symlink; -path (no -type) matches it without the find -o/-print gotcha.
  CLANG="$(find "$dst" -path '*/bin/mos-snes-clang' | head -1)"
}
PKG_SOURCE=""; PKG_VERSION=""; PKG_URL=""
case "$METHOD" in
  local)
    [ -f /artifact/src.tar.xz ] || { say "FATAL: METHOD=local but /artifact/src.tar.xz not mounted"; exit 2; }
    say "  extracting the freshly-built tarball ($(du -h /artifact/src.tar.xz | cut -f1))"
    acquire_from_tarball /artifact/src.tar.xz
    PKG_SOURCE="local tarball (the freshly-built dist artifact — the publish gate)"
    ;;
  tarball)
    say "  scraping the tarball link off $PRODUCT_PAGE"
    url="$(curl -fsSL "$PRODUCT_PAGE" | grep -oE 'https://apt\.indri\.studio/sources/llvm-mos-65816_[^"]+\.tar\.xz' | head -1)"
    [ -n "$url" ] || { say "FATAL: no tarball link found on the product page"; exit 1; }
    say "  -> $url"
    curl -fsSL "$url" -o "$WORK/published.tar.xz"
    acquire_from_tarball "$WORK/published.tar.xz"
    PKG_SOURCE="product-page tarball link (live)"; PKG_URL="$url"
    ;;
  apt)
    say "  apt install llvm-mos-65816 from $APT_URL"
    install -d -m 0755 /etc/apt/keyrings
    curl -fsSL "$APT_KEY_URL" | gpg --dearmor -o /etc/apt/keyrings/indri.gpg
    echo "deb [signed-by=/etc/apt/keyrings/indri.gpg] $APT_URL stable main" >/etc/apt/sources.list.d/indri.list
    apt-get update -qq
    apt-get install -y -qq llvm-mos-65816 >/dev/null
    CLANG="$(command -v mos-snes-clang || true)"
    PKG_SOURCE="apt $APT_URL (live repo)"
    PKG_VERSION="$(dpkg-query -W -f='${Version}' llvm-mos-65816 2>/dev/null || true)"
    PKG_URL="$APT_URL"
    ;;
  *) say "FATAL: unknown METHOD='$METHOD' (use local | apt | tarball)"; exit 2 ;;
esac
[ -n "${CLANG:-}" ] && [ -e "$CLANG" ] || { say "FATAL: could not locate mos-snes-clang via METHOD=$METHOD"; exit 1; }
CLANG_REAL="$(readlink -f "$CLANG")"
CLANG_VER="$("$CLANG" --version 2>/dev/null | head -1)"
# Published install tree root: <prefix>/bin/clang-23 -> <prefix>. Used for the docs listing.
TREE="$(dirname "$(dirname "$CLANG_REAL")")"
say "  mos-snes-clang: $CLANG  -> $CLANG_REAL"

# --- clean-room assertions --------------------------------------------------
step "clean-room check (the dev build must be invisible)"
fail=0
if [ -e /work/build/llvm-mos-install ]; then say "  ${c_red}FAIL${c_rst}: /work/build/llvm-mos-install is present (dev build leaked in)"; fail=1; fi
case "$CLANG_REAL" in
  *llvm-mos-install*) say "  ${c_red}FAIL${c_rst}: compiler resolves into a dev install tree"; fail=1 ;;
esac
case "$METHOD" in
  apt)             case "$CLANG" in /usr/bin/*) : ;; *) say "  ${c_red}FAIL${c_rst}: apt compiler not on /usr/bin"; fail=1 ;; esac ;;
  local|tarball)   case "$CLANG_REAL" in /opt/published/*) : ;; *) say "  ${c_red}FAIL${c_rst}: compiler not from the extracted published tree"; fail=1 ;; esac ;;
esac
[ "$fail" -eq 0 ] && say "  ${c_grn}OK${c_rst} — only the published compiler is reachable" || exit 1

# --- 3+4. host oracle (the differential expectation) ------------------------
step "host oracle (independent CRC over the same grid)"
case "$ORACLE" in
  display)
    DW=$(awk '/#define DW /{print $3; exit}' "$SRC")
    DH=$(awk '/#define DH /{print $3; exit}' "$SRC")
    DN=$(awk '/#define DN /{print $3; exit}' "$SRC")
    say "  grid ${DW}x${DH}, N=${DN} (scraped from the program)"
    GRID="${DW}x${DH} N=${DN}"
    EXP=$("$RIG/mandel-render" "$OUT/mandel-host.png" "$DW" "$DH" "$DN" | grep -oE '0x[0-9A-Fa-f]{4}' | tail -1)
    say "  host reference: CRC16=$EXP  ($OUT/mandel-host.png)"
    ;;
  gate)
    GRID="16x10 N=12 (gate slice)"
    EXP=$("$RIG/mandel-render" --gate | grep -oE '0x[0-9A-Fa-f]{4}' | tail -1)
    say "  host reference (gate): CRC16=$EXP"
    ;;
esac
[ -n "${EXP:-}" ] || { say "FATAL: oracle produced no CRC"; exit 1; }

# --- which builds? ----------------------------------------------------------
builds=()
case "$A16" in
  both) builds=(default a16) ;;
  1)    builds=(a16) ;;
  0)    builds=(default) ;;
  *)    say "FATAL: A16='$A16' (use both|1|0)"; exit 2 ;;
esac

# --- 2(compile) + 5(run) per build ------------------------------------------
declare -A RESULT GOT CC_DT JG_DT SFC FLAGS SHOT
rc=0
for b in "${builds[@]}"; do
  extra=(); label="default-8bit"
  [ "$b" = a16 ] && { extra=(-Xclang -target-feature -Xclang +mos-a16); label="+mos-a16"; }
  FLAGS[$b]="${extra[*]}"; CC_DT[$b]="?"; JG_DT[$b]="?"; SFC[$b]=0; SHOT[$b]=""
  step "build + run: $label"
  sfc="$WORK/$PROGRAM-$b.sfc"; map="$WORK/$PROGRAM-$b.map"; cc="$WORK/$PROGRAM-$b.cc.log"
  # Compile with the PUBLISHED argv0 driver (mos-snes-clang bakes in --config + -mcpu=mosw65816).
  # SHOW the compilation: echo the exact command, run it capturing combined stdout+stderr, and
  # print that output (this is the "log showing the compilation"; the host runner tees it to a file).
  cmd=("$(basename "$CLANG")" "${extra[@]}" -Os -Wl,-Map="$(basename "$map")" -o "$(basename "$sfc")" "$SRC")
  say "  ${c_dim}[$(ts)] compile${c_rst}"
  say "  ${c_dim}\$ ${cmd[*]}${c_rst}"
  cc_t0=$(date +%s)
  set +e; "$CLANG" "${extra[@]}" -Os -Wl,-Map="$map" -o "$sfc" "$SRC" >"$cc" 2>&1; ccrc=$?; set -e
  cc_dt=$(( $(date +%s) - cc_t0 )); CC_DT[$b]="$cc_dt"
  if [ "$ccrc" -ne 0 ]; then
    say "  ${c_red}FAIL${c_rst}: compile error (exit $ccrc):"; sed 's/^/    | /' "$cc"; RESULT[$b]="FAIL(compile)"; rc=1; continue
  fi
  if [ -s "$cc" ]; then
    say "  ${c_dim}compiler output:${c_rst}"; sed 's/^/    | /' "$cc"
  else
    say "    | (no diagnostics — warning-clean)"
  fi
  # Public-release bar: zero warnings tolerated.
  if grep -qiE 'warning|error' "$cc"; then
    say "  ${c_red}FAIL${c_rst}: compile is NOT warning-clean (see output above)"; RESULT[$b]="FAIL(warning)"; rc=1; continue
  fi
  SFC[$b]="$(stat -c%s "$sfc")"
  say "  ${c_grn}compiled warning-clean${c_rst} -> $(basename "$sfc") (${SFC[$b]} bytes) [$(ts), ${cc_dt}s]"
  off=$(awk '$NF=="corpus_result"{print $1; exit}' "$map")
  [ -n "$off" ] || { say "  ${c_red}FAIL${c_rst}: corpus_result not in map"; RESULT[$b]="FAIL(nosym)"; rc=1; continue; }
  png=()
  [ "$ORACLE" = display ] && png=("$OUT/mandel-$b.png")
  say "  ${c_dim}[$(ts)] emulate${c_rst} — bsnes-jg: boot + run $FRAMES frames, read corpus_result @ WRAM 0x$off vs $EXP"
  jg_t0=$(date +%s)
  if line="$("$RIG/jgxcheck" "$sfc" "$RIG/Database" "0x$off" 2 "$EXP" "$FRAMES" "${png[@]}" 2>"$WORK/$b.jg.err")"; then
    jg_dt=$(( $(date +%s) - jg_t0 )); JG_DT[$b]="$jg_dt"
    say "  ${c_grn}$line${c_rst} [$(ts), ${jg_dt}s wall]"
    got=$(printf '%s' "$line" | grep -oE 'got=0x[0-9A-Fa-f]+' | cut -d= -f2)
    GOT[$b]="$got"; RESULT[$b]="PASS"
    [ "${#png[@]}" -gt 0 ] && SHOT[$b]="$(basename "${png[0]}")"
    # Screenshot is a REQUIRED deliverable for the display program — fail if absent.
    if [ "${#png[@]}" -gt 0 ]; then
      if [ -s "${png[0]}" ]; then
        say "  ${c_grn}screenshot${c_rst}: ${png[0]} ($(stat -c%s "${png[0]}") bytes, SNES Mandelbrot)"
      else
        say "  ${c_red}FAIL${c_rst}: expected screenshot ${png[0]} was not produced"; RESULT[$b]="FAIL(noshot)"; rc=1
      fi
    fi
  else
    JG_DT[$b]=$(( $(date +%s) - jg_t0 ))
    say "  ${c_red}$line${c_rst}"; sed 's/^/    /' "$WORK/$b.jg.err" 2>/dev/null || true
    got=$(printf '%s' "$line" | grep -oE 'got=0x[0-9A-Fa-f]+' | cut -d= -f2 || true)
    GOT[$b]="${got:-?}"; RESULT[$b]="FAIL"; rc=1
  fi
done

# --- 6. report --------------------------------------------------------------
step "result table  (METHOD=$METHOD  PROGRAM=$PROGRAM  oracle=$EXP)"
printf '  %-14s %-10s %-8s %s\n' "build" "got" "expect" "verdict"
printf '  %-14s %-10s %-8s %s\n' "-----" "---" "------" "-------"
for b in "${builds[@]}"; do
  v="${RESULT[$b]:-?}"; col="$c_grn"; [ "$v" = PASS ] || col="$c_red"
  lbl="default-8bit"; [ "$b" = a16 ] && lbl="+mos-a16"
  printf '  %-14s %-10s %-8s %s%s%s\n' "$lbl" "${GOT[$b]:-?}" "$EXP" "$col" "$v" "$c_rst"
done
echo
say "  ${c_bold}artifacts${c_rst} (in build/release-test/):"
say "    - this run transcript -> the compile log (host runner tees it to release-test-$METHOD.log)"
for f in "$OUT"/*.png; do
  [ -e "$f" ] || continue
  case "$f" in *mandel-host.png) tag="host reference (${DW:-?}x${DH:-?})";; *) tag="SNES Mandelbrot screenshot";; esac
  say "    - $(basename "$f")  ($(stat -c%s "$f") bytes, $tag)"
done
echo
FINISHED="$(ts)"
say "  finished $FINISHED"

# --- machine-readable data for dev/release-report.py (host renders the HTML) -
DATA="$OUT/release-report-data.tsv"
overall="PASS"; [ "$rc" -eq 0 ] || overall="FAIL"
{
  printf 'meta\tstarted\t%s\n'          "$STARTED"
  printf 'meta\tfinished\t%s\n'         "$FINISHED"
  printf 'meta\tmethod\t%s\n'           "$METHOD"
  printf 'meta\tprogram\t%s\n'          "$PROGRAM"
  printf 'meta\ta16\t%s\n'              "$A16"
  printf 'meta\tframes\t%s\n'           "$FRAMES"
  printf 'meta\toracle\t%s\n'           "$EXP"
  printf 'meta\tgrid\t%s\n'             "${GRID:-?}"
  printf 'meta\tcompiler_version\t%s\n' "${CLANG_VER:-?}"
  printf 'meta\tcompiler_path\t%s\n'    "$CLANG"
  printf 'meta\thost_arch\t%s\n'        "$HOST_ARCH"
  printf 'meta\thost_cpus\t%s\n'        "$HOST_CPUS"
  printf 'meta\tubuntu\t%s\n'           "${UBUNTU:-?}"
  printf 'meta\tbsnes\t%s\n'            "${RIG_BSNES_VER:-?}"
  printf 'meta\tresult\t%s\n'           "$overall"
  printf 'meta\tpkg_source\t%s\n'       "${PKG_SOURCE:-}"
  printf 'meta\tpkg_version\t%s\n'      "${PKG_VERSION:-}"
  printf 'meta\tpkg_url\t%s\n'          "${PKG_URL:-}"
  printf 'meta\ttree_bytes\t%s\n'       "$(du -sb "$TREE" 2>/dev/null | cut -f1)"
  for b in "${builds[@]}"; do
    lbl="default-8bit"; [ "$b" = a16 ] && lbl="+mos-a16"
    printf 'build\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
      "$lbl" "${FLAGS[$b]}" "${SFC[$b]}" "${GOT[$b]:-?}" "${RESULT[$b]:-?}" "${CC_DT[$b]}" "${JG_DT[$b]}" "${SHOT[$b]}"
  done
  # bundled docs in the published tree: top-level README + the docs/ tree (.md/.pdf),
  # NOT the per-platform SDK READMEs (those aren't release documentation).
  [ -f "$TREE/README.md" ] && printf 'doc\tREADME.md\t%s\tmd\n' "$(stat -c%s "$TREE/README.md")"
  if [ -d "$TREE/docs" ]; then
    find "$TREE/docs" -type f \( -iname '*.md' -o -iname '*.pdf' \) | sort | while read -r f; do
      rel="docs/${f#"$TREE"/docs/}"; ext="$(printf '%s' "${f##*.}" | tr 'A-Z' 'a-z')"
      printf 'doc\t%s\t%s\t%s\n' "$rel" "$(stat -c%s "$f")" "$ext"
    done
  fi
  # executables shipped in bin/: the real toolchain BINARIES (size), then the
  # user-facing SNES driver symlinks (entry points). The package also carries a
  # mos-<plat>-clang symlink + .cfg per SDK platform — counted, not enumerated.
  if [ -d "$TREE/bin" ]; then
    find "$TREE/bin" -maxdepth 1 -type f ! -name '*.cfg' | sort | while read -r f; do
      printf 'exe\tbin/%s\t%s\tbinary\n' "$(basename "$f")" "$(stat -c%s "$f")"
    done
    for d in mos-clang mos-clang++ mos-snes-clang mos-snes-clang++ mos-snes-far-clang mos-snes-far-clang++; do
      [ -L "$TREE/bin/$d" ] && printf 'exe\tbin/%s\t-1\tdriver → %s\n' "$d" "$(readlink "$TREE/bin/$d")"
    done
    printf 'meta\tbin_total\t%s\n' "$(find "$TREE/bin" -maxdepth 1 \( -type f -o -type l \) | wc -l | tr -d ' ')"
  fi
} >"$DATA"
say "  wrote $DATA (report data for dev/release-report.py)"

if [ "$rc" -eq 0 ]; then
  say "${c_grn}${c_bold}RESULT: PASS${c_rst} — the published compiler builds a correct, bootable ROM (METHOD=$METHOD)"
else
  say "${c_red}${c_bold}RESULT: FAIL${c_rst} — see the per-build lines above"
fi
exit $rc
