# Published SNES compiler-bug page audit

**Scope.** This audit covers published SNES ROM demos that *originally exposed*
a compiler, assembler, backend-runtime, or compiler-generated-platform defect.
It deliberately excludes later demos that merely re-stress a known repair. A
passing current ROM is not evidence that a historical compiler defect did not
exist; the linked investigation or defect record remains the authority for its
baseline and status.

The canonical machine-readable set is
[`../snes-demo-compiler-bug-pages.json`](../snes-demo-compiler-bug-pages.json).
It is the bridge between the defect evidence and the public biohack.net page.
Every listed page must visibly say that it was the discovery site, identify the
trigger and affected configuration, describe the observed failure, state the
resolution or qualified current status, explain the ROM's standing regression
role, and link primary technical evidence (an upstream PR/issue when one
exists, otherwise the repository investigation).

## Reconciled discovery pages

| Demo | Discovery | Page requirement |
| --- | --- | --- |
| Blossom | Far `memset` selected the near runtime and lost the destination bank. | Explain the bank-loss symptom, the far-runtime selection repair, and the retained red/green evidence. |
| L-System Plant | `+mos-xy16` index-width scheduling corrupted an in-place `memmove`. | Preserve the width-state mechanism, bad/good CRC evidence, repair, and why overlapping strings expose it. |
| qsortviz | Generic three-way comparisons aborted legalization. | Keep the `G_SCMP`/`G_UCMP` mechanism, all-mode reach, fix, and PR link. |
| Diffie-Hellman Colour-Mixer | Native-width 64-bit unmerge/extension legalizing was incomplete. | Explain the affected modes, exact generic operations, repair boundary, and five-way post-fix check. |
| CRC Wall | Default-width rotate coalescing silently used stale A. | State that this was silent and verifier-clean, then explain the register-class repair and default-mode regression. |
| Seam Demo | Status-register scavenging read an unavailable physical value. | Explain the verifier finding, availability-vs-reaching-definition distinction, and fixed scavenger invariant. |
| Step-Sequencer VM | An undefined imaginary-register lane reached a real store after allocation. | State that the runtime result remained correct but the verifier rejection is an unresolved toolchain contract, with a link to the issue. |
| VBlank Interrupt Tally | ISR entry assumed M8/X8 despite asynchronous native-width entry. | Keep the before/after results, fixed-width outer save envelope, and runtime evidence. |
| BRK/COP Tunnel | Native BRK/COP vectors and signature-byte assembly were incomplete. | Separate vector/platform and assembler behaviors; link the primary PR. |
| LZSS Mode 7 Gallery | Its far-decode work exposed late-opt non-GPR `LDImm` crash and nondeterministic zero-page allocation. | Explain both causal defects separately, distinguish the posted PR from the reproducible-build repair, and show why the gallery exercised them. |
| Backtracking Solver | Native `longjmp` page-1 reconstruction did not execute because an immediate was encoded at the wrong width. | Explain the actual CPU decode failure, assembler-width rule, repair, and recursive unwind check. |
| Retry-On-Fault Ladder | `+mos-xy16` frame-index materialization overwrote the spill value. | Mark the defect's status exactly as current; include the divergent CRC and do not claim a resolution until evidence establishes one. |
| By-Value Boundary Trio | Mixed-width accesses through one pointer across a call exhausted allocation registers. | Explain the small source shape, upstream/pristine reach, scoped workaround, and why the shipped gate remains meaningful. |

## Release gate going forward

Before a new SNES ROM whose development exposes a compiler defect is published:

1. Follow the defect-evidence workflow first. Decide whether it is an original
   discovery or only another observation of an existing canonical defect.
2. For an original discovery, append one record to
   `docs/snes-demo-compiler-bug-pages.json`, with the public page and the
   retained technical evidence. Add the site's `compilerBug` metadata and a
   detailed page section headed **“Compiler defect this ROM exposed.”**
3. The public section must give visitors the trigger, configuration, observed
   output/diagnostic, causal mechanism, current status, identified repair (if
   any), regression check, and primary links. Never replace historical red
   evidence with a current green run.
4. Run the normal paired-publication preflight. It checks every registered slug
   for both the machine-readable `compilerBug` marker and that exact page
   heading before it permits publication. The gallery derives its bug badge
   from the same marker.
5. Review this audit and the affected summaries through `docs-deps`; then build
   the site and verify the public page and badge after deployment.

This is a publishing provenance requirement, not a claim that every stress-test
ROM found a compiler defect.
