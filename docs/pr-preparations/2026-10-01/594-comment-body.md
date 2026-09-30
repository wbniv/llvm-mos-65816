Hi @mlund, thanks for laying this foundation. I'm preparing 65816 far-data support for upstream ([#320 series](https://github.com/wbniv/llvm-mos-65816/blob/main/docs/pr-preparations/2026-09-30/split-320-321/REVIEWER-MAP-320.md)), and its first commit defines the same 32-bit imaginary register family as this PR: `sublo16`/`subhi16`, `MOSImagReg32`, `MaxImag32Regs`, `RL#I` and `Imag32`. Rather than send a competing copy, I'd like to build on #594.

Concretely, I'd propose:

1. **Land #594 as the shared foundation.** I'll rebase the far series onto it, keep your commit and authorship as they are, and adopt your numbering (`Imag16RegsOffset + MaxImag16Regs`) in place of ours.

2. **Make allocation follow your contract.** The far series needs `RL` to be allocatable, because it passes far pointers in `RL1`–`RL3`. I'd rather gate that on the SDK contract from your `imag32-contract` branch than on the CPU, and supply the declaration for the SNES platform, whose linker script we control and can guarantee contiguous four-byte imaginary registers. If the contract isn't close to landing, a fallback would be to enable allocation only for the 65816 until it is. Would either be acceptable? If you'd rather land the allocation step yourself, I'll build on that instead.

3. **Agree on one far address space.** The series uses `addrspace(2)` for far data: 32-bit pointers holding a 24-bit bank address, lowered to 65816 long addressing (`[dp]`, `[dp],Y`, long absolute). Since MEGA65 `[ptr],z` is on your list, it would be good to settle on one far address space that each target lowers its own way, before either lands.

Does that direction work for you (and @mysterymath)? The far support already drives a published SNES demo, the [LZSS gallery](https://biohack.net/snes/lzss-gallery/), which keeps its data in far memory.

This comment was drafted with Claude Code 2.1.285 (model `claude-opus-5-5`; reasoning effort not recorded) and reviewed by me before posting.
