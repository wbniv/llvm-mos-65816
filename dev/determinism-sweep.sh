#!/usr/bin/env bash
# Run the fixed 2026-09-15 SNES demo set through each demo's differential gate.
# Run inside the dev container with: task build-determinism-sweep
set -euo pipefail

ROOT=/work
MANIFEST="$ROOT/dev/build-determinism-demo-set.txt"
TOOLCHAIN="${MOS_TOOLCHAIN:-$ROOT/build/llvm-mos-install}"
LLC="${MOS_LLC:-$ROOT/build/llvm-mos/bin/llc}"
FIX_SOURCE="$ROOT/vendor/llvm-mos/llvm/lib/Target/MOS/MOSLegalizerInfo.cpp"

usage() {
  echo "Usage: task build-determinism-sweep [--only slug,slug,...] [--list]"
}

ONLY=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --only) [ "$#" -ge 2 ] || { usage >&2; exit 2; }; ONLY="$2"; shift 2 ;;
    --list) sed -e '/^[[:space:]]*#/d' -e '/^[[:space:]]*$/d' "$MANIFEST"; exit 0 ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; exit 2 ;;
  esac
done

[ -x "$LLC" ] || { echo "FATAL: fixed-toolchain llc missing: $LLC" >&2; exit 1; }
[ -f "$FIX_SOURCE" ] || { echo "FATAL: live legalizer source missing: $FIX_SOURCE" >&2; exit 1; }
python3 - "$FIX_SOURCE" <<'PY'
import pathlib, re, sys
source = pathlib.Path(sys.argv[1]).read_text()
fixed = re.search(
    r"Helper\.Observer\.changingInstr\(UseMI\);\s*"
    r"MO\.setReg\(Explicit16\);\s*"
    r"Helper\.Observer\.changedInstr\(UseMI\);",
    source,
)
if not fixed:
    raise SystemExit("FATAL: MOSLegalizerInfo.cpp does not contain the build-determinism observer fix")
PY
if [ ! "$LLC" -nt "$FIX_SOURCE" ]; then
  echo "FATAL: llc is older than the fixed legalizer source; rebuild the toolchain first" >&2
  exit 1
fi

echo "==> fixed compiler: $($TOOLCHAIN/bin/clang --version | head -1)"
echo "==> llc: $($LLC --version | head -1)"
echo "==> llc SHA-256: $(sha256sum "$LLC" | awk '{print $1}')"

declare -A alias=([spigot]=pi [mandel-display]=mandel-shot [hello]=smoke)
declare -a selected=()
declare -A requested=()
if [ -n "$ONLY" ]; then
  IFS=, read -r -a slugs <<<"$ONLY"
  for slug in "${slugs[@]}"; do requested["$slug"]=1; done
fi
while IFS= read -r slug; do
  [ -n "$slug" ] && [[ "$slug" != \#* ]] || continue
  if [ -n "$ONLY" ] && [ -z "${requested[$slug]:-}" ]; then continue; fi
  selected+=("$slug")
  unset 'requested[$slug]'
done < "$MANIFEST"
if [ "${#requested[@]}" -gt 0 ]; then
  printf 'FATAL: unknown demo slug(s): %s\n' "${!requested[*]}" >&2
  exit 2
fi

RUN_ID="$(date -u +%Y%m%dT%H%M%SZ)"
OUT="$ROOT/build/build-determinism-sweep/$RUN_ID"
mkdir -p "$OUT/logs"
SUMMARY="$OUT/results.tsv"
printf 'demo\tgate\tstatus\texit\tseconds\tlog\n' > "$SUMMARY"
total=${#selected[@]}
pass=0; fail=0; index=0
for slug in "${selected[@]}"; do
  gate="${alias[$slug]:-$slug}"
  script="$ROOT/dev/$gate.sh"
  source="$ROOT/examples/snes/$slug.c"
  index=$((index + 1))
  log="$OUT/logs/$slug.log"
  if [ ! -f "$source" ] || [ ! -f "$script" ]; then
    printf '%s\t%s\tFAIL\t2\t0\t%s\n' "$slug" "$gate" "${log#"$ROOT/"}" >> "$SUMMARY"
    printf 'FAIL %3d/%d %-20s missing source or gate script\n' "$index" "$total" "$slug"
    fail=$((fail + 1)); continue
  fi
  printf 'RUN  %3d/%d %-20s gate=%s\n' "$index" "$total" "$slug" "$gate"
  started=$(date +%s)
  if bash "$script" >"$log" 2>&1; then
    status=PASS; pass=$((pass + 1)); rc=0
  else
    rc=$?; status=FAIL; fail=$((fail + 1))
  fi
  elapsed=$(( $(date +%s) - started ))
  printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$slug" "$gate" "$status" "$rc" "$elapsed" "${log#"$ROOT/"}" >> "$SUMMARY"
  printf '%-4s %3d/%d %-20s %4ss\n' "$status" "$index" "$total" "$slug" "$elapsed"
done

printf '\nRESULT: %d/%d PASS, %d FAIL\n' "$pass" "$total" "$fail"
printf 'Summary: %s\n' "${SUMMARY#"$ROOT/"}"
[ "$fail" -eq 0 ]
