# DMA source-address upstream audit

**Decision:** refuted — no compiler defect and no upstream submission

## Original incident

The corrupted visible proof was built in the work leading to commit `5038454`. Its C presentation
assigned DMA source bytes from a linked framebuffer address after calling
`svx_decode_payload_asm`. The generated code materialized the linked low-byte relocation before the
call, preserved it in a compiler spill, and reloaded it afterward. The handwritten decoder reused
`__rc0` as a packet cursor without preserving it. In the 65816 configuration `__rc0/__rc1` are the
software-stack pointer, so the reload's textual stack-relative load correctly used the stack base
but observed the wrong address after the callee corrupted that base.

The corrective source, disassembly conclusion, flags, 4,480-byte runtime check, and framebuffer
hash are preserved in the [codec benchmark correction](../plans/2026-07-30-lzss-gallery-exhirom-video-boundary-test/real-video-codec-benchmark.md#visible-proof-rom-correction).
The fixed decoder saves `__rc0` on entry and restores it before returning; the caller retains its
ordinary C DMA assignments. bsnes-jg then reports `corpus_result == 0`, and the captured framebuffer
SHA-256 is `d0bd439a2a8909f2905ae3000e037b17f180ccdc365e7b6bf7f460b1d9c04c92`.

## Minimal audit

`test/upstream/dma-source-address/` contains two deliberately distinct cases:

- `dma-source-address.c` plus `callee-good.c` is assembly-free at the call boundary, keeps the
  linked object's low address byte live across an ABI-conforming observable call, assigns all three
  DMA-style bytes, and returns an observable checksum.
- `callee-bad.s` is the negative control. It explicitly modifies `__rc0`, documents that this is
  forbidden, and therefore models the old decoder rather than a valid compiler input.

Run `dev/dma-source-address-upstream-audit.sh`. It emits LLVM IR, pre-final-isel MIR, final assembly,
ELF relocations, and object disassembly under `/tmp/dma-source-address-upstream-audit`. The pristine
upstream tools identify themselves as llvm-mos `8be0546128a55e78c63ca571d466aa72a782cd36`.

The valid case passes `-verify-machineinstrs`. Its object contains distinct
`R_MOS_ADDR16_LO linked_object` and `R_MOS_ADDR16_HI linked_object` relocations; final assembly keeps
the linked low byte live across `jsr abi_conforming_call` and stores the correct high relocation.
The custom audit link places `linked_object` at `$91A5`; linked disassembly contains low `$A5` and
high `$91`, proving the relocations reached the final bytes. There is no wrong relocation or
source-semantics mismatch. The control assembles only because raw
assembly can violate the calling convention; its resulting bad reload is expected behavior.

## Pristine-upstream gate

| Requirement | Result |
|---|---|
| unmodified upstream, no 65816 fork patches | pass: pristine `build/upstream-llc` at `8be0546128a55` |
| valid testcase with ABI-conforming call | pass |
| wrong runtime output or relocation | **fail: none demonstrated** |
| independent of fork features | pass: target is plain `mos`; no far pointer, `+mos-a16`, SNES map, or fork linker script |

Because the required wrong-result prerequisite fails, the decision gate stops here. The incident is
an assembly ABI violation, not an LLVM optimization, instruction-selection, relocation, or linker
defect. No upstream issue, regression patch, PR draft, or contribution-status entry is warranted.
