#!/usr/bin/env bash
# dev/build-release-docs.sh — generate the reader docs (.md + .pdf) that ship in the
# release tarball, FROM THIS REPO's own sources, so the package is self-contained and
# reproducible. No dependency on the indri.studio sibling having run its sync-docs;
# dev/package-release.sh calls this to populate RELEASE_DOCS_DIR.
#
# Each doc's markdown is `git show`n from a pinned ref:path (works for both `main` and
# the `wt/321-snes-hwref` branch). The PDF is best-effort: the shared md-to-html.sh +
# headless Chrome (the same pipeline ../indri.studio/scripts/sync-65816-docs.sh uses).
# The .md set is always emitted; a doc whose source ref/path is unreachable, or whose
# PDF can't render, is WARNed and skipped — never silently dropped.
#
# Usage: dev/build-release-docs.sh [OUTDIR]      (default build/release-docs)
# Env:   MD2HTML=<path to md-to-html.sh>          (default ../python-tui-lib/scripts/…)
#
# Manifest mirrors ../indri.studio/scripts/sync-65816-docs.sh — keep the two in sync
# (this repo owns the source docs; that script publishes them to the web).
set -euo pipefail

case "${1-}" in -h|--help) echo "Usage: dev/build-release-docs.sh [OUTDIR]"; exit 0;; esac

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="${1:-$ROOT/build/release-docs}"
MD2HTML="${MD2HTML:-$ROOT/../python-tui-lib/scripts/md-to-html.sh}"

CHROME=""
for c in google-chrome-stable google-chrome chromium chromium-browser; do
  command -v "$c" >/dev/null 2>&1 && { CHROME="$c"; break; }
done

# slug | ref | path   (reading order — oop-in-c last, the rest hardware-first)
DOCS=$(cat <<'TSV'
65816-opcodes|wt/321-snes-hwref|docs/refs/65816/65816-reference.md
snes-hardware|wt/321-snes-hwref|docs/refs/snes-hardware/snes-hardware-summary.md
snes-registers|wt/321-snes-hwref|docs/refs/snes-hardware/snes-register-map.md
snes-bootup|main|docs/snes-bootup-sequence.md
emulator-screenshots|main|docs/investigations/snes-emulator-screenshots.md
oop-in-c|main|docs/investigations/object-oriented-c-and-assembly.md
TSV
)

rm -rf "$OUT"; mkdir -p "$OUT"
echo "==> generating release docs into $OUT"
[ -n "$CHROME" ]   || echo "    note: no Chrome found — generating .md only (no .pdf)" >&2
[ -x "$MD2HTML" ]  || echo "    note: md-to-html.sh not at $MD2HTML — generating .md only (no .pdf)" >&2

# Read the manifest on FD 3 so the inner commands (chrome, md-to-html) — which read
# stdin — can't swallow the remaining doc lines (the classic loop-stdin gotcha).
n_md=0; n_pdf=0
while IFS='|' read -r slug ref path <&3; do
  [ -n "$slug" ] || continue
  if ! raw="$(git -C "$ROOT" show "$ref:$path" 2>/dev/null)"; then
    echo "    WARN: $slug — $ref:$path not reachable, skipping" >&2; continue
  fi
  # The opcode reference ships its short audit as an appendix (matches the web build).
  if [ "$slug" = 65816-opcodes ]; then
    if audit="$(git -C "$ROOT" show "$ref:docs/refs/65816/65816-opcode-audit.md" 2>/dev/null)"; then
      raw="$raw"$'\n\n---\n\n'"$audit"
    fi
  fi
  printf '%s\n' "$raw" > "$OUT/$slug.md"; n_md=$((n_md+1))
  echo "    md  $slug.md ($(du -h "$OUT/$slug.md" | cut -f1))"
  if [ -n "$CHROME" ] && [ -x "$MD2HTML" ]; then
    MD_TO_PDF_NO_OPEN=1 bash "$MD2HTML" "$OUT/$slug.md" >/dev/null 2>&1 || true
    html="$HOME/tmp/$slug.html"
    if [ -f "$html" ] && "$CHROME" --headless=new --no-sandbox --disable-gpu \
         --no-pdf-header-footer --print-to-pdf="$OUT/$slug.pdf" "file://$html" >/dev/null 2>&1; then
      n_pdf=$((n_pdf+1)); echo "    pdf $slug.pdf ($(du -h "$OUT/$slug.pdf" | cut -f1))"
    else
      echo "    WARN: could not render $slug.pdf (md still bundled)" >&2
    fi
  fi
done 3<<< "$DOCS"

echo "==> release docs: $n_md md, $n_pdf pdf in $OUT"
[ "$n_md" -gt 0 ] || { echo "FATAL: no release docs generated (check the doc refs)" >&2; exit 1; }
