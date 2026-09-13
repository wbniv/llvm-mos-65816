MOSCopyOpt can forward a loop-header `A = COPY Y` through reaching `Y = COPY A` definitions and remove the restore. This changes the register that must remain live around the back edge from Y to A.

A single post-order liveness update visits the latch before the header and can leave A absent from the latch's live-ins. Later CmpZero lowering then treats A as scratch and overwrites the loop-carried value. In the CRC reproducer this makes the next rotate consume the old accumulator value.

Propagate live-ins to a fixed point with `fullyRecomputeLiveIns` before dead-copy cleanup. The per-block live-in recompute inside the cleanup loop stays: it is what lets a copy in a predecessor become dead in the same pass after a successor's dead copy is erased. Keep the entry block's ABI live-ins intact. Remove the original shouldCoalesce workaround; ordinary rotate coalescing remains enabled.

The reduced MIR regression checks that A is live through the latch and that the copy-optimization/pseudo-expansion/late-optimization pipeline does not overwrite it. Both checks fail without the fix. A second test pins two- and three-block dead-copy chains so the per-block recompute cannot be dropped by accident. The three-block case also checks final assembly for the absence of leftover register transfers.

This replaces the original PR's diagnosis: register allocation emits the required restore correctly. The failure occurs later when copy forwarding changes the loop's liveness and the update does not propagate around the back edge. The defect is confined to the target-specific MOSCopyOpt pass; no generic LLVM change is involved.

Validation: MOS CodeGen suite at `b4749221bf37`: 80 pass, 1 unsupported. Both regression assertions fail without the fix. The reconstructed SNES demo changes from host/ROM CRC mismatch (0x7F81 / 0xC57C) to agreement at 0x7F81 in bsnes. Compile-time cost of the fixed-point recompute, measured as retired instructions over a 176-file corpus at -O2: +0.8% overall, +2.4% on the worst loop-dense kernel; on-CPU time unchanged.
