Mark CmpZero as a terminator so the machine verifier rejects ordinary instructions placed after it. Restrict `lowerCmpZeros` to the block's terminator range.

Keep each pseudo's fold decision separate from the pass's change accumulator, and report a change when deleting a dead comparison. Tests cover the rejected non-terminator placement, adjacent comparisons that require independent folding/lowering, and removal of a dead comparison. Existing late-optimization tests cover the ordinary single-comparison paths.

The original PR's reproducer placed a normal instruction after CmpZero. That placement violates the intended invariant; this revision encodes and tests the invariant explicitly.

Validation: all 80 enabled MOS CodeGen tests pass across the full run and focused rerun after correcting one new test expectation; 1 upstream-disabled test.
