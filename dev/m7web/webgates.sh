#!/usr/bin/env bash
# dev/m7web/webgates.sh — live-site checks for plan 121 gates 17/18/20/21/23 (static half) and
# plan 123 steps 2/4. Fetches both live galleries + both mandel-oop pages cold and prints the
# evidence the plans' verification records quote. Read-only; no site repo is modified.
#
# Usage: dev/m7web/webgates.sh [-h]
#   OUT=<dir>          where the fetched HTML lands (default build/m7web)
#   BIOHACK_SITE=<dir> INDRI_SITE=<dir>   site checkouts (default ~/biohack.net, ~/indri.studio)
#   SLUG=<demo>        demo whose per-demo page and ROM are checked (default mandel-oop)
set -euo pipefail
if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'; exit 0; fi
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT="${OUT:-$ROOT/build/m7web}"; mkdir -p "$OUT"
BIOHACK="${BIOHACK_SITE:-/home/will/biohack.net}"
INDRI="${INDRI_SITE:-/home/will/indri.studio}"
SLUG="${SLUG:-mandel-oop}"
cd "$OUT"

echo "## fetch"
curl -sS https://biohack.net/snes/ -o bh.html -w 'biohack %{http_code} %{size_download}\n'
curl -sS https://indri.studio/apps/llvm-mos-65816/snes/ -o in.html -w 'indri %{http_code} %{size_download}\n'
curl -sS "https://biohack.net/snes/$SLUG/" -o bh-demo.html -w "biohack $SLUG %{http_code} %{size_download}\n"
curl -sS "https://indri.studio/apps/llvm-mos-65816/snes/$SLUG/" -o in-demo.html -w "indri $SLUG %{http_code} %{size_download}\n"

echo; echo "## gate 17 / step 2 — counts (grep -o | wc -l; the pages are minified onto one line)"
for f in bh.html in.html; do
  echo "--- $f ---"
  echo "gl-mode7-badge spans: $(grep -o 'class="gl-mode7-badge' $f | wc -l)"
  echo "badges with aria-label=\"Mode 7 display\": $(grep -o 'aria-label="Mode 7 display"' $f | wc -l)"
  echo "data-display-mode=\"7\" hooks: $(grep -o 'data-display-mode="7"' $f | wc -l)"
  echo "filter toggles (class=\"gl-mode-toggle\"): $(grep -o 'class="gl-mode-toggle' $f | wc -l)"
done

echo; echo "## gate 18 / step 4 — live slug sets vs the committed ledger"
BIOHACK="$BIOHACK" INDRI="$INDRI" python3 - <<'EOF'
import re, json, os
def slugs(f):
    h = open(f).read()
    # each Mode 7 card is an <li … data-display-mode="7"> whose first <a href> is the demo page;
    # the slug is the last path segment (indri's blossom card links to /blossom/, same slug).
    return {m.group(1).rstrip('/').rsplit('/', 1)[-1]
            for m in re.finditer(r'<li\b[^>]*data-display-mode="7"[^>]*>\s*<a href="([^"]+)"', h)}
def ledger(repo):
    src = open(f'{repo}/src/data/mode7-contract.mjs').read()
    m = re.search(r'EXPECTED_MODE7_SLUGS\s*=\s*Object\.freeze\((\[[^\]]*\])', src, re.S)
    return set(json.loads(re.sub(r',\s*\]', ']', m.group(1).replace("'", '"'))))
bh, ind = slugs('bh.html'), slugs('in.html')
lb, li = ledger(os.environ['BIOHACK']), ledger(os.environ['INDRI'])
fmt = lambda s: ' '.join(sorted(s))
print(f"biohack live Mode 7 slugs ({len(bh)}): {fmt(bh)}")
print(f"indri   live Mode 7 slugs ({len(ind)}): {fmt(ind)}")
print(f"sets identical: {bh == ind}")
print(f"committed ledger biohack ({len(lb)}): {fmt(lb)}")
print(f"committed ledger indri   ({len(li)}): {fmt(li)}")
print(f"ledgers identical: {lb == li}")
print(f"live == ledger (biohack): {bh == lb}")
print(f"live == ledger (indri):   {ind == li}")
EOF
echo "contract file parity:"
sha256sum "$BIOHACK/src/data/mode7-contract.mjs" "$INDRI/src/data/mode7-contract.mjs"

echo; echo "## gate 20 — deployed $SLUG ROM SHA-256 (checked-in copies, then the live bytes)"
sha256sum "$BIOHACK/public/play/roms/$SLUG.sfc" "$INDRI/public/apps/llvm-mos-65816/play/roms/$SLUG.sfc"
curl -sS "https://biohack.net/play/roms/$SLUG.sfc" | sha256sum | sed "s|-\$|  https://biohack.net/play/roms/$SLUG.sfc|"
curl -sS "https://indri.studio/apps/llvm-mos-65816/play/roms/$SLUG.sfc" | sha256sum | sed "s|-\$|  https://indri.studio/apps/llvm-mos-65816/play/roms/$SLUG.sfc|"

echo; echo "## gate 21 — manifest entries"
SLUG="$SLUG" BIOHACK="$BIOHACK" INDRI="$INDRI" python3 - <<'EOF'
import json, os
slug = os.environ['SLUG']
for name, p in [('biohack', f"{os.environ['BIOHACK']}/public/play/roms/manifest.json"),
                ('indri', f"{os.environ['INDRI']}/public/apps/llvm-mos-65816/play/roms/manifest.json")]:
    e = [r for r in json.load(open(p))['roms'] if r.get('id') == slug][0]
    print(name, json.dumps({'id': e['id'], 'title': e.get('title'), 'selfcheck': e.get('selfcheck')}))
EOF

echo; echo "## gate 23 — content-hash cache-bust map in the built per-demo HTML"
for f in bh-demo.html in-demo.html; do
  echo "--- $f ---"
  SLUG="$SLUG" python3 - "$f" <<'EOF'
import re, sys, html, json, os
slug = os.environ['SLUG']; h = open(sys.argv[1]).read()
m = re.search(r'const bust = (\{[^}]*\})', h) or re.search(r'data-bust="([^"]*)"', h)
d = json.loads(html.unescape(m.group(1))) if m else {}
for k in (f'roms/{slug}.sfc', f'preview/{slug}.png', 'roms/manifest.json', 'app.js'):
    print(f"  bust[{k!r}] = {d.get(k)}")
EOF
done
echo "12-hex SHA-256 prefixes of the checked-in assets (what a republish changes):"
for p in "$BIOHACK/public/play/roms/$SLUG.sfc" "$BIOHACK/public/play/preview/$SLUG.png" \
         "$INDRI/public/apps/llvm-mos-65816/play/roms/$SLUG.sfc" "$INDRI/public/apps/llvm-mos-65816/play/preview/$SLUG.png"; do
  printf '  %s  %s\n' "$(sha256sum "$p" | cut -c1-12)" "$p"
done
echo "runtime consumer (biohack app.js bust()):"
grep -n 'function bust\|return BASE + path\|fetch(bust("roms/" + id\|img.src = bust' "$BIOHACK/public/play/app.js"
