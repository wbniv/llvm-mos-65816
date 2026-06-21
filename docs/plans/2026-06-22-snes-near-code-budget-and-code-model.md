# SNES near-code budget assertion + the near/far "code model" framing

**Status:** DONE + verified (2026-06-22) · **Issue context:** #320 (24-bit address space) / SNES SDK target
**Supplements:** [`CLAUDE.md`](../../CLAUDE.md) + [`docs/agent-handoff.md`](../agent-handoff.md) (build/test mechanics).

## Context

The question that prompted this: *"should we have a compiler mode which limits the code generator to 64k
(maybe 32k on the SNES)? 32/64k of actual CODE is quite a lot for these systems."*

Two Explore passes over the backend + SDK established the answer is **mostly "you already have it, and it's
the right default"** — with one real gap worth closing:

- **The code generator already defaults to near/64k.** A normal call lowers to `JSR`/`RTS` (2-byte,
  within-bank); `CodeModel::Small` is the default (`MOSTargetMachine.cpp`); function pointers are 2-byte
  near. Far (`JSL`/`RTL`, 4-byte fn pointers, `address_space(2)`) is **strictly opt-in per symbol** via the
  `.far_*` section attribute / `far` attribute / typed `far_fn_t`. Evidence:
  `vendor/llvm-mos/llvm/lib/Target/MOS/MOSCallLowering.cpp` — `IsFar` is false (→ `JSR`/`RTS`) unless the
  callee's section starts with `.far_` **and** the target is W65816 (call site ≈ line 420, return ≈ line
  280). So "a mode that limits codegen to 64k" **describes the status quo**, and it would buy **no extra
  code-size win** — near calls are already the minimal form. It is a *contract*, not an optimizer.

- **The genuine gap is the *guarantee*, not the *generation*.** Nothing names or enforces the near-code
  budget. On the `snes` target (LoROM, single fixed bank $00) the real code window is **`$8000–$FFAF`
  (32 KiB minus the cartridge header at `$FFB0` and the vectors at `$FFE0`/`$FFF0`)**, but
  `platforms/snes/link.ld` declares `rom : … LENGTH = 0x8000` — the *full* bank. An over-budget build
  therefore does not fail with "code too big"; it trips an obscure overlap against the fixed-address
  `.snes_header` section. The "32k on the SNES" instinct is exactly the LoROM bank geometry.

**Outcome:** (1) make the near-code budget explicit and enforce it with a loud, byte-quantified link-time
error; (2) record the near = *small* / far = *medium-large* "code model" framing for the eventual #320
upstream discussion, plus the decision that **no `-mcmodel`-style codegen mode is warranted** (far is already
opt-in and per-symbol — finer-grained than a global switch).

**Scope decided with the user (2026-06-21):**
- The optional `-mno-far` / no-far guardrail is **skipped** — far is already strictly opt-in, nothing to
  guard until a concrete need appears.
- **No compiler / `vendor/` change.** This is a **linker-script + docs** change only → no
  `dev/run.sh toolchain` rebuild. That is the payoff of enforcing at link time rather than as a codegen mode.

## Part A — Near-code budget enforcement (the substantive change)

**Mechanism: carve the fixed-address header/vectors into their own `MEMORY` region so the code region's
`LENGTH` *is* the true near-code budget.** This hands high-water tracking (including the `.data` LMA init
image) to LLD's region allocator, which then emits a clear, byte-quantified, **region-named** overflow error
— exactly the "code exceeds the near window by N bytes" failure wanted — with zero compiler change and
**byte-identical ROM output** for any in-budget program.

In `platforms/snes/link.ld`:

- `rom : ORIGIN = 0x8000, LENGTH = 0x8000` → **`LENGTH = 0x7FB0`** (`$8000–$FFAF`: code/rodata/data window).
- Add **`romhdr : ORIGIN = 0xFFB0, LENGTH = 0x0050`** (`$FFB0–$FFFF`: header + native + emu vectors).
- Retarget the three fixed-VMA output sections `>rom` → `>romhdr`: `.snes_header` (`0xFFB0`),
  `.snes_vectors_native` (`0xFFE0`), `.snes_vectors_emu` (`0xFFF0`).
- `OUTPUT_FORMAT { FULL(rom) }` → **`FULL(rom) FULL(romhdr)`** — `0x7FB0 + 0x0050 = 0x8000`, contiguous, so
  the emitted 32 KiB headerless `.sfc` is unchanged.
- Add a comment naming the budget (`$8000–$FFAF`, 32688 B) so the `rom` region is self-documenting, with the
  remediation hint: an overflow means "move functions to `.far_text` (snes-far) or shrink".

Apply the **identical bank-$00 carve** to `platforms/snes-far/link.ld` (the two scripts are deliberately kept
in sync — see its header comment). Its far bank `rom_1` (`$018000–$01FFFF`) already holds
`.far_text`/`.far_rodata` in its own named region, so **no change is needed there** — its overflow is already
reported clearly as region `rom_1`.

*Optional sugar (only if cheap & reliable): a custom-message `ASSERT(... <= 0xFFB0, "…")`. The region carve is
the load-bearing enforcement; an ASSERT is sugar and must NOT be the only mechanism — `.data`'s VMA lives in
RAM, so a naive `. <= 0xFFB0` is unreliable across the opaque `rodata.ld`/`data.ld` includes. Prefer the
carve.*

## Part B — Docs: near/far "code model" framing + decision record

1. **Append a "Code model: near vs far" section** to `docs/320-upstream-far-pointer-note.md` (same topic,
   same upstream issue):
   - Near (`JSR`/`RTS`, 2-byte fn ptr, `CodeModel::Small`) is today's default; far is the #320 opt-in.
   - Map to the standard LLVM ladder for the upstream conversation: **`small` = all-near / single bank
     (today's default); `medium`/`large` = the #320 far story.**
   - **Decision: do not add a `-mcmodel`-style codegen mode.** Per-symbol far (`.far_*` / `far_fn_t`) is
     strictly finer-grained than a global switch — you pay the 4-byte/`JSL` tax only on symbols that cross
     banks; a whole-module knob would be coarser and buys no codegen shrink.
   - The 32k-LoROM / 64k-HiROM "near window" is **bank geometry**, enforced at link time (Part A), not a
     compiler flag.

2. **Pointer in `docs/upstream-contribution-status.md`**: the SDK-side linker budget assertion
   (llvm-mos-sdk concern) and the compiler-side code-model framing (llvm-mos #320 concern) as two distinct
   ready artifacts, each with where it lands. Mirror the one-line pointer in TODO's *Upstream / Contribution*
   section.

## Files to modify

- `platforms/snes/link.ld` — carve `romhdr`; shrink `rom` to `0x7FB0`; retarget header+vectors;
  `OUTPUT_FORMAT` `FULL(rom) FULL(romhdr)`; budget comment.
- `platforms/snes-far/link.ld` — identical bank-$00 carve (keep in sync); `rom_1` untouched.
- `docs/320-upstream-far-pointer-note.md` — append "Code model: near vs far" + the no-`-mcmodel` decision.
- `docs/upstream-contribution-status.md` — two artifact pointers.
- `TODO.md` — one entry + Upstream-section mirror line.

No `vendor/` edits → no toolchain rebuild.

## Verification

Numbered steps are the spec; paste raw output under each in a code block + PASS/FAIL when run. Run from the
repo root with the SDK built (`mos-snes.cfg` / `mos-snes-far.cfg` present).

1. **Output-neutral for in-budget programs (byte-identical ROM).** Capture one corpus program's linked `.sfc`
   on `main` HEAD; apply the link.ld change; rebuild; `cmp` the two → expect **identical** (the carve only
   relocates region boundaries that `FULL()` padding already filled). Also `dev/run.sh corpus` → expect
   **7/7** unchanged.

   ```
   byte-identical: 7 snes corpus ROMs + 5 snes-far ROMs (far-bank1/far-run/far_call/
     far_store/far_arith) all cmp-identical pre-carve vs post-carve — 12/12 ROMs, 0 diffs.
   dev/run.sh corpus  ->  7/7 passed
   ```
   **PASS** — the carve is output-neutral; every in-budget ROM is byte-identical (the region
   boundaries it moves were already `FULL()`-padded, so 0x7FB0 + 0x0050 reproduces the bytes).

2. **Far suite still links + runs (snes-far bank-$00 carve correct).** `dev/run.sh far_call`,
   `far_near_call`, `far-bank1` → expect existing PASS values (`far_near_call == 0xE0`, `far-bank1 == 0xF3`,
   …) on MAME (+ bsnes-jg where wired). Confirms `romhdr` + `rom_1` coexist and bank-$01 far placement is
   unaffected.

   ```
   far-bank1  RESULT: PASS — bank-$01 read == 0xF3            (ROM byte-identical)
   far-run    RESULT: PASS — far load+store in MAME == 0xF3   (ROM byte-identical)
   far_call   RESULT: PASS — JSL to bank $01 + RTL == 0xF3    (ROM byte-identical)
   far_store  RESULT: PASS == 0xF3   far_arith  RESULT: PASS == 0xF3
   ```
   **PASS** — the `snes-far` bank-$00 carve is correct; `romhdr` + `rom_1` coexist; bank-$01 far
   placement is unaffected. (`far_near_call` FAILS, but it is **PRE-EXISTING on clean main HEAD**,
   *not* this change: proven by stashing the carve + rebuilding the original `link.ld` → the test
   fails identically, the compiler emitting `jsr near_helper` (a near call) instead of
   `jsl __call_near_from_far`, so the thunk is gc-dropped. A link-time script cannot change
   compile-time instruction selection — unrelated codegen issue, out of scope here.)

3. **Overflow fails loudly with a clear, region-named, byte-quantified error.** Compile a deliberately
   oversized program against `snes` — an initialized `const` array large enough to push bank-$00 ROM past
   `$FFAF` (e.g. `const unsigned char big[0x7800] = { 1, … };` + normal `main`). Expect a link **error naming
   region `rom`** with the overflow byte count (`… will not fit in region 'rom'` / `region 'rom' overflowed
   by N bytes`) — **not** the old obscure `.snes_header` overlap message.

   ```
   $ mos-clang --config mos-snes.cfg -mcpu=mosw65816 -Os overflow_probe.c -o x.sfc
   ld.lld: error: section '.rodata' will not fit in region 'rom': overflowed by 206 bytes
   ld.lld: error: section .rodata virtual address range overlaps with .snes_header
   >>> .snes_header range is [0xFFB0, 0xFFDF]
   mos-clang: error: ld.lld command failed with exit code 1
   ```
   **PASS** — the **leading** error names region `rom` + the byte count (`overflowed by 206 bytes`):
   the clear "code exceeds the near window" diagnostic that was the whole point (the `.snes_header`
   overlap now follows as a *secondary* consequence rather than being the sole, obscure message).
   Note: the probe references its 0x8000-byte `const` array through a **`volatile` index** — a
   fully-known const array is constant-folded and gc-dropped by `-Os` and would not overflow.

4. **Docs preview.** `task md -- docs/320-upstream-far-pointer-note.md` and this plan render cleanly; all URLs
   in `[label](url)` form.

   ```
   task md -- docs/320-upstream-far-pointer-note.md  ->  320-upstream-far-pointer-note.html (89 KB), opened
   ```
   **PASS** — the #320 note (with the new "Code model: near vs far" section) + this plan render cleanly;
   all URLs in `[label](url)` form.

## Out of scope (explicit)

- **No `-mcmodel` / "limit codegen to 64k" compiler mode** — near is already the default and it buys no
  codegen win (recorded as a decision in Part B, not built).
- **No `-mno-far` guardrail** — user chose to skip; far is already opt-in per symbol.
- **`rom_1` far bank** in `snes-far` left as-is (already a clearly-named, overflow-checked region).
- **No compiler/`vendor/` edits** — linker-script + docs only.
