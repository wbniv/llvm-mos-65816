# Vendored reference sources — 65816 opcode audit oracle

The [65816 reference](65816-reference.md) and its companion [opcode audit](65816-opcode-audit.md)
are **generated from the llvm-mos backend's own TableGen** (`vendor/llvm-mos/llvm/lib/Target/MOS/*.td`,
Apache-2.0-with-LLVM-exception) by [`tools/gen-65816-ref.py`](../../../tools/gen-65816-ref.py). The audit
cross-checks every opcode against an **independent canonical opcode matrix** — the oracle below.

Retrieved: **2026-06-25**.

| File | Tracked? | sha256 | Source | License / notes |
|------|----------|--------|--------|-----------------|
| `oracle-65c816-opcodes.tsv` | **yes** (committed) | — | derived from the file below via [`tools/gen-65816-oracle.py`](../../../tools/gen-65816-oracle.py) | Normalised `opcode→mnemonic→mode→bytes` table. Pure facts from a CC0 source → freely committable. |
| `oracle/65c816-datasheet.txt` | no (gitignored) | `b2ba1db7f8a49eb575f0a444bb5d66af34e762999d0db2a00bff03e9993f0196` | [larsbrinkhoff/awesome-cpus `MCS6500/65c816.txt`](https://raw.githubusercontent.com/larsbrinkhoff/awesome-cpus/master/MCS6500/65c816.txt) | **CC0 1.0** (public domain) — a text transcription of the GTE/WDC G65SC802/816 datasheet "Table 8. Opcode Matrix". Re-fetch with [`dev/fetch-65816-oracle.sh`](../../../dev/fetch-65816-oracle.sh). |

The oracle is used **only as a correctness reference** (to select the 65816 variant per opcode and to
audit the backend); the generated docs are not a verbatim copy of it. Because the source is CC0 the
normalised TSV is committed for offline, reproducible audits; the raw datasheet stays gitignored to keep
the tree lean (re-fetch + sha256-verify with the script above).

If the sha256 stops matching, upstream changed — re-fetch, re-run `tools/gen-65816-oracle.py`, and
re-verify the audit before trusting it.
