# Plan — clean-room test of the *published* SNES compiler release

## Context

We published the 65816 toolchain as a `.deb` on **apt.indri.studio** + a tarball, and a product page at
[indri.studio/apps/llvm-mos-65816](https://indri.studio/apps/llvm-mos-65816/) (interim, until #320/#321 land
upstream). Every test so far used the *local* `build/llvm-mos-install`. This plan tests the **published
artifact** the way a stranger would: fetch the compiler from the public endpoints, compile a reference
program, **run it in an emulator, and check the result against a host oracle** — all in a throwaway Docker
container, with **no sound and no copyrighted BIOS**.

### The bar
`host(mandel-render --gate) == published-compiler ROM @ bsnes-jg`, for **both** the default (8-bit) and the
`+mos-a16` build. The existing differential value is **`0x820B`** (CRC16 of the 16×10 gate grid). A pass
proves the *published* compiler emits a correct, bootable, runnable ROM.

### Two hard constraints (both satisfiable, verified)
1. **No sound / no APU.** The reference program must not touch the APU ($2140–$2143) or require the SPC700 to
   be initialised or to exist. Verified APU-free: `examples/65816/k_mandel.c`, `examples/65816/mandel.h`,
   `examples/snes/mandel-display.c`, `examples/snes/hello.c`.
2. **No BIOS.** **bsnes-jg embeds the SPC700 IPL** in its core (`vendor/bsnes-jg/src/smp.cpp`, 64-byte `const
   iplrom[]`) — it boots ROMs with zero external copyrighted input. (MAME *requires* `spc700.rom` and is
   therefore **excluded** from the clean-room test; it's an optional add for the full 4-way diff.) The
   project already has a `JG_ONLY=1` path that skips MAME's BIOS gate.

## Reference program

**Primary: `examples/65816/k_mandel.c`** — 16×10 fixed-point Mandelbrot (N=12), CRC16 → WRAM
`corpus_result`. Single `.c` + the shared `examples/65816/mandel.h` kernel; **no generated headers**,
**SDK-only**, APU-free, completes ~125 frames. Host oracle: `tools/mandel-render --gate` → `0x820B` (same
`mandel.h` kernel → a true cross-platform oracle). Both default-8bit and `+mos-a16` must hit `0x820B`.

**Optional visual upgrade: `examples/snes/mandel-display.c`** — 32×28 Mandelbrot rendered as a BG tilemap;
`jgxcheck` can also dump a framebuffer PNG (a human-viewable artifact) while asserting the same CRC channel.

*(Not used: `mandel-interactive.c` — needs the gitignored baked `mandel_image.h`, which isn't in the
shipped SDK.)*

## The test rig vs. the unit under test

- **Unit under test = the published compiler** (fetched fresh from apt.indri.studio / the tarball). The
  container must **not** see `build/llvm-mos-install`.
- **Test rig (fixtures, from this repo):** the reference `.c` + `mandel.h`, the host oracle
  `tools/mandel-render.c`, the emulator harness `dev/jgxcheck.cpp`, and `vendor/bsnes-jg` (source + its
  `Database/`). These are the rig, not the release.

## Design

### A. Test-rig image — *(new: `dev/Dockerfile.release-test`)*
Clean `ubuntu:26.04`, **no toolchain baked in**. Layers (all cached):
- deps: `build-essential g++ libsamplerate0-dev pkg-config curl gnupg ca-certificates xz-utils`
- build `bsnes-jg` + `dev/jgxcheck.cpp` → `/opt/rig/jgxcheck` (+ copy `vendor/bsnes-jg/Database`)
- build the host oracle: `cc -O2 -I examples/65816 -I tools tools/mandel-render.c -o /opt/rig/mandel-render`
- copy the reference fixtures (`k_mandel.c`, `mandel.h`, `mandel-display.c`)

This keeps the per-run cost to *fetch-compiler + compile + run* (seconds), not a bsnes-jg rebuild.

### B. Runner — *(new: `dev/test-release.sh`, + `task release-test`)*
`set -euo pipefail`, `-h/--help`, env knobs: `METHOD=apt|tarball` (default `apt`), `A16=1|0` (default: run
both), `PROGRAM=k_mandel|mandel-display` (default `k_mandel`), `FRAMES`. Runs the rig image and inside it:

1. **Acquire the published compiler** (the consumer path):
   - `METHOD=apt`:
     ```
     curl -fsSL https://apt.indri.studio/key.gpg | gpg --dearmor -o /etc/apt/keyrings/indri.gpg
     echo "deb [signed-by=/etc/apt/keyrings/indri.gpg] https://apt.indri.studio stable main" >/etc/apt/sources.list.d/indri.list
     apt-get update && apt-get install -y llvm-mos-65816      # -> mos-snes-clang on PATH
     ```
   - `METHOD=tarball`: scrape the tarball URL from the product page (so the test also exercises that link),
     download, extract, use `…/bin/mos-snes-clang`:
     ```
     url=$(curl -fsSL https://indri.studio/apps/llvm-mos-65816/ | grep -oE 'https://apt.indri.studio/sources/llvm-mos-65816_[^"]+\.tar\.xz' | head -1)
     curl -fsSL "$url" | tar -C /opt -xJ      # -> /opt/llvm-mos-65816-*/bin/mos-snes-clang
     ```
2. **Compile** the reference program with the fetched `mos-snes-clang` (default and/or `+mos-a16`):
   ```
   mos-snes-clang -Os -Wl,-Map=k_mandel.map -o k_mandel.sfc k_mandel.c            # default 8-bit
   mos-snes-clang -Xclang -target-feature -Xclang +mos-a16 -Os -Wl,-Map=… -o k_mandel-a16.sfc k_mandel.c
   ```
   Capture stderr; **fail on any warning** (same public-release bar as packaging).
3. **Host oracle:** `EXP=$('/opt/rig/mandel-render' --gate | grep -oE '0x[0-9A-Fa-f]{4}')`  (≡ `0x820B`).
4. **Run + verify (bsnes-jg, headless, BIOS-free):** read `corpus_result`'s WRAM offset from the `.map`,
   then
   ```
   /opt/rig/jgxcheck k_mandel.sfc /opt/rig/Database 0x<off> 2 "$EXP" 200   # SMOKE: PASS off=… got=0x820B
   ```
   Do this for each build; assert `got == EXP` for every one. (Optional `mandel-display`: pass a 7th arg to
   dump `mandel.png`.)
5. **Report** a table: method × build → got vs `0x820B` → PASS/FAIL; non-zero exit on any FAIL.

### C. Sound-free assertion (cheap guard)
Before compiling, `grep -niE 'apu|spc|214[0-3]|sound|audio'` the chosen program → must be empty. Documents
the constraint in the test itself; bsnes-jg's embedded IPL means the SPC700 is never externally required.

## Order of execution
1. Write `dev/Dockerfile.release-test`; build the rig image once (bsnes-jg + jgxcheck + oracle).
2. Write `dev/test-release.sh` + add `task release-test`.
3. Run `METHOD=apt` (both builds) → expect `0x820B` × bsnes-jg = PASS.
4. Run `METHOD=tarball` (scrapes the product-page link) → same.
5. (optional) Add `mandel-display` + PNG artifact; (optional) a MAME 4-way leg behind a supplied
   `spc700.rom` for the full differential (not default — needs the BIOS).

## Verification
1. `task release-test METHOD=apt` → output shows `host oracle: 0x820B`, then for default + `+mos-a16`:
   `SMOKE: PASS … got=0x820B`. Paste output; assert final `PASS`.
2. `task release-test METHOD=tarball` → resolves the product-page tarball link, same `0x820B` PASS.
3. **Clean-room check:** the container has no `build/llvm-mos-install`; `which mos-snes-clang` points at the
   apt-installed `/usr/bin/...` (or the extracted tarball) — i.e. the *published* compiler, not the dev build.
4. **Sound-free check:** the grep guard is empty; the run uses bsnes-jg with **no** `spc700.rom` present.
5. **Warning-clean:** the compile step emits zero clang/`ld.lld` warnings.

## Reproducible / optional CI
- Everything is a `task` + committed script + a Dockerfile → reproducible from the repo.
- **Optional CI job** (`release-smoke` in `smoke.yml`, or a scheduled run): on a cadence, `task release-test
  METHOD=apt` against the live apt repo — catches a broken publish. bsnes-jg-only, so no BIOS secret needed.

## Open items / risks
- The reference fixtures (`k_mandel.c`, `mandel.h`, oracle, `jgxcheck`, bsnes-jg) come from **this repo** —
  that's the rig; the *compiler* is the published one. Document so it's not mistaken for testing the local build.
- bsnes-jg build cost is paid once in the image layer; if it churns, pin the `vendor/bsnes-jg` commit.
- `mandel-display` on bsnes-jg needs enough frames for the BG fill (~1800 in `dev/mandel-shot.sh`); `k_mandel`
  needs ~200. Tune `FRAMES` per program.
- crt0 boot is sound-free (no APU handshake) — relied on so the ROM runs even where the SPC700 doesn't exist;
  re-confirm if the SNES platform crt0 changes.
