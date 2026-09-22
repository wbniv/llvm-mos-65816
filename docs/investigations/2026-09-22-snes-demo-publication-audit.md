# SNES demo publication audit — 2026-09-22

- [x] Compare local demo sources against both repositories and both live manifests.
- [x] Rebuild and pass every missing demo's own emulator gate (19/19; no skips).
- [x] Stage matching ROMs, previews, fidelity metadata, and pages on both sites.
- [x] Pass site tests, builds, engine drift checks, and paired artifact checks.
- [x] Complete browser fidelity checks for all new pages on both builds (38/38 pass).
- [x] Publish both tag-triggered site releases.
- [x] Verify deployed pages, ROM hashes, previews, and both gallery inventories (38/38).

Both live manifests contained the same 133 demos at the start of the audit. The 19 entries below bring each gallery to 152. The existing 133 manifest records retain their values and ordering. Indri serves Blossom at `/blossom/`, so its generic SNES directory contains 151 demo pages plus the dedicated Blossom page.

| # | Demo | biohack.net | indri.studio | Fidelity CRC | Frames |
| --- | --- | --- | --- | --- | --- |
| 116 | Backtracking Solver (`backtrack`) | [Play](https://biohack.net/snes/backtrack/) | [Play](https://indri.studio/apps/llvm-mos-65816/snes/backtrack/) | `0x7336` | 600 |
| 117 | Callee-Saved Restore Curve (`csrjmp`) | [Play](https://biohack.net/snes/csrjmp/) | [Play](https://indri.studio/apps/llvm-mos-65816/snes/csrjmp/) | `0xADD8` | 600 |
| 118 | Retry-On-Fault Ladder (`retryjmp`) | [Play](https://biohack.net/snes/retryjmp/) | [Play](https://indri.studio/apps/llvm-mos-65816/snes/retryjmp/) | `0x3388` | 600 |
| 139 | IRQ Gate (`irqgate`) | [Play](https://biohack.net/snes/irqgate/) | [Play](https://indri.studio/apps/llvm-mos-65816/snes/irqgate/) | `0x24F6` | 500 |
| 141 | Bank/Direct-Page Windows (`dpbank`) | [Play](https://biohack.net/snes/dpbank/) | [Play](https://indri.studio/apps/llvm-mos-65816/snes/dpbank/) | `0x4D5F` | 500 |
| 142 | ISA-256 Bytecode Machine (`jt256`) | [Play](https://biohack.net/snes/jt256/) | [Play](https://indri.studio/apps/llvm-mos-65816/snes/jt256/) | `0xB8CC` | 600 |
| 143 | Run-Length Scanline Decoder (`vlastack`) | [Play](https://biohack.net/snes/vlastack/) | [Play](https://indri.studio/apps/llvm-mos-65816/snes/vlastack/) | `0xD77B` | 600 |
| 144 | Reservoir Ladder (`borrowov`) | [Play](https://biohack.net/snes/borrowov/) | [Play](https://indri.studio/apps/llvm-mos-65816/snes/borrowov/) | `0x81FB` | 600 |
| 145 | Affine Stage Pipeline (`bigbyval`) | [Play](https://biohack.net/snes/bigbyval/) | [Play](https://indri.studio/apps/llvm-mos-65816/snes/bigbyval/) | `0xBD6B` | 600 |
| 146 | Precision Bridge (`dblbridge`) | [Play](https://biohack.net/snes/dblbridge/) | [Play](https://indri.studio/apps/llvm-mos-65816/snes/dblbridge/) | `0xF829` | 2200 |
| 147 | Bisection Oracle (`bsearchviz`) | [Play](https://biohack.net/snes/bsearchviz/) | [Play](https://indri.studio/apps/llvm-mos-65816/snes/bsearchviz/) | `0x7FF5` | 600 |
| 148 | Lexicographic Race (`strcmprace`) | [Play](https://biohack.net/snes/strcmprace/) | [Play](https://indri.studio/apps/llvm-mos-65816/snes/strcmprace/) | `0xF0BA` | 600 |
| 149 | Unaligned Record Reader (`packrec`) | [Play](https://biohack.net/snes/packrec/) | [Play](https://indri.studio/apps/llvm-mos-65816/snes/packrec/) | `0x4676` | 600 |
| 150 | Unreachable Sentinel (`trapguard`) | [Play](https://biohack.net/snes/trapguard/) | [Play](https://indri.studio/apps/llvm-mos-65816/snes/trapguard/) | `0x2C2D` | 600 |
| 151 | Nested VLA Pyramid (`vlanest`) | [Play](https://biohack.net/snes/vlanest/) | [Play](https://indri.studio/apps/llvm-mos-65816/snes/vlanest/) | `0x153B` | 600 |
| 152 | Jump-Table Boundary Sweep (`jtedge`) | [Play](https://biohack.net/snes/jtedge/) | [Play](https://indri.studio/apps/llvm-mos-65816/snes/jtedge/) | `0xC199` | 600 |
| 153 | Sparse Switch Ladder (`jtsparse`) | [Play](https://biohack.net/snes/jtsparse/) | [Play](https://indri.studio/apps/llvm-mos-65816/snes/jtsparse/) | `0xA131` | 600 |
| 154 | By-Value Boundary Trio (`byvaledge`) | [Play](https://biohack.net/snes/byvaledge/) | [Play](https://indri.studio/apps/llvm-mos-65816/snes/byvaledge/) | `0x4FAB` | 600 |
| 155 | Overflow Family Matrix (`ovmatrix`) | [Play](https://biohack.net/snes/ovmatrix/) | [Play](https://indri.studio/apps/llvm-mos-65816/snes/ovmatrix/) | `0xD4D0` | 600 |

## Inventory accounting

Published aliases: `wireframe` → `3d-wireframe`; `buddha` → `buddhabrot`; `invaders` → `space-invaders`; `cartsize-canary` → the cartridge-size variants; `apollo-reel` → `apollo-daylight`; `snes-video-reel` → `svx2-fastrom-video`.

Non-gallery sources: `hello` is a smoke program; `snes-video-codec-bench` is a benchmark; `snes-video-codec`, `snes-video-dma`, and `snes-video-stream` are companion translation units. Build-directory corpus and compiler-probe ROMs are not separate rendered demos.

## Validation

The 19 `dev/<slug>.sh` gates were run inside `llvm-mos-65816-dev`. Seventeen include bsnes-jg and MAME checks. `irqgate` and `dpbank` check the default, accumulator-16, and index-16 builds with repeated bsnes-jg runs; the freshly tested accumulator-16 artifacts are the published versions. All gates passed without skipped checks.

Both sites carry the exact tested ROM bytes. Preview images were inspected together. Precision Bridge requires 2,200 fidelity frames; IRQ Gate and Bank/Direct-Page Windows use 500; the other 16 use 600. WRAM offsets come from the matching link maps.

Biohack: 47 tests passed, one skipped; 165 pages built. Indri: 11 tests passed; 172 pages built. Both engine bundles match `@wbniv/bsnes-jg-player@1.1.0`. Biohack's link, page-count, fullscreen, Thailand contrast, and Thailand interaction checks passed.

Local evidence is under `build/publish-all-snes/`: `inventory.json`, `gates.json`, individual `*.gate.log` files, `release.json`, `paired-artifacts.log`, site test/build logs, and browser fidelity reports/screenshots.

All 38 new pages passed the browser fidelity check with the expected CRC and a rendered 256×224 canvas; no JavaScript exceptions were reported. Precision Bridge needs more than the initial 90-second harness limit to execute all 2,200 frames, so its allowance scales with the required frame count. Both completed runs match `0xF829`.

## Artifact hashes

| ROM | SHA-256 |
| --- | --- |
| `backtrack.sfc` | `b5cb508d58345abf5c6b5001682a332c01bf57e57c5cb2bf897763cf545da79e` |
| `csrjmp.sfc` | `25456b9a64331883111a2067e06e45d58cb94c2c1a88afabad9db102f6d9a612` |
| `retryjmp.sfc` | `471edb0c58cbd2ffa89628bf8d3a7071a25b04d200c47d56e57dd2342856ccd4` |
| `irqgate.sfc` | `ec81409a0fe9958153fda1c37f5b4de07cb5701c0aaecc8a636454ac7c3b44d3` |
| `dpbank.sfc` | `116b26e3b314f4650d0c1154d0accd7194d3491273c3d9057352abb02d5a7217` |
| `jt256.sfc` | `66608967ed531702779221467ebc0a8c18e477c78ba014441fb6166ff86b2b2a` |
| `vlastack.sfc` | `8a5148b5e5fd8480902afe22069d5ed1dbeb24c1d2153fe604cfa6c214ea93dc` |
| `borrowov.sfc` | `5850331657bc8e74a1e8895720a102d0ee04ab417309ce4f9222ba3124c10899` |
| `bigbyval.sfc` | `227162ded9f7ebe50e51dfd7896b42689ed49b793e2619a4dc7325827f73cbb0` |
| `dblbridge.sfc` | `a48bafaf66a404b7e935e2ae480bebfb3ceb53ed53ebdd76ab27e645f853aa74` |
| `bsearchviz.sfc` | `63ce9ab2fad3f3ae72342acef274d85737e1f0182d3f7149d68b6219611eb81f` |
| `strcmprace.sfc` | `e59dc86cf4246b8eefece8cc0da1ceac233b293a8a106bf1e89aaaa120d815b5` |
| `packrec.sfc` | `11f71eb4ca244989175cd4e43472dc970fe144e280c5bce86faef84cc336df5b` |
| `trapguard.sfc` | `76550288d216c150114c436a984418a6e5476ad24abec1db6d3adc2aaf961ece` |
| `vlanest.sfc` | `ddaca5fe3856cc4baf1e2e3ae5705a6277dc4679e8b461d83cbae2a5f08699f8` |
| `jtedge.sfc` | `e8aaf1eb08e1f84d7f453e597a1dd566363aa1a7fee3ee0aa7ad462db09d1e3c` |
| `jtsparse.sfc` | `b486e9768187acd06235c6bd5e4677cc49e3125fae51d464b2eb67f9c4873c22` |
| `byvaledge.sfc` | `15fce450324545fce95f2e2170bab52b94ea521bb61ed9ccbd6bd39cf7f8ff41` |
| `ovmatrix.sfc` | `d674eb730c8c25d28b8d1fc8a4367194217bee52b75763b3027e395b024e6edb` |

## Releases

| Site | Commit | Release | Deployment |
| --- | --- | --- | --- |
| biohack.net | `0c067a13b5e6eb0f8131610ac96f75b8579fbddd` | `v1.0.599` | [GitHub Actions](https://github.com/wbniv/biohack.net/actions/runs/35681336505) |
| indri.studio | `62b4727807cbfd8b483da04e8b16bc3b860bdb77` | `v0.1.158` | [GitHub Actions](https://github.com/wbniv/indri.studio/actions/runs/35681337615) |

Both Cloudflare deployment steps succeeded. All 38 new live pages, ROM SHA-256 values, and preview bytes were verified. Both live 152-entry manifests and player engines match the tested builds. By-Value Boundary Trio also passes its live browser check on each site with `0x4FAB`. Evidence: `build/publish-all-snes/live-check.json`, `browser-live.json`, and `*-byvaledge-live.png`.

Both original sibling checkouts were fast-forwarded to the publication commits. All 21 pre-existing local file states were verified unchanged.

## By-Value Boundary Trio title follow-up

The ROM title card now reads `BY-VALUE` / `BOUNDARY TRIO`, and the running HUD uses `BY-VALUE`. The corrected source is commit `707ef7f73cd09e721e52d230063197b10279fc6c`. The website typography was not changed.

- [x] Title screenshot inspected and title-character gate passed.
- [x] bsnes-jg and MAME pass CRC `0x4FAB` at 600 frames; ABI checks pass in all three local modes.
- [x] Site assets committed and pushed: biohack.net `b4803d3` (`v1.0.600`), indri.studio `c8371a3` (`v0.1.159`).
- [x] Verify both deployed ROM/preview hashes and browser fidelity checks (`0x4FAB` on both sites).

The updated ROM SHA-256 is `ba0697c56a43baf730ebee14d3caa452c163f08c65cb47894ee44026ed2ad6d7`; this supersedes the initial-release hash in the table above. Evidence is in `build/byvaledge-title-fix/`.

Preview verification uses the content-hashed URLs emitted by each live gallery, because `/play/` assets are cached as immutable. Both live gallery URLs select the corrected preview.
