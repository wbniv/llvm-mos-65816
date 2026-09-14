# Mode 7 gallery website layer — reconcile plans 121 and 123 with current reality

TODO entry: `[T3] Reconcile the Mode-7 gallery website layer with current reality (121 gates
17/20/22/23 + 123 gates 2/4/10 — resolve ONCE for both plans)`, plus the orchestrator's addition of
121 gate 11. Worktree `wt/m7-gallery-web-reconcile` (hardlink/non-compiler, off `main` @ `294bc8c`).

## Goal

Both `[verify T3]` items for [plan 121](2026-07-26-121-mode7-gallery-badges-and-mandel-oop-startup.md)
and [plan 123](2026-07-26-123-mode7-gallery-filter.md) have been blocked since 2026‑08‑04 on the same
handful of website-layer gates whose *expectations* no longer describe what the two sites serve. For
each such gate this plan records, once, what the gate expects, what the live site / manifest does
today, and a decision — **fix the site** to meet the gate, or **fix the gate** because an intentional
change (named by commit) made the wording stale — then executes every decision and re-runs both
plans' complete verification sections against current `main`.

No visible surface changes here: the only user-visible effect is the staged `mandel-oop` republish
(a startup-path ROM change already specified and verified by plans 121 / 2026‑08‑05 / 2026‑09‑14), so
this plan carries no mockups.

## Decision table

| # | Gate | What the gate expects | What the live site / manifest does today (2026‑09‑14) | Decision | Evidence (the commit that made the change intentional) |
|---|---|---|---|---|---|
| 1 | **121 / 17** — "Exactly nine `7` badges on each gallery" | A fixed count of nine | 11 badges on both galleries, one-for-one with `data-display-mode="7"` hooks; the count is **derived** from each site's registry and pinned by a committed ledger + `MODE7_PARITY_DIGEST` that fails both builds on drift | **Fix the gate.** Plan 121 formally adopts plan 123's 2026‑08‑04 amendment: "nine" reads as the contract count, `EXPECTED_MODE7_SLUGS.length` (11 today). Plan 121's matrix, rollout and acceptance criteria are annotated, not rewritten. | `cdaa6f4` (`svx2-fastrom-video`) and `ad87374` (`apollo-daylight`) legitimately added two Mode 7 demos; `1a9d9b8` landed the contract that makes the count reviewed instead of silent |
| 2 | **121 / 20** — "Both deployed `mandel-oop` ROMs match the verified build SHA-256" | Deployed bytes == the build the plan verified | Both sites serve `59a76c6f…` (the ROM verified and published 2026‑08‑05, `0ee4ba9` / `dc27e7f`, `corpus_result @ 0x895`). A fresh build of today's `main` is `140c7b74…` with `corpus_result @ 0x897` — the sources changed after the publish. | **Fix the gate's reference, and set the republish policy.** The gate compares the deployed ROM to the SHA **recorded by the most recent publication record** in the plan, never to an arbitrary rebuild. A rebuild that differs is scored by *why*: (a) **demo-source drift** (`examples/snes/mandel-oop.c` or the `snesgfx` headers it includes changed since the published build) → republish; (b) **toolchain-only drift** (same sources, different bytes) → accepted divergence, recorded with the differential result, no republish. Today is case (a), so the republish is **staged** on a branch in each site repo and left unpushed (publishing is user-gated). | `13ebe3e` (post-title force-blank 11 → 5), `e2f3cd0` + `b6ab8b5` (first-frame opt-in adopted by `mandel-oop`) all post-date the 08‑05 publish |
| 3 | **121 / 22** — "Browser smoke test sees title → loading animation → progressive image → ready animation" | A real browser drives the live page | Never executed: neither site repo has browser automation and none may be added there; the 08‑04 run recorded "none installed on this host". Google Chrome 152 **is** on this host now. | **Fix the method, not the gate.** The gate is a *verification step*, not a CI requirement, so it needs no Playwright in either site repo. Executed with host Chrome (`--headless=new`) driven over the DevTools protocol by `dev/m7web/smoke22.mjs`, sampling the player canvas at **emulated frame numbers** (one SNES frame per `requestAnimationFrame`) so the browser timeline lines up with the `jgxcheck` framescan. | — (method change; nothing in either site repo) |
| 4 | **121 / 23** — "Cache-busted ROM and preview URLs change in the built HTML" | A republished ROM/preview cannot be served from a stale cache | Both per-demo pages ship a **content-hash map** in the built HTML (`roms/mandel-oop.sfc → 59a76c6f84a1`, `preview/mandel-oop.png → 36f2fcdd3292`, …) and `app.js`'s `bust()` appends `?v=<sha>` to every player asset request at runtime (`fetch(bust("roms/" + id + ".sfc"))`, `img.src = bust("preview/" + id + ".png")`). The 08‑03/08‑04 FAIL grepped the HTML for a literal `mandel-oop.sfc?…` URL, which this design never emits. | **Fix the gate's measurement.** The check is (i) the hash map in the built HTML carries the ROM and preview entries and they equal the checked-in assets' SHA prefixes, and (ii) the browser's actual requests carry `?v=<sha>`. Both hold; a republish changes the map (proof: the staged branch's rebuilt page will carry `140c7b742f65`). | biohack `3aeb92d` (2026‑07‑27, `SnesPlayer` + `BJG_BUST`); indri `2208cb0` + `c7988ac` (2026‑07‑26, `data-bust` on `#bjg-embed`) — both **predate** the 08‑04 record |
| 5 | **123 / 2** — "exactly nine `data-display-mode="7"` cards and nine accessible badges" | nine | 11 / 11 / 1 toggle on both sites; equals the ledger | **Fix the gate** — already amended 2026‑08‑04 ("nine" = contract count); re-verified only. | `cdaa6f4`, `ad87374`, `1a9d9b8` (as row 1) |
| 6 | **123 / 4** — "Activating Mode 7 shows exactly the nine expected slugs" | nine | The 11-slug contract set, identical on both sites and equal to the ledger | **Fix the gate** — same amendment; re-verified in a real browser this time. | as row 1 |
| 7 | **123 / 10** — "Test at the narrowest supported phone width and with reduced motion" | Layout + motion behaviour at 320 CSS px, with `prefers-reduced-motion: reduce` | BLOCKED-no-harness since 08‑03 (jsdom does no layout; no browser on host) | **Fix the method, not the gate.** Executed in host Chrome at 320×640 (mobile metrics) and again with `--force-prefers-reduced-motion`, by `dev/m7web/filter123.mjs`; the arrow-overflow sub-case from step 8 is measured with real layout (`scrollWidth > clientWidth` vs the nav's `hidden`). | — |
| 8 | **121 / 11** — "first post-title frame — non-black animated loading field" | Zero black frames after the title | `FRAMES=700 dev/m7blank.sh --gate`: `mandel-oop` measured **5**, budget **6**; the physical floor is **1** (the Mode 7 / CGRAM mode switch cannot happen with the screen on), and the remaining frames are the splash's own fade-to-black tail | **Fix the gate.** Re-baselined to "post-title black frames ≤ the committed `dev/m7blank.sh` budget for the demo (`mandel-oop`: measured 5, budget 6, floor 1)". The 0-frame wording is physically unattainable; see the floor measurement. Scored PASS from today's `--gate` output. | [2026‑08‑05 floor plan](2026-08-05-mode7-splash-forceblank-floor.md) (floor = 1 frame), `13ebe3e` (11 → 5), `e2f3cd0` / `b6ab8b5` (first-frame opt-in, merged) |

## Execution

1. **Plan 121 amendment** (`docs/plans/2026-07-26-121-…md`, new section "Amendment — 2026‑09‑14"):
   rows 1, 2, 3, 4 and 8 — gate 17's count, gate 20's reference SHA + republish policy, gate 22's
   method, gate 23's measurement, gate 11's budget. Annotates; never rewrites the 2026‑07‑26 text.
2. **Plan 123 note** (`docs/plans/2026-07-26-123-…md`, appended to the 2026‑08‑04 amendment): step 10's
   method (row 7). Steps 2 and 4 need nothing new.
3. **Reproducible harness** in this repo — `dev/m7web/`: `cdp.mjs` (DevTools driver over host
   Chrome, no npm deps), `smoke22.mjs` (gate 22 + gate 23 runtime proof), `filter123.mjs` (123 steps
   3–10), `webgates.sh` (121 gates 17/18/20/21/23 static + 123 steps 2/4), `romgates.sh` (121 gates
   1/4/6/8–16/21). Nothing is added to either site repo.
4. **Republish staged, not pushed** (row 2): a branch `snes/mandel-oop-republish` in a worktree of
   each site repo carrying the fresh ROM (`140c7b74…`), the manifest `selfcheck.off` `0x895 → 0x897`
   (and its label), and — indri only — the same field in `src/data/snes-demos.ts`. The preview PNG is
   unchanged (the ready state is unchanged: `0x204F` and gate 4; the 08‑05 republish kept it too).
5. **Re-run both plans' verification sections in full** against `main` @ `294bc8c` and record raw
   output + PASS/FAIL under every step in both plan files (house format).

## Verification

1. `bash dev/m7web/webgates.sh` — 121 gates 17/18/20/21/23 (static half) and 123 steps 2/4: 11 badges
   = 11 hooks = ledger on both sites; deployed ROM bytes `59a76c6f…` on both; bust map carries the ROM
   and preview hashes.
2. `node dev/m7web/smoke22.mjs biohack <out>` — title → loading → progressive → ready observed on the
   live biohack page; every player asset request carries `?v=<sha>`. `… indri <out>` — expected to
   FAIL on the known `[wip T2]` indri player defect (ROM never requested); record it as such.
3. `node dev/m7web/filter123.mjs <out>` — 123 steps 3–10 PASS on both sites, including 320 px and
   reduced-motion runs.
4. `dev/run.sh mandel-oop` in the worktree — `0x204F` on host, bsnes-jg and MAME; then
   `bash dev/m7web/romgates.sh` — gates 1, 4, 6, 8–16 evidence, 21 on the deployed ROMs.
5. `FRAMES=700 dev/m7blank.sh --gate` — `mandel-oop` measured ≤ budget (5 / 6).
6. Both site worktree branches carry exactly the republish files, unpushed: `git log -1 --stat` on each
   shows only the ROM + manifest (+ indri registry); `git status -sb` shows the branch ahead of nothing
   remote; `build/jgxcheck <staged rom> … 0x897 2 0x204F 5800` PASS.
7. Both plan files carry a "Verification record — 2026‑09‑14" with every step verbatim and scored.

## Verification results — 2026‑09‑14, against `main` @ `294bc8c`

### 1. `bash dev/m7web/webgates.sh`

```
## fetch
biohack 200 120877
indri 200 174244
biohack mandel-oop 200 8643
indri mandel-oop 200 69660

## gate 17 / step 2 — counts (grep -o | wc -l; the pages are minified onto one line)
--- bh.html ---
gl-mode7-badge spans: 11
badges with aria-label="Mode 7 display": 11
data-display-mode="7" hooks: 11
filter toggles (class="gl-mode-toggle"): 1
--- in.html ---
gl-mode7-badge spans: 11
badges with aria-label="Mode 7 display": 11
data-display-mode="7" hooks: 11
filter toggles (class="gl-mode-toggle"): 1

## gate 18 / step 4 — live slug sets vs the committed ledger
biohack live Mode 7 slugs (11): apollo-daylight avalanche blossom buddhabrot julia lzss-gallery mandel-display mandel-double mandel-float mandel-oop svx2-fastrom-video
indri   live Mode 7 slugs (11): apollo-daylight avalanche blossom buddhabrot julia lzss-gallery mandel-display mandel-double mandel-float mandel-oop svx2-fastrom-video
sets identical: True
committed ledger biohack (11): apollo-daylight avalanche blossom buddhabrot julia lzss-gallery mandel-display mandel-double mandel-float mandel-oop svx2-fastrom-video
committed ledger indri   (11): apollo-daylight avalanche blossom buddhabrot julia lzss-gallery mandel-display mandel-double mandel-float mandel-oop svx2-fastrom-video
ledgers identical: True
live == ledger (biohack): True
live == ledger (indri):   True
contract file parity:
1bf91bab908dab36c66577addb4b099ea533ffb3adfc0cad02e579b169fc24d2  /home/will/biohack.net/src/data/mode7-contract.mjs
1bf91bab908dab36c66577addb4b099ea533ffb3adfc0cad02e579b169fc24d2  /home/will/indri.studio/src/data/mode7-contract.mjs

## gate 20 — deployed mandel-oop ROM SHA-256 (checked-in copies, then the live bytes)
59a76c6f84a171b01d366d56b134af469f3cf2c597c8bc1679e88981a847872e  /home/will/biohack.net/public/play/roms/mandel-oop.sfc
59a76c6f84a171b01d366d56b134af469f3cf2c597c8bc1679e88981a847872e  /home/will/indri.studio/public/apps/llvm-mos-65816/play/roms/mandel-oop.sfc
59a76c6f84a171b01d366d56b134af469f3cf2c597c8bc1679e88981a847872e    https://biohack.net/play/roms/mandel-oop.sfc
59a76c6f84a171b01d366d56b134af469f3cf2c597c8bc1679e88981a847872e    https://indri.studio/apps/llvm-mos-65816/play/roms/mandel-oop.sfc

## gate 21 — manifest entries
biohack {"id": "mandel-oop", "title": "Mode 7 Mandelbrot (OOP)", "selfcheck": {"off": "0x895", "len": 2, "want": "0x204F", "frames": 5800, "label": "gate jgxcheck CRC (corpus_result @ WRAM $0895)"}}
indri {"id": "mandel-oop", "title": "Mode 7 Mandelbrot (OOP)", "selfcheck": {"off": "0x895", "len": 2, "want": "0x204F", "frames": 5800, "label": "gate jgxcheck CRC (corpus_result @ WRAM $0895)"}}

## gate 23 — content-hash cache-bust map in the built per-demo HTML
--- bh-demo.html ---
  bust['roms/mandel-oop.sfc'] = 59a76c6f84a1
  bust['preview/mandel-oop.png'] = 36f2fcdd3292
  bust['roms/manifest.json'] = c8a28a93792b
  bust['app.js'] = fdb8b71ef465
--- in-demo.html ---
  bust['roms/mandel-oop.sfc'] = 59a76c6f84a1
  bust['preview/mandel-oop.png'] = 36f2fcdd3292
  bust['roms/manifest.json'] = 849291757bfe
  bust['app.js'] = 100f4b5122e4
12-hex SHA-256 prefixes of the checked-in assets (what a republish changes):
  59a76c6f84a1  /home/will/biohack.net/public/play/roms/mandel-oop.sfc
  36f2fcdd3292  /home/will/biohack.net/public/play/preview/mandel-oop.png
  59a76c6f84a1  /home/will/indri.studio/public/apps/llvm-mos-65816/play/roms/mandel-oop.sfc
  36f2fcdd3292  /home/will/indri.studio/public/apps/llvm-mos-65816/play/preview/mandel-oop.png
runtime consumer (biohack app.js bust()):
24:  function bust(path) {
26:    return BASE + path + (b && b[path] ? "?v=" + b[path] : "");
188:    return fetch(bust("roms/" + id + ".sfc"))
350:    img.src = bust("preview/" + id + ".png");
```

**PASS** — 11 = 11 = ledger on both sites; deployed bytes `59a76c6f…` on both; the bust map carries the ROM and preview hashes.

### 2. `node dev/m7web/smoke22.mjs biohack <out>` / `… indri <out>`

```
status: "running mandel-oop.sfc · 256×224"  (+6867 ms after navigation)

 target  sampled  nonblack%  colours  row0_nb  rowL_nb  hash      diff_prev   wall(s)
     60       61      99.61        7      255      255  e2e27d05          -     10.1
    120      120      99.61        5      255      255  641a91b5    changed     16.6
    200      201      99.61        7      255      255  97204825    changed     24.3
    239      240          0        1        0        0  62aa1dc5    changed     29.0
    241      242          0        1        0        0  62aa1dc5       same     29.1
    246      248        100        8      256      256  da2268df    changed     29.8
    250      251        100        8      256      256  da2268df       same     30.0
    255      256        100        8      256      256  da2268df       same     30.4
    260      262        100        8      256      256  f5d05e05    changed     30.8
    275      276       96.7       10      256      256  4c24864b    changed     31.7
    300      301       88.7       10      256      256  057f6add    changed     33.2
    450      451      88.38       11      256      256  47379605    changed     48.5
   1200     1201      90.28       13      256      251  a50eb20b    changed    140.0
   1500     1501      90.79       14      256      250  d904e224    changed    170.4
   3000     3001      92.19       14      252      256  a424170a    changed    372.6

final status: running mandel-oop.sfc · 256×224
player asset requests (gate 23 runtime proof — every one carries the content hash):
  https://biohack.net/play/app.js?v=fdb8b71ef465
  https://biohack.net/play/cores/bsnes_jg.js?v=54e19fd849b8
  https://biohack.net/play/roms/manifest.json?v=c8a28a93792b
  https://biohack.net/play/preview/mandel-oop.png?v=36f2fcdd3292
  https://biohack.net/play/cores/bsnes_jg.wasm?v=e74dbd3d7160
  https://biohack.net/play/cores/PROVENANCE.json?v=5927ba6e4126
  https://biohack.net/play/roms/mandel-oop.sfc?v=59a76c6f84a1
exit=0
```

```
status: ""  (+39988 ms after navigation)
FAIL: player never reached running
exit=1
```

**PASS on biohack; FAIL on indri as predicted** — indri's player never requests the ROM (the tracked `[wip T2]` indri player defect, not this plan's).

### 3. `node dev/m7web/filter123.mjs <out>`

```
STEP3 biohack {"total":141,"visible":141,"pressed":"false","ariaLabel":"Show Mode 7 demos only","count":"133 demos","url":""}
STEP4 biohack {"total":141,"visible":11,"pressed":"true","ariaLabel":"Show all demos","count":"11 Mode 7 demos","url":"?mode=7"}
STEP6 biohack {"total":141,"visible":141,"pressed":"false","ariaLabel":"Show Mode 7 demos only","count":"133 demos","url":""}
STEP5 biohack {"total":141,"visible":11,"pressed":"true","ariaLabel":"Show all demos","count":"11 Mode 7 demos","url":"?mode=7"}
STEP9 biohack {"tabsToReach":3,"focused":true,"focusVisible":true,"outline":"solid 2px rgb(194, 65, 12)","outlineOffset":"3px","tagName":"BUTTON","type":"button","pressedInitial":"false","pressedAfterKeyActivate":"true","labelAfterKeyActivate":"Show all demos","visible":11,"hiddenAttrUsed":true,"count":"11 Mode 7 demos","pressedAfterEscape":"false","focusReturnedToToggle":true,"countAriaLive":"polite","url":""}
STEP3 indri {"total":133,"visible":133,"pressed":"false","ariaLabel":"Show Mode 7 demos only","count":"133 demos","url":""}
STEP4 indri {"total":133,"visible":11,"pressed":"true","ariaLabel":"Show all demos","count":"11 Mode 7 demos","url":"?mode=7"}
STEP6 indri {"total":133,"visible":133,"pressed":"false","ariaLabel":"Show Mode 7 demos only","count":"133 demos","url":""}
STEP5 indri {"total":133,"visible":11,"pressed":"true","ariaLabel":"Show all demos","count":"11 Mode 7 demos","url":"?mode=7"}
STEP9 indri {"tabsToReach":15,"focused":true,"focusVisible":true,"outline":"solid 2px rgb(184, 239, 0)","outlineOffset":"3px","tagName":"BUTTON","type":"button","pressedInitial":"false","pressedAfterKeyActivate":"true","labelAfterKeyActivate":"Show all demos","visible":11,"hiddenAttrUsed":true,"count":"11 Mode 7 demos","pressedAfterEscape":"false","focusReturnedToToggle":true,"countAriaLive":"polite","url":""}
STEP10 biohack motion-ok       {"viewport":"320x640","reducedMotion":false,"toggle":{"w":121,"h":44,"minHeightOK":true,"touch44OK":true},"countBelowToggle":false,"countOnSameLine":true,"countOverflowsRight":false,"pageHorizontalOverflow":false,"filterApplied":11,"pressed":"true","count":"11 Mode 7 demos","visibleShelves":5,"arrowNavConsistent":true,"allScrollLeftZero":true,"toggleGeomUnchangedByActivation":true}
STEP10 biohack reduced-motion {"viewport":"320x640","reducedMotion":true,"toggle":{"w":121,"h":44,"minHeightOK":true,"touch44OK":true},"countBelowToggle":false,"countOnSameLine":true,"countOverflowsRight":false,"pageHorizontalOverflow":false,"filterApplied":11,"pressed":"true","count":"11 Mode 7 demos","visibleShelves":5,"arrowNavConsistent":true,"allScrollLeftZero":true,"toggleGeomUnchangedByActivation":true}
STEP10 indri motion-ok       {"viewport":"320x640","reducedMotion":false,"toggle":{"w":121,"h":44,"minHeightOK":true,"touch44OK":true},"countBelowToggle":false,"countOnSameLine":true,"countOverflowsRight":false,"pageHorizontalOverflow":false,"filterApplied":11,"pressed":"true","count":"11 Mode 7 demos","toggleGeomUnchangedByActivation":true}
STEP10 indri reduced-motion {"viewport":"320x640","reducedMotion":true,"toggle":{"w":121,"h":44,"minHeightOK":true,"touch44OK":true},"countBelowToggle":false,"countOnSameLine":true,"countOverflowsRight":false,"pageHorizontalOverflow":false,"filterApplied":11,"pressed":"true","count":"11 Mode 7 demos","toggleGeomUnchangedByActivation":true}
```

**PASS** — full output is in plan 123's 2026‑09‑14 record.

### 4. `dev/run.sh mandel-oop` + `bash dev/m7web/romgates.sh 0x897`

```
RESULT: PASS — mandel-oop OOP gate GREEN; corpus_result==0x204F on host == +mos-a16@bsnes-jg
SMOKE: PASS off=0x897 len=2 got=0x204F (ran 5800 frames, bsnes-jg)
    SHOT: PASS corpus=0x204F (snapshot at frame 5800)           # MAME
all-black intervals (dominant colour #000000 at >=99%): [(1, 50), (239, 243)]
```

**PASS** — full output is in plan 121's 2026‑09‑14 record.

### 5. `FRAMES=700 dev/m7blank.sh --gate`

```
gate: force-blank frames vs committed budget
demo               measured   budget  verdict
apollo-reel               5        6  ok
avalanche                 1        2  ok
blossom                   4        5  ok
buddha                    2        3  ok
julia                     1        2  ok
lzss-gallery            153      254  ok
mandel-display            1        2  ok
mandel-double             1        2  ok
mandel-float              1        2  ok
mandel-oop                5        6  ok
seamdemo                 20       21  ok
snes-video-reel           4        5  ok

PASS: every demo is within its post-title force-blank budget.
```

**PASS** — `mandel-oop` 5 ≤ 6.

### 6. Site worktree branches

```
$ git -C ~/biohack.net-m7rec log -1 --stat --format='%h %s'
e7f7d09 feat(snes): publish mandel-oop
 public/play/roms/mandel-oop.sfc | Bin 32768 -> 32768 bytes
 public/play/roms/manifest.json  |   4 ++--
$ git -C ~/biohack.net-m7rec status -sb | head -1
## snes/mandel-oop-republish

$ git -C ~/indri.studio-m7rec log -1 --stat --format='%h %s'
bc7d7cc feat(snes): publish mandel-oop
 public/apps/llvm-mos-65816/play/roms/mandel-oop.sfc | Bin 32768 -> 32768 bytes
 public/apps/llvm-mos-65816/play/roms/manifest.json  |   4 ++--
 src/data/snes-demos.ts                              |   4 ++--
$ git -C ~/indri.studio-m7rec status -sb | head -1
## snes/mandel-oop-republish

$ build/jgxcheck /home/will/biohack.net-m7rec/public/play/roms/mandel-oop.sfc vendor/bsnes-jg/Database 0x897 2 0x204F 5800
SMOKE: PASS off=0x897 len=2 got=0x204F (ran 5800 frames, bsnes-jg)
$ build/jgxcheck /home/will/indri.studio-m7rec/public/apps/llvm-mos-65816/play/roms/mandel-oop.sfc vendor/bsnes-jg/Database 0x897 2 0x204F 5800
SMOKE: PASS off=0x897 len=2 got=0x204F (ran 5800 frames, bsnes-jg)
```

**PASS** — exactly the republish files, no upstream, both staged ROMs latch `0x204F` at the manifests' new `0x897`.

### 7. Both plan files carry a "Verification record — 2026‑09‑14"

```
$ grep -n '^## Verification record — 2026-09-14' docs/plans/2026-07-26-121-*.md docs/plans/2026-07-26-123-*.md
```

**PASS** — see the grep output in the commit that lands this plan (both records present, every step verbatim and scored).
