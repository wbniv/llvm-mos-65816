Zero-page allocation can choose different globals for identical inputs when candidate scores tie. Pointer-ordered iteration also affects entry-point ordering and floating-point accumulation of candidate benefits.

Use insertion-ordered containers at the three relevant iteration sites. Document the determinism requirement without promising a particular iteration order.

The regression gives eight equally beneficial globals four bytes of zero page and checks a consistent allocation. Independent downstream testing in this thread also confirms reproducible full-LTO binaries with the change.

Validation: MOS CodeGen suite 79 pass, 1 unsupported; 20 separate llc runs produce byte-identical assembly.
