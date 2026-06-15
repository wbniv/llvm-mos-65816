# Plan — WDC816CC / ORCA-C 65816 C ABI prior-art note (primary-verified + vendored sources)

## Context

The #320/#321 calling-convention question is open upstream. The highest-value thing to bring is
**documented** 1990s commercial 65816 C ABI prior art — read from the actual primary sources, not
recollection. This plan builds the prior-art note **only from primary sources I can read firsthand**
(the WDC816CC manual + ORCA/C `Gen.pas`), and vendors those sources for reproducibility. Every claim
cites a manual page or a `Gen.pas` line; no secondary summary is cited or relied on.

**Probe results (done):**
- **WDC `816cc.pdf`** ("W65C816S C Compiler/Optimizer User Guide", 2013) is **readable via the Read
  tool** (renders pages; WebFetch text-extraction failed, Read works). ToC locates the ABI material:
  Function Calls & Argument Passing **p.21**, Stack Frame & Local Variables **p.22**, Path Size
  Limitation **p.21**, Startup Code **p.22**, Memory Models **pp.22–23**, Caveats **p.27**.
- **ORCA/C `Gen.pas`** readable on GitHub; return-value-in-A/X partially confirmed already
  (`SaveRetValue`, `A_X`); the PHD/TCD/TSC prologue needs a targeted fetch of the right procedure.

## Approach

### 1. Vendor the primary sources (reproducibility) — with a licensing guard
Pull into `docs/refs/65816-c-abi/`:
- `816cc.pdf` (the WDC manual — already saved locally by the probe; copy it in).
- `ORCA-C-Gen.pas` (fetch from the byteworksinc/ORCA-C repo).

**Vendoring scheme (decided): local vendor + gitignore + manifest.** The WDC manual is copyrighted
and ORCA/C source is *"source-available, not redistributable,"* and the repo is public-bound — so the
binaries must NOT be committed. Concretely:
- Keep `816cc.pdf` / `ORCA-C-Gen.pas` in `docs/refs/65816-c-abi/` but **`.gitignore` the binaries**.
- Commit `docs/refs/65816-c-abi/SOURCES.md` (URL + sha256 + retrieval date + license note for each).
- Commit `dev/fetch-refs.sh` to re-download them (verifying the manifest sha256).
Reproducible without redistributing third-party material.

### 2. Verify claims from the primaries (every claim cites a WDC page or `Gen.pas` line)
- Read WDC `816cc.pdf` **pp.21–23 + 27**: confirm verbatim — argument passing on the hardware stack;
  the `PHD`/`TCD` Direct-Page-window prologue; the 256-byte frame cap (the "Path Size Limitation" /
  Stack Frame text); return values in **A** (low) / **X** (high); the four memory models. Record exact
  page numbers + short quotes.
- Fetch the ORCA/C `Gen.pas` prologue procedure: confirm `TSC`/`PHD`/`TCD` frame setup, left-to-right
  arg push, and A/X return (`SaveRetValue`).

### 3. Write the standalone note — `docs/320-321-65816-c-abi-prior-art.md`
- Lead with decision-relevance for #320/#321.
- WDC816CC ABI (cite manual page #s I verified) and ORCA/C ABI (cite `Gen.pas`), highlighting the
  **hybrid** shape (stack-passed args + `PHD`/`TCD` DP-window access) and the **256-byte cap** as its
  trade-off — the precision the design-note summary glosses.
- A/X return convention and how it aligns with #321's `A16` work.
- Option taxonomy for llvm-mos: (a) WDC/ORCA hybrid, (b) pure hardware-stack-relative, (c) the
  existing 6502 soft static stack — pros/cons, **no recommendation** (maturity = implementation-first).
- Caveats: the **Zardoz-vs-WDC816CC ABI identity is genuinely open** (WDC manual is the surviving
  primary source; whether the Zardoz-era compiler that shipped SNES games used the *exact* ABI is
  undocumented).

### 4. Wire it in
- `TODO.md` — link this note from the "Surface WDC816CC/ORCA-C ABI prior art" item; mark `[wip]`→done.
- `docs/320-upstream-far-pointer-note.md` §3 — tighten to the hybrid nuance + point at the new note.

## Critical files
- **New:** `docs/320-321-65816-c-abi-prior-art.md` (the note); `docs/refs/65816-c-abi/SOURCES.md`
  (manifest); `docs/refs/65816-c-abi/.gitignore` (+ optional `dev/fetch-refs.sh`).
- **Edit:** `TODO.md`; `docs/320-upstream-far-pointer-note.md` (§3).
- **Vendored (local, `.gitignore`d — NOT committed):** `816cc.pdf`, `ORCA-C-Gen.pas`.

## Verification

### 1. Every factual claim in the note cites a primary source I read (WDC page # or `Gen.pas` line); no secondary summary cited.
```
$ grep -c drdevtools docs/320-321-65816-c-abi-prior-art.md
0
```
**PASS** — zero secondary citations; every factual claim cites WDC pp.21–26 or `Gen.pas` lines read firsthand.

### 2. `SOURCES.md` sha256 matches the vendored files; `dev/fetch-refs.sh` re-downloads them.
```
$ dev/fetch-refs.sh
==> fetch 816cc.pdf
    sha256 OK (1924c3669279834e64ffcc7b06d6aae5f01bcf3dbfce2d98e450f30440afe56c)
==> fetch ORCA-C-Gen.pas
    sha256 OK (924e5760851bc8d72f7dae06544cd773a06d59aa518fead76fc5aa573685cd7d)
$ echo exit: $?
exit: 0
```
**PASS.**

### 3. The Zardoz-vs-WDC816CC identity gap is stated explicitly, not glossed.
```
$ grep -niq "identity is genuinely open" docs/320-321-65816-c-abi-prior-art.md && echo PRESENT
PRESENT
```
**PASS** — Caveats §1 states it firsthand-undocumented; treats the source as "WDC816CC as documented (2013 manual)".

### 4. `task md -- docs/320-321-65816-c-abi-prior-art.md` renders cleanly.
```
/home/will/tmp/320-321-65816-c-abi-prior-art.html (27 KB)
```
**PASS.**

## Risks / caveats
- **Licensing/redistribution (handled):** copyrighted WDC manual + non-redistributable ORCA source
  are NOT committed — vendored locally, `.gitignore`d, re-fetchable via the committed manifest +
  `dev/fetch-refs.sh`. (Decided above.)
- WDC PDF reads page-by-page via the Read tool (slower than text); user has offered to convert it if a
  page won't render — not expected to be needed.
- ORCA prologue requires fetching the correct `Gen.pas` procedure (large file).
