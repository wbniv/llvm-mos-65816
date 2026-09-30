# Coordination comment for llvm-mos#594 (draft, not posted)

**Status:** drafted 2026‑10‑01 for the user to review. Posting is user-triggered.

**Why:** #320‑1 in the [#320/#321 split series](../2026-09-30/split-320-321/README.md) defines the same `Imag32`/`RL` register family as [llvm-mos#594](https://github.com/llvm-mos/llvm-mos/pull/594) (mlund, open draft, head `7b80f7e18768`, last updated 2026‑08‑19, no comments or reviews when read on 2026‑10‑01). The two differ on allocation and numbering. This is B7 of the [first independent review](../2026-09-30/far-word-rebase/independent-review.md), and the numbering is also B5. On 2026‑10‑01 the user chose option 1 from the [carry plan](../../plans/2026-10-01-far-prerequisite-split-carry.md#594-reconciliation-b7): build on #594 with mlund's credit, adopt its numbering, and add allocation separately. The user also asked for this comment to go out before filing.

**What #594 says about its own roadmap** (PR body, read 2026‑10‑01):
1. An SDK linker contract that identifies platforms with safe contiguous four-byte imaginary registers (branch `mlund/llvm-mos-sdk:imag32-contract`).
2. Allocation, spilling and i32 inline asm on top of that (branch `mlund/llvm-mos:imag32-inline-asm-v2`).
3. Far-pointer address spaces and instruction selection later, targeting MEGA65 `lda/sta [ptr],z` first, then possibly CX16 VRAM.

The comment therefore proposes gating allocation on mlund's contract, with the SNES platform declaring it, rather than on the CPU. It keeps a 65816-only gate as the fallback. It also raises the shared far address space, because MEGA65 far pointers are on mlund's list.

**Body:** [594-comment-body.md](594-comment-body.md), with one physical line per paragraph per AGENTS.md.

**Before posting:** re-read #594 live (`gh pr view 594 --repo llvm-mos/llvm-mos --comments`) and adjust the body if it has changed. Confirm that the REVIEWER-MAP-320 link and the LZSS gallery page resolve. `gh` needs a valid login first (`gh auth login -h github.com`).

**Post command:**

```bash
gh pr comment 594 --repo llvm-mos/llvm-mos --body-file docs/pr-preparations/2026-10-01/594-comment-body.md
```

**Suggested additions from implementing option 1 (2026‑10‑01, for the user to review; the body above is unchanged):**

- **#594 aborts on calls with stack arguments.** Applied to upstream `06bc967d2668` alone, #594 makes any function with a call that has stack arguments, such as a variadic call, abort in the register coalescer ("Invalid global physical register"), in every MOS CPU mode. A four-line variadic `main` reproduces it. The cause is that RL is not reserved over a reserved RS pair: LLVM counts a register unit as reserved only when all its super-registers are reserved, so the stack pointer's bytes stop being reserved. The #320 series carries #594 unchanged and fixes this in the next commit ([record](../../defects/mos-imag32-reserved-pair-units.json)). The comment could offer that fix to mlund for #594 itself.
- **The numbering lands inside the RS type range.** On the current base (after #571), `Imag16RegsOffset + MaxImag16Regs` gives RL numbers `0x30080 + K`, inside the RS "type 0x03" range of the MOS DWARF specification. The lldb MOS plugin knows only the RC and RS banks. The comment could ask whether the specification should define a separate bank for 32-bit imaginary registers.
- **#594 needs a one-token rebase.** `MOSImagReg32` takes `bits<16> num`; since #571, `MOSReg` numbers are 32 bits, and `0x30080` does not fit.

**After posting:** record the comment URL here and in [upstream-contribution-status.md](../../upstream-contribution-status.md). Implementing option 1 in the split series (carry #594 as #320‑1a, adopt its numbering, add allocation as #320‑1b) follows the second independent review, and is revised to match mlund's reply.

Drafted by Claude Code 2.1.285 orchestrator, model Claude Opus 5.5 (`claude-opus-5-5`); reasoning effort not recorded in session metadata.
