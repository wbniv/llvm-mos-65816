# 65816 external references

Canonical, freely-linkable references for the WDC 65816 ISA — the part this fork targets under
`+mos-a16`. **Link these; do not bundle them.** See *Licensing* below before copying any datasheet
text into the repo or the release tarball.

## Primary — Western Design Center (the rights-holder)

WDC designed the 65816/65802 and still publishes and owns the documentation. Cite WDC first.

- **W65C816S datasheet** — [westerndesigncenter.com/wdc/documentation/w65c816s.pdf](https://www.westerndesigncenter.com/wdc/documentation/w65c816s.pdf)
  (© 1981–2024 The Western Design Center, Inc.). The authoritative ISA reference: registers, addressing
  modes, opcode matrix, per-instruction cycle counts, native vs. emulation mode (`XCE`), `rep`/`sep`,
  `M`/`X` flag semantics.
- **WDC product / documentation index** — [westerndesigncenter.com](https://westerndesigncenter.com/)

## Secondary — archival mirrors (handy, still copyrighted)

- **6502.org datasheet archive** — [archive.6502.org/datasheets/](http://archive.6502.org/datasheets/)
  (multiple dated W65C816S revisions; useful when chasing a wording change between datasheet years).
- **SNESdev wiki — 65C816** — [snes.nesdev.org/wiki/65C816](https://snes.nesdev.org/wiki/65C816)
  (community reference; CC-licensed wiki text, good for the SNES-specific mode/timing context).

## Licensing — why these are linked, not vendored

The release tarball is **Apache-2.0 with LLVM exceptions, end to end** — `dev/package-release.sh` ships
only `LICENSE` + `NOTICE`, and that same tree is repacked into the apt `.deb`. A manufacturer datasheet
is **third-party copyrighted material** (WDC, and for the older CMOS parts the second-source vendors that
fabbed them), distributed with **no redistribution grant**. Dropping datasheet text into `docs/` of that
prefix would inject an incompatible, unlicensed work into an otherwise clean distribution.

So: **reference by URL, never copy in.** Any reproduction we ship needs an actual permission grant from
WDC first — its presence on an old FTP/web mirror is not one.

### Note on the GTE / Oulu HTML transcription

A widely-mirrored HTML copy of the **GTE Microcircuits G65SC802/G65SC816 data sheet** exists, transcribed
by *Jouko Valta (`jopi@stekt.oulu.fi`)* at the University of Oulu in the early/mid-1990s. GTE was a
**second-source licensee** of WDC's design; that page is an **unauthorized hobbyist transcription** with no
license attached. It's fine to *consult*, but it is **not** a redistributable or public-domain source —
prefer WDC's current datasheet above for anything we cite, and do not bundle the GTE/Oulu text.
