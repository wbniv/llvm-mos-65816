<!-- ───────────────────────────── STATUS / METADATA (strip before posting) ─────────────────────────────
Upstream artifact: #321 calling-convention design note — measured frame-ABI evaluation.
Type: discussion post / note (NOT a PR, NOT a code change). Posting is USER-TRIGGERED.
Venue: issue #321 comment, and/or the llvm-mos Discord CC thread (@mysterymath / @asiekierka).
Post command (strip this status block first):
    gh issue comment 321 --repo llvm-mos/llvm-mos --body-file docs/321-upstream-cc-frame-abi-note.md
Internal sources: docs/plans/2026-06-20-321-frame-abi-build-all-three-and-measure.md (§Outcome),
  docs/plans/2026-06-18-321-cc-frame-phased-decision.md, dev/frameabi-census.sh, examples/65816/frameabi_a0.c.
Queued in: docs/upstream-contribution-status.md (Ready to post now #6).
─────────────────────────────────────────────────────────────────────────────────────────────────── -->

# llvm-mos #321 — which stack-frame ABI for the 65816 C calling convention? A measured answer

*Before proposing a calling convention for the 65816, we evaluated whether a per-frame hardware-stack model
— the kind WDC816CC and ORCA/C use — would actually beat llvm-mos's existing soft static stack. In the
project's code-first spirit: we built the feasibility proof, measured the opportunity on real code, and the
answer is **keep the soft static stack — by measurement, not by default.** Sharing the method and the
non-obvious reason, since it bears on any 65816 ABI discussion.*

Repo / working branch: **[wbniv/llvm-mos-65816](https://github.com/wbniv/llvm-mos-65816)** — the evaluation is
host-side + dual-emulator (MAME + bsnes-jg); reproducible via `dev/frameabi-census.sh` and
`dev/run.sh frameabi_a0`.

---

## TL;DR

- **Question.** For locals/frames, should the 65816 C ABI move to a per-frame **TCD direct-page window**
  (`tsc;[sbc;tcs;]phd;tcd` … `pld`, locals via 8-bit DP-offset) or **hardware-stack-relative** (`offset,S`),
  instead of llvm-mos's **soft static stack** (locals in fixed zero-page `__rc*` imaginary registers)?
- **Feasible — yes.** The non-obvious blocker is real but surmountable: the linker fixes `__rc0..31` at ZP
  `$00–$1F`, and 65816 zero-page addressing is **direct-page-relative**, so the instant a DP window sets
  `D≠0`, every `lda __rcN` silently retargets. A DP-window function must therefore reach `__rc` via
  **absolute** addressing (`DBR:addr`, ignores `D`). Verified on hardware emulators: a function at `D=$1000`
  reads a DP frame-local *and* an `__rc` cell (via absolute) correctly — `corpus_result == 0xBBAA` on MAME
  **and** bsnes-jg.
- **But worthless on real code — NULL.** We measured the *opportunity* per function (corpus + 6 kernels,
  `-Os`, 16-bit-accumulator ambient): **0 of 13 functions** would benefit from *either* alternative. Reason:
  llvm-mos keeps locals **register-resident in the imaginary-register file**, and routes local
  arrays/buffers/structs through a **pointer in `__rc`** (`lda (__rc),y`) — even `&local` lands in `__rc`
  (imaginary registers are addressable zero page). So static-stack/spill traffic is ≈0. A per-frame window
  has nothing to optimize and would only **tax** the abundant `__rc` accesses.
- **The ask / takeaway.** The soft static stack is the right first-pass CC frame model for the 65816 —
  *measured*, not assumed. This is also why the textbook commercial DP-frame doesn't transplant onto
  llvm-mos: those ABIs have no global ZP imaginary-register file; llvm-mos's does, and it's the competitive
  advantage that makes frames nearly free.

---

## Method

**Cost model (per function), deliberately generous to the alternative:**

| Access kind | soft static stack (today) | DP-window | Δ |
|---|---|---|---|
| spilled / frame local | 4-byte long (`R_MOS_ADDR24`) | 2-byte DP | **−2 B (win)** |
| `__rc` imaginary register | 2-byte DP | 3-byte absolute | **+1 B (tax)** |
| per call | none (non-reentrant ⇒ no hw-stack traffic) | `tsc;[sbc;tcs;]phd;tcd … pld` | **+~8 B** |

`gain = 2·Nspill − 1·Nrc − 8`, profitable iff `> 0`. `Nspill`/`Nrc` are counted directly from
`llvm-objdump -dr` relocations (`.noinit..Lstatic_stack` vs `R_MOS_ADDR8 __rc*`).

**Result (realistic code — the verdict):**

```
function          Nspill   Nrc   gain
arith.c:main           0    89    -97   loses
arrays.c:main          9    12     -2   loses   (spill-heaviest; still loses)
k_isort.c:main         5    50    -48   loses
... (all 13 lose; 11/13 have Nspill = 0) ...
SUMMARY: 0 / 13 profitable
```

**Winning boundary (synthetic stress).** Only *atypical* shapes profit — `volatile` locals and
constant-indexed local-array shuffles with near-zero arithmetic (spill-heavy, `__rc`-light). Realistic-style
stress (address-taken scalars, loop buffer-copy, struct field-shuffle, in-place reverse) **all lose with
`Nspill = 0`** — they go through a pointer in `__rc`, not the static stack. Realistic compute doesn't produce
the winning pattern.

**Feasibility proof.** `examples/65816/frameabi_a0.c` (hand-encoded) enters `D=$1000`, writes a frame local
via DP (`$10`→`$1010`), and — while `D≠0` — reads the `__rc16` cell via absolute (`$0010`); a correct
DP-vs-absolute split yields `0xBBAA`, a collision would yield `0xBBBB`. Both emulators agree.

## Conclusion

Pure hardware-stack-relative was a priori the weakest (limited `,S` instruction coverage → still stages
through `A`); the direct-page window is the strongest alternative and it is *dominated on this workload*. So
both are shelved and the **soft static stack stands** as the first-pass CC frame model. If a future target
ships frame-heavy code (large/`volatile`/address-pinned locals dominating register-resident temporaries), the
census (`dev/frameabi-census.sh`) is the cheap re-check — but the structural point holds: optimizing frames
only pays when frames are used, and llvm-mos's imaginary-register model means they largely aren't.

*(Reproduce: `dev/frameabi-census.sh` for the per-function census; `dev/run.sh frameabi_a0` for the
DP/absolute coexistence proof on both emulators.)*
