MOSCopyOpt can forward a loop-header `A = COPY Y` through reaching `Y = COPY A` definitions and remove the restore. This changes the register that must remain live around the back edge from Y to A.

A single post-order liveness update visits the latch before the header and can leave A absent from the latch's live-ins. Later CmpZero lowering then treats A as scratch and overwrites the loop-carried value. In the CRC reproducer this makes the next rotate consume the old accumulator value.

Propagate live-ins to a fixed point with `fullyRecomputeLiveIns` before dead-copy cleanup. Keep the entry block's ABI live-ins intact. Remove the original shouldCoalesce workaround; ordinary rotate coalescing remains enabled.

The reduced MIR regression checks that A is live through the latch and that the copy-optimization/pseudo-expansion/late-optimization pipeline does not overwrite it. Both checks fail without the fix.

This replaces the original PR's diagnosis: register allocation emits the required restore correctly. The failure occurs later when copy forwarding changes the loop's liveness and the update does not propagate around the back edge.

Validation: MOS CodeGen suite 79 pass, 1 unsupported. Both regression assertions fail without the fix. The reconstructed SNES demo changes from host/ROM CRC mismatch (0x7F81 / 0xC57C) to agreement at 0x7F81 in bsnes.
