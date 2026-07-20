# HOWTO — a feature worktree that runs `dev/run.sh` without rebuilding the toolchain

**What:** spin up a git worktree for a feature or a GO/NO-GO spike so it gets a clean checkout + isolated
commits off `main`'s hot shared tree, **and** can run the Dockerized differential harness (`dev/run.sh`)
without the 30–90 min from-source toolchain rebuild.

**When:** any non-trivial change, and *especially* investigations/spikes — per [`CLAUDE.md`](../CLAUDE.md)
("Investigations go on throwaway worktrees, not `main`") and [`~/CLAUDE.md`](../../CLAUDE.md)
("Worktree-based feature workflow").

## Why the obvious shortcut doesn't work

`CLAUDE.md` says reuse the main checkout's toolchain by **env-overriding** `CLANG`/`OBJDUMP` to
`…/build/llvm-mos-install/bin/...` rather than rebuilding. That works for **host-side, compile-only** scripts
(e.g. `dev/measure-zp-pressure.sh`). It does **not** work for `dev/run.sh`: that wrapper runs everything inside
Docker with a **single** bind-mount — `-v "$ROOT":/work` — so a path pointing at the *sibling* main checkout
(`/home/will/llvm-mos-65816/build/...`) **dangles inside the container** (which only sees `/work` = the
worktree). The worktree therefore needs its **own** self-contained `build/`.

Rebuilding it is 30–90 min. Instead, **hardlink** the prebuilt, read-only bits in: `cp -al` is near-instant,
uses ~zero extra disk (shares inodes on the same filesystem), and — being real directory entries under the
worktree root — resolves correctly inside the container.

## Steps

```bash
SLUG=myfeature                          # -> branch wt/321-myfeature
MAIN=/home/will/llvm-mos-65816
WT="$MAIN-$SLUG"

# 1. Worktree off the CURRENT main tip (so it carries the latest committed infra).
git -C "$MAIN" worktree add -b "wt/321-$SLUG" "$WT" main

# 2. Hardlink the prebuilt toolchain / SDK / emulator / BIOS so dev/run.sh's Docker
#    gets a self-contained build/ — NO rebuild. (Read-only: never edit these in place.)
mkdir -p "$WT/build" "$WT/vendor"
cp -al "$MAIN/build/llvm-mos-install" "$WT/build/"     # mos-clang / lld / llvm-objdump …
cp -al "$MAIN/build/install"          "$WT/build/"     # SDK: mos-snes.cfg + platform libs
cp -al "$MAIN/build/jgxcheck"         "$WT/build/"     # bsnes-jg readback harness (if built)
cp -al "$MAIN/vendor/bsnes-jg"        "$WT/vendor/"    # bsnes-jg core + Database
cp -al "$MAIN/dev/roms"               "$WT/dev/"       # SPC700 IPL (gitignored BIOS)

# 3. Verify the worktree sees a usable toolchain.
for p in build/llvm-mos-install/bin/mos-clang build/install/bin/mos-snes.cfg \
         build/jgxcheck vendor/bsnes-jg/Database dev/roms/s_smp/spc700.rom; do
  [ -e "$WT/$p" ] && echo "ok   $p" || echo "GONE $p"
done
```

Then work and run **from the worktree**:

```bash
cd "$WT"
dev/run.sh corpus        # 7/7 — confirms the hardlinked toolchain works end-to-end
dev/run.sh fuzz 50 1     # the differential harness, in the worktree's own Docker
```

## What's isolated vs shared

- **Isolated (fresh inodes):** all source edits, new files, and harness *scratch* — ROMs, link maps,
  `build/fuzz-triage/`, and freshly-built tools (e.g. `vendor/csmith`). None of this touches `main`.
- **Shared (hardlinks):** the prebuilt `build/llvm-mos-install`, `build/install`, `build/jgxcheck`,
  `vendor/bsnes-jg`, `dev/roms`. **Read-only — never modify in place** (you'd mutate `main`'s copy too). To
  rebuild the toolchain *in the worktree*, first `rm -rf build/llvm-mos-install` to break the hardlink, then
  `dev/run.sh toolchain` writes a fresh, independent tree.

## Compiler-changing variant — `cp -a` a warm build (rebuild in place)

The hardlink recipe above is for **host-only / non-compiler** work (it shares `main`'s prebuilt toolchain
read-only). When the feature **edits the compiler** (`vendor/llvm-mos`) and must rebuild, hardlinking
`build/llvm-mos-install` would corrupt `main` on rebuild-in-place. Instead **real-copy** the editable sources
and the **warm** `build/` (cmake tree + ccache) so the first rebuild is a fast *incremental* (minutes), not a
30–90 min cold build. Relocatable because `dev/run.sh` bind-mounts the worktree as `/work` and the cmake cache
uses `/work/...` paths. This is what `wt/320-far-cc` and `wt/321-frame-abi` use.

```bash
SLUG=myfeature; MAIN=/home/will/llvm-mos-65816; WT="$MAIN-$SLUG"
git -C "$MAIN" worktree add -b "wt/NNN-$SLUG" "$WT" main
mkdir -p "$WT/vendor" "$WT/dev"                          # create vendor/ FIRST (it's gitignored, absent in a fresh worktree)
cp -a  "$MAIN/vendor/llvm-mos"     "$WT/vendor/llvm-mos"     # REAL copy: editable backend (~5 GB)
cp -a  "$MAIN/vendor/llvm-mos-sdk" "$WT/vendor/llvm-mos-sdk" # REAL copy: editable SDK
cp -a  "$MAIN/build"               "$WT/build"              # REAL copy: warm cmake + ccache (~6 GB) -> fast incremental
cp -al "$MAIN/vendor/bsnes-jg"     "$WT/vendor/bsnes-jg"     # read-only -> hardlink
cp -al "$MAIN/dev/roms"            "$WT/dev/roms"            # gitignored BIOS -> hardlink
cd "$WT" && dev/run.sh toolchain && dev/run.sh corpus       # incremental rebuild (confirm clang-23 mtime advanced) + 7/7 sanity
```

Gotchas specific to this variant: **`mkdir -p "$WT/vendor"` before the first `cp -a`** (a fresh worktree has
no `vendor/`, so `cp -a src dest/vendor/llvm-mos` fails if `dest/vendor` is absent — and `set -e` aborts the
whole setup at that first copy). After each `vendor/` edit, **confirm the rebuild actually took** — check
`build/llvm-mos-install/bin/clang-23`'s mtime advanced (the symlinked `clang` has a stale mtime; a stale build
silently serves old codegen). Needs ~12 GB free per worktree.

## Disposition

- **Keep (the work lands):** merge the durable artifacts to `main` (`git -C "$MAIN" merge "wt/321-$SLUG"`, or
  cherry-pick), then `git worktree remove "$WT"` + `git branch -d "wt/321-$SLUG"`.
- **Dead-end (a spike says NO-GO):** `git worktree remove "$WT"` + `git branch -D "wt/321-$SLUG"`. Nothing is
  lost from `main`, and the hardlinked toolchain is untouched. Merge back only the recorded verdict (a one-file
  doc) first.

Either way, register the worktree in the **Active worktrees** table at the top of
[`agent-handoff.md`](agent-handoff.md) while it's live.

## Gotchas

- **Branch off the live `main` tip**, not a pinned older commit — on this hot tree you'd otherwise miss
  freshly-landed infra (e.g. the c-torture filter/runner).
- **Never edit a hardlinked file in place** — it shares an inode with `main`. Editors that replace-by-rename
  are safe; in-place truncation mutates both.
- **`set -euo pipefail` in an *inline* shell one-liner** can trip the harness shell-snapshot's unguarded
  `ZSH_VERSION` under `-u` (exit 127). Drop `-u` for ad-hoc one-liners; committed `.sh` scripts are unaffected.
- **Not yet automated.** This could be wrapped in a `dev/feature-worktree.sh` / `task feature-start NAME=<slug>`
  (see `~/CLAUDE.md` "Worktree-based feature workflow"). Until then, the block above is the one-shot setup.
