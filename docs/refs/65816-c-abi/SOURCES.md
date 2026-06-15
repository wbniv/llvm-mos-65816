# Vendored reference sources — 65816 C ABI prior art

Primary sources behind [docs/320-321-65816-c-abi-prior-art.md](../../320-321-65816-c-abi-prior-art.md).
These files are **redistribution-restricted** and are **not committed** (see `.gitignore`); they are
vendored locally for verification only. Re-fetch + verify with `dev/fetch-refs.sh`.

Retrieved: **2026-06-15**.

| File | sha256 | Source | License / notes |
|------|--------|--------|-----------------|
| `816cc.pdf` | `1924c3669279834e64ffcc7b06d6aae5f01bcf3dbfce2d98e450f30440afe56c` | <https://www.westerndesigncenter.com/wdc/documentation/816cc.pdf> | WDC816CC "W65C816S C Compiler/Optimizer User Guide" (WDC, 2013-09-12). © Western Design Center — **copyrighted**, do not redistribute; cited by page number only. |
| `ORCA-C-Gen.pas` | `924e5760851bc8d72f7dae06544cd773a06d59aa518fead76fc5aa573685cd7d` | <https://raw.githubusercontent.com/byteworksinc/ORCA-C/master/Gen.pas> | ORCA/C code generator (Byte Works). **Source-available, not OSI-open / not redistributable** (forking permitted, redistribution requires written permission); cited by line number only. |

If a sha256 stops matching, the upstream document changed — update the hash here and re-verify the
page/line citations in the prior-art note before trusting them.
