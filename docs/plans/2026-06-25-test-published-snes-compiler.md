# Plan — clean-room test of the *published* SNES compiler, wired into the publish gate

## Context

We publish the 65816 toolchain as a `.deb` on **apt.indri.studio** + a tarball, and a product page at
[indri.studio/apps/llvm-mos-65816](https://indri.studio/apps/llvm-mos-65816/) (interim, until #320/#321 land
upstream). Every test so far used the *local* `build/llvm-mos-install`. This plan tests the **published
artifact** the way a stranger would: take the compiler from the public/release path, compile a reference
program, **run it in an emulator, and check the result against a host oracle** — all in a throwaway Docker
container, with **no sound and no copyrighted BIOS**.

**This test is a publish gate, not an afterthought.** It runs on the freshly-built tarball **inside
`dev/package-release.sh`** (so *every* `task package` is clean-room-verified before the artifact can be
uploaded), and it can also re-run against the **live** apt repo / product-page link after deploy. A broken
build never reaches `release-upload`.

### The bar
`host(mandel-render over the program's grid) == published-compiler ROM @ bsnes-jg`, for **both** the default
(8-bit) and the `+mos-a16` build. For the reference program **`examples/snes/mandel-display.c`** (32×28,
N=15) the differential value is **`0x9103`** (CRC16 of the escape buffer, read back from WRAM
`corpus_result`). A pass proves the *published* compiler emits a correct, bootable, runnable ROM — and, as a
bonus, a real emulator-rendered **PNG** of the Mandelbrot.

### Two hard constraints (both satisfiable, verified)
1. **No sound / no APU.** The reference program must not touch the APU ($2140–$2143) or require the SPC700 to
   be initialised or to exist. Verified APU-free: `examples/snes/mandel-display.c`, `examples/65816/k_mandel.c`,
   `examples/65816/mandel.h`, `examples/snes/hello.c`.
2. **No BIOS.** **bsnes-jg embeds the SPC700 IPL** in its core (`vendor/bsnes-jg/src/smp.cpp`, 64-byte `const
   iplrom[]`) — it boots ROMs with zero external copyrighted input. (MAME *requires* `spc700.rom` and is
   therefore **excluded** from the clean-room test; it's an optional add for the full 4-way diff.)

## Reference program

**Primary: `examples/snes/mandel-display.c`** — the fixed-point Mandelbrot rendered ON the SNES: a 32×28
(DW×DH) escape grid, N=15 (DN), each cell a solid-colour 8×8 BG1 tile, so the BG tilemap *is* the image. It
`#include <snes.h>` (the published SDK header) and the shared `../65816/mandel.h` kernel — the SAME compute
the host renderer (`tools/mandel-render.c`) runs, so the on-screen image is the differentially-verified one.
`corpus_result` carries the escape-buffer CRC16 (WRAM read-back) as the proof channel. **No generated
headers.** Both default-8bit and `+mos-a16` must hit **`0x9103`**; `corpus_result` lives at WRAM **`0x580`**
(read from the `.map`, never hard-coded). The compute is heavy (896 cells × 15 iters × three 16×16→32
multiplies), so the CRC is settled after **~1800** emulated frames (same budget `dev/mandel-shot.sh` uses).

Host oracle: `tools/mandel-render.c`'s PNG path runs the IDENTICAL `mandel_fill(fb,32,28,15)` +
`mandel_crc(fb,896)` and prints `full-grid CRC16=0x9103` — a true cross-platform oracle (same `mandel.h`),
and it writes the host reference PNG for free. Grid params (DW/DH/DN) are scraped from the program source so
the oracle can't drift (the `dev/mandel-shot.sh` pattern).

**Secondary (optional, `PROGRAM=k_mandel`): `examples/65816/k_mandel.c`** — the smaller 16×10 N=12 gate grid;
host oracle `mandel-render --gate` → **`0x820B`**, ~200 frames. Kept as a fast alternative.

*(Not used: `mandel-interactive.c` — needs the gitignored baked `mandel_image.h`, absent from the shipped SDK.)*

## The test rig vs. the unit under test

- **Unit under test = the published compiler** — the relocatable tarball `task package` produces (and which
  the `.deb` repacks verbatim). The clean-room container must **not** see `build/llvm-mos-install`; it only
  ever sees `mos-snes-clang` from the extracted tarball (`local`) or the apt-installed
  `/usr/bin/mos-snes-clang` (`apt`).
- **Test rig (fixtures, baked into the rig image from this repo):** the reference `.c` + `mandel.h`, the host
  oracle `tools/mandel-render.c`, the emulator harness `dev/jgxcheck.cpp`, and a pinned `bsnes-jg` (built in
  the image, which also supplies its `Database/`). These are the rig, not the release.

## Three acquisition methods (the `METHOD` knob)

| `METHOD` | source of `mos-snes-clang` | when it runs |
|---|---|---|
| **`local`** (default) | the freshly-built `dist/llvm-mos-65816-*-linux-x86_64.tar.xz`, extracted in the clean container | **the publish gate** — invoked by `dev/package-release.sh` on every `task package`, *before* upload |
| **`apt`** | `apt-get install llvm-mos-65816` → `/usr/bin/mos-snes-clang` from the live repo | post-publish / periodic CI confirmation of the live consumer path |
| **`tarball`** | scrape the tarball URL off the live product page, download, extract | post-publish confirmation that the product-page download link works |

`local` is the artifact the `.deb` is a byte-for-byte repack of (apt's `build.sh` does `cp -a` the extracted
tree under `/usr/lib/llvm-mos-65816` and symlinks the `mos-*` drivers onto PATH), so a `local` pass gates the
exact bits that will go live; `apt`/`tarball` re-confirm the live endpoints after deploy.

## Design

### A. Test-rig image — *(new: `dev/Dockerfile.release-test`)*
Clean `ubuntu:26.04`, **no toolchain baked in**. Layers (heavy ones cached, fixtures last so editing them is
a cheap re-COPY):
- deps: `build-essential g++ libsamplerate0-dev pkg-config curl gnupg ca-certificates xz-utils`
- fetch (pinned `BSNES_VER=2.1.0`, sha256-checked — same pin as `dev/xcheck.sh`) + build `bsnes-jg`
  (`make ENABLE_STATIC=1 DISABLE_MODULE=1`) → static archive + its `Database/`. **Fetched in the image**, so
  the rig is reproducible from the repo alone (no dependency on a populated host `vendor/`).
- build `dev/jgxcheck.cpp` → `/opt/rig/jgxcheck`; copy `Database/` → `/opt/rig/Database`
- build the host oracle: `cc -O2 tools/mandel-render.c -o /opt/rig/mandel-render`
- copy the reference fixtures preserving the include layout: `/opt/rig/fixtures/snes/mandel-display.c`,
  `/opt/rig/fixtures/65816/mandel.h`, `/opt/rig/fixtures/65816/k_mandel.c` (so `#include "../65816/mandel.h"`
  resolves)

This keeps the per-run cost to *acquire-compiler + compile + run* (seconds), not a bsnes-jg rebuild. Build
context is the repo root with a `.dockerignore` excluding `vendor/`, `build/`, `dist/`, `.git` (only the
small tracked fixtures + the two `.cpp`/`.c` sources are sent).

### B. Runner — *(new: `dev/test-release.sh`, + `task release-test`)*
Host-side orchestrator. `set -euo pipefail`, `-h/--help`, env knobs:
`METHOD=local|apt|tarball` (default `local`), `A16=both|1|0` (default both),
`PROGRAM=mandel-display|k_mandel` (default `mandel-display`), `TARBALL=<path>` (for `local`; default = newest
`dist/*.tar.xz`), `FRAMES` (default per-program: 1800 / 200). It builds the rig image, then runs the
container **with no repo mount** (clean-room) — for `local` the chosen tarball is the only thing handed in
(read-only mount / `docker cp`), and an artifacts dir is mounted at `/out` for the PNGs/logs. Inside the
container, per (method × build):

1. **Sound-free assertion (cheap guard).** `grep -niE 'apu|spc|214[0-3]|sound|audio'` the program → must be
   empty. Documents the constraint in the test itself.
2. **Acquire the published compiler** (the consumer path) per `METHOD` (table above). Assert the resolved
   `mos-snes-clang` is **not** under any dev tree and that `build/llvm-mos-install` is absent (clean-room).
3. **Compile** the reference program with the acquired `mos-snes-clang` (default and/or `+mos-a16`):
   ```
   mos-snes-clang -Os -Wl,-Map=out.map -o out.sfc fixtures/snes/mandel-display.c             # default 8-bit
   mos-snes-clang -Xclang -target-feature -Xclang +mos-a16 -Os -Wl,-Map=… -o out-a16.sfc …    # +mos-a16
   ```
   Capture stderr; **fail on any warning** (same public-release bar as packaging).
4. **Host oracle:** scrape DW/DH/DN from the program, then
   `EXP=$('/opt/rig/mandel-render' /out/host.png $DW $DH $DN | grep -oE '0x[0-9A-Fa-f]{4}' | tail -1)`
   (≡ `0x9103` for mandel-display; `--gate` ≡ `0x820B` for k_mandel).
5. **Run + verify (bsnes-jg, headless, BIOS-free):** read `corpus_result`'s WRAM offset from the `.map`, then
   ```
   /opt/rig/jgxcheck out.sfc /opt/rig/Database 0x<off> 2 "$EXP" <frames> /out/mandel-<build>.png
   ```
   for each build; assert `SMOKE: PASS … got==EXP` for every one (and dump the emulator PNG).
6. **Report** a table: method × build → got vs EXP → PASS/FAIL; non-zero exit on any FAIL.

### C. Wiring into the publish gate — *(edit: `dev/package-release.sh`, `Taskfile.yml`)*
After `dev/package-release.sh` builds + checksums the tarball (and passes its warning-free self-test), it
runs the clean-room emulator test on **that exact tarball** as the FINAL gate:
```
dev/test-release.sh METHOD=local TARBALL="$DIST_DIR/$NAME.tar.xz"
```
Non-zero → `package-release.sh` exits non-zero and the tarball is **not** a publish candidate. This makes
"every publish is clean-room-verified" structural, regardless of entry point (`task package` or a raw
`dev/package-release.sh`). Override only for emergencies via `SKIP_RELEASE_TEST=1` (default: mandatory; if
Docker is unavailable the gate FAILS rather than silently skipping). `task package`'s description documents
the added gate.

## Order of execution
1. Add `.dockerignore`; write `dev/Dockerfile.release-test`; build the rig image once (bsnes-jg + jgxcheck +
   oracle + fixtures).
2. Write `dev/test-release.sh` + add `task release-test`.
3. Run `METHOD=local` against a freshly built `dist/*.tar.xz` (both builds) → expect `0x9103` × bsnes-jg = PASS.
4. Wire the `METHOD=local` gate into `dev/package-release.sh`; re-run `task package` end-to-end → tarball is
   built **and** clean-room-verified in one shot.
5. Run `METHOD=apt` (live repo) and `METHOD=tarball` (product-page link) → same `0x9103` PASS (post-publish
   confirmation).
6. (optional) Add a periodic CI `release-smoke` (`METHOD=apt`) catching a broken live publish; (optional) a
   MAME 4-way leg behind a supplied `spc700.rom` for the full differential (not default — needs the BIOS).

## Verification
1. `dev/test-release.sh METHOD=local` → output shows `host oracle: 0x9103`, then for default + `+mos-a16`:
   `SMOKE: PASS … got=0x9103`, and `/out/mandel-*.png` written. Paste output; assert final `PASS`.
2. `task package` → builds the tarball, passes the warning-free self-test, **then** runs the `METHOD=local`
   clean-room gate to `0x9103` PASS — all in one invocation; a forced failure (e.g. corrupt the tarball)
   makes `task package` exit non-zero.
3. `task release-test METHOD=apt` and `METHOD=tarball` → resolve the live repo / product-page tarball, same
   `0x9103` PASS.
4. **Clean-room check:** the container has no `build/llvm-mos-install`; the resolved `mos-snes-clang` is the
   extracted-tarball or `/usr/bin/...` path — i.e. the *published* compiler, not the dev build.
5. **Sound-free check:** the grep guard is empty; the run uses bsnes-jg with **no** `spc700.rom` present.
6. **Warning-clean:** the compile step emits zero clang/`ld.lld` warnings.

### Verification evidence (2026-06-25, all PASS)

Step 1 — `METHOD=local` on `dist/llvm-mos-65816-…c49f395-linux-x86_64.tar.xz`:
```
==> acquire the published compiler (METHOD=local)
  mos-snes-clang: /opt/published/.../bin/mos-snes-clang  -> /opt/published/.../bin/clang-23
==> host oracle (independent CRC over the same grid)
  grid 32x28, N=15 (scraped from the program)
  host reference: CRC16=0x9103  (/out/mandel-host.png)
  default-8bit   0x9103     0x9103   PASS
  +mos-a16       0x9103     0x9103   PASS
RESULT: PASS — the published compiler builds a correct, bootable ROM (METHOD=local)
```
PASS (artifacts: `build/release-test/mandel-{host,default,a16}.png`; emulator frames 256×224, will-owned).

Step 2 — `dev/package-release.sh` (the publish path) ran the gate after packaging:
```
==> clean-room gate: run the tarball's compiler output in bsnes-jg (METHOD=local)
  ... default-8bit 0x9103 PASS ; +mos-a16 0x9103 PASS ; RESULT: PASS
==> done  (warning-free self-test + clean-room emulator gate both PASSED)
```
PASS. Negative control: a corrupt tarball makes the gate exit non-zero —
```
negative-control exit=1 (NON-zero == gate correctly FAILED)
  default-8bit   ?          0x9103   FAIL(compile)
  +mos-a16       ?          0x9103   FAIL(compile)
RESULT: FAIL — see the per-build lines above
```
PASS (the gate actually gates).

Step 3 — `METHOD=apt` (live repo) and `METHOD=tarball` (live product-page link):
```
METHOD=apt:      apt install -> /usr/bin/mos-snes-clang ; default 0x9103 PASS ; +mos-a16 0x9103 PASS ; RESULT: PASS
METHOD=tarball:  scraped https://apt.indri.studio/sources/llvm-mos-65816_0.0.0+git20260625.c49f395.tar.xz
                 default 0x9103 PASS ; +mos-a16 0x9103 PASS ; RESULT: PASS
```
PASS (both live consumer paths).

Steps 4–6 — every run printed `clean-room check … OK — only the published compiler is reachable`,
`sound-free check … OK — no sound/APU references`, and `compiled warning-clean`. PASS.

## Reproducible / optional CI
- Everything is a `task` + committed script + a Dockerfile → reproducible from the repo; bsnes-jg is fetched
  pinned in the image layer.
- The `METHOD=local` gate is part of `dev/package-release.sh`, so the CI `package` job inherits the
  clean-room verification with no extra wiring.
- **Optional CI job** (`release-smoke` in `smoke.yml`, or a scheduled run): on a cadence, `task release-test
  METHOD=apt` against the live apt repo — catches a broken publish. bsnes-jg-only, so no BIOS secret needed.

## Open items / risks
- The reference fixtures (`mandel-display.c`, `mandel.h`, oracle, `jgxcheck`, bsnes-jg) come from **this repo**
  — that's the rig; the *compiler* is the published one. Documented so it's not mistaken for testing the local build.
- bsnes-jg build cost is paid once in the image layer; pinned to `2.1.0` (+sha256) so it can't churn.
- `mandel-display` needs ~1800 frames for the heavy compute before `corpus_result` settles; `k_mandel` ~200.
  `FRAMES` defaults per program.
- crt0 boot is sound-free (no APU handshake) — relied on so the ROM runs even where the SPC700 doesn't exist;
  re-confirm if the SNES platform crt0 changes.
- `METHOD=local` tests the **tarball**, which the `.deb` repacks byte-for-byte (apt `build.sh` `cp -a`s the
  extracted tree); the deb's own layout (`/usr/bin` driver symlinks) is exercised by `METHOD=apt` post-deploy
  and by the apt repo's own `task verify`.
