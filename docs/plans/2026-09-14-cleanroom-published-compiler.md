# Plan — clean-room re-verification of the *published* SNES compiler (2026‑09‑14)

**TODO item:** `[wip T3]` "Clean-room test of the *published* SNES compiler — wired into the publish gate"
(`TODO.md` ~L993). **Branch:** `wt/cleanroom-published-compiler` (plain worktree at
`/home/will/llvm-mos-65816-cleanroom`; no toolchain hardlinks needed — see *Rig* below).

## Context — the rig already exists; this plan is the delta

The item's deliverables were **implemented and verified on 2026‑06‑25/26** under
[`2026-06-25-test-published-snes-compiler.md`](2026-06-25-test-published-snes-compiler.md):

| Deliverable | File (all tracked on `main`) |
|---|---|
| Runner (host side) | `dev/test-release.sh` — knobs `METHOD=local\|apt\|tarball`, `PROGRAM`, `A16`, `TARBALL`, `FRAMES`, `NO_CACHE`; `-h/--help`; `set -euo pipefail` |
| In‑container driver | `dev/release-test-inner.sh` — acquire → clean‑room check → sound‑free check → oracle → compile → bsnes‑jg → result table |
| Rig image | `dev/Dockerfile.release-test` — `FROM ubuntu:26.04`, pinned bsnes‑jg 2.1.0 + `jgxcheck` + `mandel-render` oracle + fixtures; **no toolchain** |
| HTML report | `dev/release-report.py` → `build/release-test/release-report-*.html` (+ `-latest.html`) |
| Task wiring | `Taskfile.yml` `release-test` (→ `dev/test-release.sh {{.CLI_ARGS}}`) |
| Publish gate | `dev/package-release.sh` step 9 (L412–) runs `METHOD=local TARBALL=<fresh dist tarball>`; `SKIP_RELEASE_TEST=1` is the documented escape hatch, Docker‑absent = FAIL |

So there is **nothing to build**; the task brief's `dev/cleanroom-test.sh` is `dev/test-release.sh` (the name
the TODO item and the 2026‑06‑25 plan already fixed). Creating a second script would be a duplicate.

What *is* outstanding, and why the item is still `wip`:

1. The 2026‑06‑25 verification evidence records oracle **`0x9103`** for `mandel-display`. On 2026‑06‑26
   (`0034e3c`) the SNES Mandelbrot demos were collapsed into one far/16‑bit tester — `mandel-display.c` is now
   64×56 N=15, **`+mos-a16`‑only**, oracle **`0x204F`** — and the frame budget was raised 1800→5800
   (`ce96744`). The rig was updated in the same commits but **no run against the live published artifact has
   been recorded since**.
2. The **published artifact is stale relative to `main`.** Live today (2026‑09‑14):
   - apt: `llvm-mos-65816 0.0.0+git20260625.c49f395` (`pool/main/l/llvm-mos-65816/…_amd64.deb`,
     SHA256 `7ce8024302b2…3809`) from [apt.indri.studio](https://apt.indri.studio)
   - tarball: [`llvm-mos-65816_0.0.0+git20260625.c49f395.tar.xz`](https://apt.indri.studio/sources/llvm-mos-65816_0.0.0+git20260625.c49f395.tar.xz)
     (linked from the [product page](https://indri.studio/apps/llvm-mos-65816/))
   - `main` is at `294bc8c`; `git log c49f395..HEAD -- patches/` = **31 commits** (late‑opt CmpZero fix
     `6249aae`, ISR D/DBR envelope + a16 SBC carry‑in normalize `bd91729`/`357fe37`, …).

   The fixtures the rig compiles come from **this checkout** (`examples/snes/mandel-display.c` at HEAD), while
   the compiler is the **2026‑06‑25 build**. Two outcomes are possible and both are findings, not glitches:
   PASS (the published compiler still builds today's tester correctly → the 31 patch commits did not change
   observable behaviour on this program), or FAIL (compile error because the fixture now needs a later
   patch, or a CRC mismatch → a codegen defect fixed after `c49f395` that consumers are still shipping).

## What is fetched, from where

| `METHOD` | Source | What the container sees |
|---|---|---|
| `tarball` | `curl` the [product page](https://indri.studio/apps/llvm-mos-65816/), scrape the first `…/sources/llvm-mos-65816_*.tar.xz` link under [apt.indri.studio](https://apt.indri.studio), download, extract to `/opt/published` | `/opt/published/**/bin/mos-snes-clang` |
| `apt` | `curl $APT_URL/key.gpg` → `/etc/apt/keyrings/indri.gpg`; `deb [signed-by=…] $APT_URL stable main` (APT_URL = [apt.indri.studio](https://apt.indri.studio)); `apt-get install llvm-mos-65816` | `/usr/bin/mos-snes-clang` |
| `local` | bind‑mount the newest `dist/llvm-mos-65816-*-linux-x86_64.tar.xz` at `/artifact/src.tar.xz` (**the publish gate**) | `/opt/published/**` |

The **clean‑room check** (`release-test-inner.sh:129–139`) asserts the resolved `mos-snes-clang` realpath is
under the method's expected prefix and that nothing else on `PATH` resolves to a compiler — the container is run
with **no repo mount**, so this checkout's `build/llvm-mos-install` is unreachable by construction.

## Container base image

`ubuntu:26.04` (`dev/Dockerfile.release-test:FROM`). Packages baked in: `build-essential g++ make
libsamplerate0-dev pkg-config curl gnupg ca-certificates xz-utils` (to build bsnes‑jg + jgxcheck + the oracle
once, cached as image layers). No `llvm`, no `clang`, no `mos-*` anything.

## Programs and oracle (reused, not invented)

| `PROGRAM` | Fixture | Builds | Frames | Oracle (host `mandel-render`) |
|---|---|---|---|---|
| `mandel-display` (default) | `examples/snes/mandel-display.c` (+`mode7.h`, `sincos.h`, `../65816/mandel.h`) | `+mos-a16` only (forced when `A16=both`) | 5800 | `mandel-render mandel-host.png DW DH DN` → **`0x204F`** (DW/DH/DN parsed from the fixture) |
| `k_mandel` | `examples/65816/k_mandel.c` | default‑8bit **and** `+mos-a16` | 200 | `mandel-render --gate` → **`0x820B`** |

**Pass criterion:** for every build, `jgxcheck` boots the ROM in bsnes‑jg for `FRAMES` frames and reads the
2‑byte `corpus_result` at the address the linker map gives; it must equal the host oracle CRC. Plus: the
compile must be **warning‑clean**, the source **sound‑free** (no `$2140–$2143`/APU refs — bsnes‑jg's embedded
SPC700 IPL means no BIOS is needed), and the emulator PNG must be produced. Non‑zero exit on any FAIL.

The oracle is *the same* host program `dev/run.sh mandel-display` / `k_mandel` use against the dev‑built
toolchain, so "matches the dev‑built one" holds transitively: dev build == host oracle (the differential gate on
`main`) and published build == host oracle (this run).

## Gate wiring (unchanged; documented for the report)

`task package` → `dev/package-release.sh` → step 6 warning‑free self‑test → step 9
`dev/test-release.sh METHOD=local TARBALL=dist/<fresh>.tar.xz` → FAIL aborts packaging, the HTML report is
copied to `dist/<name>-release-report.html`. `apt`/`tarball` are **manual post‑deploy confirmations** (release
policy decided 2026‑06‑25: always test on release, no scheduled CI smoke). No change to release ordering is
needed, so **no ESCALATE**.

`METHOD=local` is **not** run in this plan: there is no `dist/` tarball on this box, and producing one means
`task package` → `release-builtins` + `release-sdk` → a toolchain/SDK rebuild in the **shared** `build/` of the
hot `main` tree — out of scope for a re‑verification on a non‑compiler worktree. The gate's own mechanics
(negative control included) are on record in the 2026‑06‑25 plan and its code is untouched since.

## Visible surface

None changed — the HTML report generator is untouched; this plan adds no UI. (No mockup section.)

## Rig defects found and fixed by this run (2026‑09‑14)

Both surfaced only because the run was executed for real against the live artifact; neither changes the gate's
semantics, both make it honest where it was silently wrong.

1. **Fixture include closure drifted → gate fails at compile for the wrong reason.**
   `mandel-display.c` gained `#include "snesgfx/m7title.h"` (→ `../font16.h`) on 2026‑07‑26 (`8ac159f`),
   but `dev/Dockerfile.release-test` hand‑listed only `mode7.h` + `sincos.h` (the June fix for the *previous*
   drift). First run: `fatal error: 'snesgfx/m7title.h' file not found`. Fix (`dev/Dockerfile.release-test:45–57`):
   copy the fixture's whole tracked header neighbourhood — `examples/snes/*.h`, `examples/snes/snesgfx/`,
   `examples/65816/*.h` (~7 MB, cheap layers after the bsnes‑jg build) — instead of a list that must be
   maintained by hand. `<snes.h>`/`<stdint.h>` still resolve from the *published* sysroot.
2. **A FAILING run produced no HTML report and no artifact trailer.** `dev/test-release.sh` ran
   `docker run … | tee "$LOG"` under `set -euo pipefail`; a non‑zero container made the pipeline non‑zero and
   `set -e` aborted the script *before* `rc=${PIPESTATUS[0]}` and the report step. The exit code was right by
   accident; the report — whose whole purpose is the failing publish gate — was missing. Fix
   (`dev/test-release.sh:88–106`): `set +e` bracket around the pipeline, capture `PIPESTATUS[0]`, `set -e`.
   Confirmed: the FAIL rerun writes `release-report-apt-20260914T093342Z.html` with the `badge fail">FAIL`
   verdict and the compile diagnostics embedded, and still exits 1.

Observation, not fixed: `release-test-<method>.log` is keyed on `METHOD` only, so a `PROGRAM=k_mandel` run
overwrites the same method's `mandel-display` log (the timestamped HTML/MD reports do not collide).
`dev/package-release.sh` reads only `release-report-latest.html` / `release-report-*-local-*.md`, so the gate is
unaffected; renaming the log would also mean touching the TODO item text, which this agent must not edit.

## Verification

Run from the worktree (`cd /home/will/llvm-mos-65816-cleanroom`). Each step: paste raw output, then PASS/FAIL.

1. `dev/test-release.sh --help` exits 0 and prints usage (house convention check).

    ```
    $ dev/test-release.sh --help; echo exit=$?
    Usage: dev/test-release.sh [KEY=VALUE ...]

    Clean-room test the published llvm-mos-65816 SNES compiler in a throwaway container.
    …
    exit=0
    ```
    PASS.

2. `dev/test-release.sh METHOD=tarball` — default `PROGRAM=mandel-display`, forced `+mos-a16`‑only; expect
   `clean-room check … OK`, `sound-free check … OK`, `compiled warning-clean`, `SMOKE: PASS … got=0x204F`,
   `RESULT: PASS`, and `build/release-test/{release-test-tarball.log,mandel-a16.png,mandel-host.png,release-report-*-tarball-*.html}`.

    Run 1 (rig as committed on `main`) — fixture drift, rig defect 1:
    ```
    clean-room release test  METHOD=tarball  PROGRAM=mandel-display  A16=1  FRAMES=5800
      started 2026-09-14T09:26:36Z  (host x86_64, 8 CPU; Ubuntu 26.04 LTS; bsnes-jg 2.1.0)
    ==> sound-free check (no APU / SPC700 / $2140-$2143)
    ==> acquire the published compiler (METHOD=tarball)
      scraping the tarball link off https://indri.studio/apps/llvm-mos-65816/
      -> https://apt.indri.studio/sources/llvm-mos-65816_0.0.0+git20260625.c49f395.tar.xz
      mos-snes-clang: /opt/published/llvm-mos-65816-20260625-c49f395-linux-x86_64/bin/mos-snes-clang  -> .../bin/clang-23
    ==> clean-room check (the dev build must be invisible)
    ==> host oracle (independent CRC over the same grid)
      host reference: CRC16=0x204F  (/out/mandel-host.png)
    ==> build + run: +mos-a16
      $ mos-snes-clang -Xclang -target-feature -Xclang +mos-a16 -Os -Wl,-Map=mandel-display-a16.map -o mandel-display-a16.sfc /opt/rig/fixtures/snes/mandel-display.c
      FAIL: compile error (exit 1):
        | /opt/rig/fixtures/snes/mandel-display.c:23:10: fatal error: 'snesgfx/m7title.h' file not found
        | 1 error generated.
      +mos-a16       ?          0x204F   FAIL(compile)
    RESULT: FAIL — see the per-build lines above
    exit=1
    ```
    Run 2 (after the Dockerfile fix) — the compiler is now reached and the verdict is about *it*:
    ```
    clean-room release test  METHOD=tarball  PROGRAM=mandel-display  A16=1  FRAMES=5800
      started 2026-09-14T09:28:55Z  (host x86_64, 8 CPU; Ubuntu 26.04 LTS; bsnes-jg 2.1.0)
    ==> sound-free check (no APU / SPC700 / $2140-$2143)
      OK — no sound/APU references
    ==> acquire the published compiler (METHOD=tarball)
      -> https://apt.indri.studio/sources/llvm-mos-65816_0.0.0+git20260625.c49f395.tar.xz
    ==> clean-room check (the dev build must be invisible)
      OK — only the published compiler is reachable
      host reference: CRC16=0x204F  (/out/mandel-host.png)
    ==> build + run: +mos-a16
      $ mos-snes-clang -Xclang -target-feature -Xclang +mos-a16 -Os -Wl,-Map=mandel-display-a16.map -o mandel-display-a16.sfc /opt/rig/fixtures/snes/mandel-display.c
      FAIL: compile error (exit 1):
        | In file included from /opt/rig/fixtures/snes/mandel-display.c:23:
        | /opt/rig/fixtures/snes/snesgfx/m7title.h:216:20: error: use of undeclared identifier 'NMITIMEN_NMI'
        | /opt/rig/fixtures/snes/snesgfx/m7title.h:216:35: error: use of undeclared identifier 'NMITIMEN_AUTOJOY'
        | /opt/rig/fixtures/snes/mandel-display.c:163:18: error: use of undeclared identifier 'NMITIMEN_NMI'
        | 3 errors generated.
    ==> result table  (METHOD=tarball  PROGRAM=mandel-display  oracle=0x204F)
      +mos-a16       ?          0x204F   FAIL(compile)
      finished 2026-09-14T09:29:04Z
    RESULT: FAIL — see the per-build lines above
    exit=1
    ```
    **FAIL — real finding, not a rig fault.** `NMITIMEN_NMI`/`NMITIMEN_AUTOJOY` are defined in
    `platforms/snes/snes_cpu.h:106` (the SDK sysroot's `<snes.h>` HAL split, commit `2d23b38`), which is
    **not an ancestor of the published `c49f395`** (`git merge-base --is-ancestor 2d23b38 c49f395` → no;
    7 commits touch `platforms/snes` in `c49f395..HEAD`). The published package's sysroot cannot compile
    today's reference program. Clean‑room, sound‑free and oracle steps all PASS; only the compile fails.

3. `dev/test-release.sh METHOD=apt` — same program; additionally the apt path installs to `/usr/bin`.
   Expect the same PASS lines and `release-test-apt.log`.

    ```
    clean-room release test  METHOD=apt  PROGRAM=mandel-display  A16=1  FRAMES=5800
      started 2026-09-14T09:30:31Z  (host x86_64, 8 CPU; Ubuntu 26.04 LTS; bsnes-jg 2.1.0)
      OK — no sound/APU references
      apt install llvm-mos-65816 from https://apt.indri.studio
      mos-snes-clang: /usr/bin/mos-snes-clang  -> /usr/lib/llvm-mos-65816/bin/clang-23
      OK — only the published compiler is reachable
      host reference: CRC16=0x204F  (/out/mandel-host.png)
      $ mos-snes-clang -Xclang -target-feature -Xclang +mos-a16 -Os -Wl,-Map=mandel-display-a16.map -o mandel-display-a16.sfc /opt/rig/fixtures/snes/mandel-display.c
      FAIL: compile error (exit 1):
        | /opt/rig/fixtures/snes/snesgfx/m7title.h:216:20: error: use of undeclared identifier 'NMITIMEN_NMI'
        | /opt/rig/fixtures/snes/snesgfx/m7title.h:216:35: error: use of undeclared identifier 'NMITIMEN_AUTOJOY'
        | /opt/rig/fixtures/snes/mandel-display.c:163:18: error: use of undeclared identifier 'NMITIMEN_NMI'
        | 3 errors generated.
      +mos-a16       ?          0x204F   FAIL(compile)
      finished 2026-09-14T09:30:53Z
    RESULT: FAIL — see the per-build lines above
    exit=1
    ```
    This first apt run ended with no `release-report:` line and no `==> compile log` trailer — rig defect 2.
    Rerun after the `dev/test-release.sh` fix:
    ```
      +mos-a16       ?          0x204F   FAIL(compile)
    RESULT: FAIL — see the per-build lines above
    release-report: wrote .../build/release-test/release-report-apt-20260914T093342Z.html (24 KiB) + release-report-apt-20260914T093342Z.md (1 screenshot(s), 1 doc(s))
    ==> compile log : .../build/release-test/release-test-apt.log
    ==> screenshots : .../build/release-test/mandel-host.png
    ==> report     : .../build/release-test/release-report-apt-20260914T093342Z.html
    exit=1
    ```
    `grep -o 'badge[^>]*>[^<]*FAIL' release-report-apt-20260914T093342Z.html` → `badge fail">FAIL`;
    `grep -c NMITIMEN_NMI` → 5 (diagnostics embedded).
    **FAIL on the compiler verdict (same stale‑SDK cause as step 2, via the `.deb` path, identical
    `0.0.0+git20260625.c49f395`); PASS on the rig now reporting a failure properly.**

4. `dev/test-release.sh METHOD=apt PROGRAM=k_mandel` — both builds (default‑8bit + `+mos-a16`) vs `0x820B`.

    ```
    clean-room release test  METHOD=apt  PROGRAM=k_mandel  A16=both  FRAMES=200
      started 2026-09-14T09:31:00Z  (host x86_64, 8 CPU; Ubuntu 26.04 LTS; bsnes-jg 2.1.0)
      OK — no sound/APU references
      apt install llvm-mos-65816 from https://apt.indri.studio
      mos-snes-clang: /usr/bin/mos-snes-clang  -> /usr/lib/llvm-mos-65816/bin/clang-23
      OK — only the published compiler is reachable
      host reference (gate): CRC16=0x820B
      $ mos-snes-clang -Os -Wl,-Map=k_mandel-default.map -o k_mandel-default.sfc /opt/rig/fixtures/65816/k_mandel.c
        | (no diagnostics — warning-clean)
      compiled warning-clean -> k_mandel-default.sfc (32768 bytes) [2026-09-14T09:31:24Z, 1s]
      SMOKE: PASS off=0x2A0 len=2 got=0x820B (ran 200 frames, bsnes-jg) [2026-09-14T09:31:31Z, 7s wall]
      $ mos-snes-clang -Xclang -target-feature -Xclang +mos-a16 -Os -Wl,-Map=k_mandel-a16.map -o k_mandel-a16.sfc /opt/rig/fixtures/65816/k_mandel.c
        | (no diagnostics — warning-clean)
      compiled warning-clean -> k_mandel-a16.sfc (32768 bytes) [2026-09-14T09:31:32Z, 1s]
      SMOKE: PASS off=0x2A0 len=2 got=0x820B (ran 200 frames, bsnes-jg) [2026-09-14T09:31:38Z, 6s wall]
      default-8bit   0x820B     0x820B   PASS
      +mos-a16       0x820B     0x820B   PASS
      finished 2026-09-14T09:31:38Z
    RESULT: PASS — the published compiler builds a correct, bootable ROM (METHOD=apt)
    release-report: wrote .../release-report-apt-20260914T093139Z.html (24 KiB) + release-report-apt-20260914T093139Z.md
    exit=0
    ```
    PASS. The same program via `METHOD=tarball` (run 2026‑09‑14T09:30:02Z) also PASSed both builds at
    `0x820B` (`release-report-tarball-20260914T093027Z.html`). So the published **codegen** — default‑8bit
    and `+mos-a16` — is still correct on the SDK‑independent Mandelbrot; the step‑2/3 failure is the SDK
    headers, not the compiler.

5. Record the published version stamp (`0.0.0+git20260625.c49f395`) vs `main` (`294bc8c`) and the
   `git log c49f395..HEAD -- patches/ | wc -l` count as the staleness finding, whatever the CRC outcome.

    ```
    apt Packages:  Package: llvm-mos-65816 / Version: 0.0.0+git20260625.c49f395
                   Filename: pool/main/l/llvm-mos-65816/llvm-mos-65816_0.0.0+git20260625.c49f395_amd64.deb
                   SHA256: 7ce8024302b2c2a732eed4eaf8f1dc2f3dfe2b896a4688ac9282545270743809
    product page:  https://apt.indri.studio/sources/llvm-mos-65816_0.0.0+git20260625.c49f395.tar.xz
                   https://apt.indri.studio/sources/llvm-mos-65816_0.0.0+git20260625.bff643e_linux-aarch64.tar.xz
    $ git rev-parse --short HEAD                                -> 294bc8c
    $ git log --oneline c49f395..HEAD -- patches/ | wc -l       -> 31
    $ git log --oneline c49f395..HEAD -- platforms/snes | wc -l -> 7
    $ git merge-base --is-ancestor 2d23b38 c49f395              -> NOT an ancestor
    ```
    Recorded. **Finding:** the live package is ~11 weeks behind `main` in both the compiler patch stack
    (31 commits, incl. the late‑opt CmpZero fix `6249aae`, the ISR D/DBR envelope `8f9a928`, the a16 SBC
    carry‑in normalize `357fe37`) and the SNES SDK headers (7 commits; the HAL split that today's examples
    depend on). Consumers on the published package cannot build the current `examples/snes/` set. Whether
    to cut a new release is a release‑ordering decision for the orchestrator — the gate itself needs no
    change: `task package` will run `METHOD=local` on the fresh tarball, whose sysroot *does* carry
    `snes_cpu.h`, so the `0x204F` leg becomes testable again the moment a release is built.

## Outcome

| Leg | Program | Builds | Verdict |
|---|---|---|---|
| tarball (live) | mandel-display | `+mos-a16` | FAIL(compile) — published SDK lacks `NMITIMEN_*` |
| apt (live) | mandel-display | `+mos-a16` | FAIL(compile) — same cause |
| tarball (live) | k_mandel | default‑8bit, `+mos-a16` | PASS `0x820B` × 2 |
| apt (live) | k_mandel | default‑8bit, `+mos-a16` | PASS `0x820B` × 2 |
| local (gate) | — | — | not run: no `dist/` tarball; building one is a shared‑tree toolchain rebuild (see above) |
