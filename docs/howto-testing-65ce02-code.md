# HOWTO — testing 65CE02 / 45GS02 code built with llvm-mos

**Why this exists.** Validating [llvm-mos PR #585](https://github.com/llvm-mos/llvm-mos/pull/585)
([investigation](investigations/2026-08-05-585-gashre-validation.md)) needed to *execute* 65CE02 code —
the PR's whole point is selecting the native `asr`. This repo's differential battery is SNES/65816-only,
so none of it applies. This is what we found out: what can be checked today, what is blocked and why, and
the trap that wasted an hour.

**Status in one line:** everything up to and including *building a bare-metal 65CE02 ROM image* works and
is checked in; *executing* it needs an emulator we do not currently have.

---

## The chips, and what llvm-mos calls them

| CPU | Machine | llvm-mos `-mcpu` |
|---|---|---|
| 65CE02 | — (core) | `mos65ce02` |
| CSG 4510 (65CE02 + MMU/ports) | Commodore 65 / C64DX prototype | `mos65ce02` |
| 45GS02 (4510 superset) | MEGA65 | `mos45gs02` |

The SDK ships a **`mega65` platform** (`mos-mega65-clang`, `-mcpu=mos45gs02`, produces a `.prg`), so the
toolchain side is already solved. `mos65ce02` and `mos45gs02` are both valid and both select the native
`asr` under #585.

---

## Level 1 — checks that need no emulator (all work today)

These caught real things during the #585 pass, so do not skip them just because they are static.

**Instruction selection and encoding.** The `asr` accumulator form must assemble to opcode `$43`
(`$44` zero-page, `$54` zero-page,X):

```console
$ printf 'signed char f(signed char a){return a>>1;}\n' > /tmp/enc.c
$ build/llvm-mos-install/bin/mos-clang --target=mos -mcpu=mos65ce02 -Os -c /tmp/enc.c -o /tmp/enc.o
$ build/llvm-mos-install/bin/llvm-objdump -d --mcpu=mos65ce02 /tmp/enc.o
00000000 <f>:
       0: 43           	asr
       1: 60           	rts
```

Disassemble the **object**, not a raw binary — `llvm-objdump -b binary -m mos --mcpu=mos65ce02` does not
apply the subtarget and will silently decode `$43` as something else, so an `asr` grep over a raw image
returns 0 even when the instruction is there.

**Byte-size deltas.** `dev/asr-bytetable-585.sh` measures `.text` size per C shape across two toolchains
and several CPUs. This is how we reproduced mlund's byte table and found the `int32_t >> 1` row understated.

**Whole-corpus byte identity.** `dev/sweep-585.sh` hashes objects for ~1540 translation units across seven
target/feature combos. `mos65ce02` and `mos45gs02` are in the combo list.

**lit.** `llvm/test/CodeGen/MOS/asr-65ce02.ll` exercises `mos65ce02`, `mos45gs02` and `mos6502`. Remember
the standing gotcha: `dev/run.sh toolchain` does **not** rebuild `llc`, so refresh it first —

```bash
docker run --rm -v "$PWD":/work --user "$(id -u):$(id -g)" -e HOME=/work/build \
  llvm-mos-65816-dev cmake --build /work/build/llvm-mos --target llc FileCheck count not --parallel 8
```

---

## Level 2 — building a bare-metal 65CE02 image (works today)

`dev/c65asr/build.sh` links C compiled for `-mcpu=mos65ce02` into a raw 8 KiB image covering CPU
`$E000-$FFFF`, vectors in the last six bytes. No SDK platform needed — `dev/c65asr/link.ld` is modelled on
the SDK's `eater` platform, the closest thing it ships to "no OS, just a reset vector".

```bash
dev/c65asr/build.sh build/llvm-mos-install dev/c65asr/target.c /tmp/asr.bin mos65ce02
# /tmp/asr.bin: 8192 bytes, ~1068 bytes of content, reset vector $E000
```

Two things this cost us, both now guarded by the script:

- **Link `crt0.o` as an object, never `-lcrt0`.** Its `.call_main` section is what references `main`. As an
  archive member it is only pulled in if *already* referenced — so with `--gc-sections` the entire program
  is dropped and you still get a clean link and a plausible 8 KiB file. Ours contained 14 bytes of init
  code and 8 KiB of padding, and the "before" and "after" images compared byte-identical, which looks
  exactly like a successful inertness result. `build.sh` now fails if the image has under 64 bytes of
  content.
- **Reset code must be a fall-through `.init.N` section, not a `jmp main`.** llvm-mos concatenates
  `.init.*` in order and the chain ends by calling `main`; jumping straight there skips soft-stack init and
  the data copy. See `dev/c65asr/start.s`.

`dev/c65asr/asrkernel.h` is a ready-made arithmetic-right-shift kernel (every width, every shift amount,
both signs, the multi-byte carry chain, store-folded shapes, and signed bitfield read-back) folded into one
16-bit checksum, shared verbatim by `host.c` (the oracle) and `target.c`. Host oracle value: **`0xE0E8`**.

---

## Level 3 — executing it (blocked; read before trying)

### MAME `c65` — do not use

MAME has a Commodore 65 driver and it does instantiate the right CPU (`m4510(:maincpu)`), and it will boot
a **synthesised** 128 KiB image, so no Commodore ROM is needed and there is no licensing problem:

```console
$ mame -listxml c65 | grep 'rom name'
  rom name=910111.bin size=131072 ... region=ipl offset=0
```

Put your own bytes in `910111.bin`, zip it as `c65.zip` into `~/mame/roms/`, and MAME reports
`WRONG CHECKSUMS` and runs anyway. `dev/c65asr/run-c65.sh` does this and reads the result back over the Lua
API (`manager.machine.devices[":maincpu"].spaces["program"]:read_u8(...)`, which works fine).

**It still does not work, and the driver says why.** From `src/mame/commodore/c65.cpp`:

```
TODO:
- Complete memory model;
\- rom8 / roma / rome all causes bootstrap issues if hooked up (needs the CPU DDR port?)
```

`rome` is the `$E000` ROM window — deliberately *not* hooked up. So the reset vector is never fetched from
your image, and your code at `$E000` never runs. MAME also flags the driver `status: preliminary,
emulation: preliminary`. Even if coaxed into running, a differential result from a preliminary driver
would need so much hedging that it would weaken a review comment rather than support it.

> ### ⚠ The trap — an all-`$EA` image gives a convincing false positive
>
> Our first probe filled the whole 128 KiB with `$EA` (NOP) and patched the vector at image offset
> `$1FFFC` to `$E000`. MAME booted and the PC advanced steadily through `$EB4B`, `$EBB5`, `$EC1F`… which
> reads exactly like "our code is executing at `$E000`". It was not. The vector fetch returned `$EAEA` —
> the *fill byte* — and the CPU was running the NOP field from there. Working backwards from the ~106
> instructions/frame rate put the start at `$EAE1 ≈ $EAEA`, not `$E000`.
>
> The tell: a `$00`-filled image put PC at `$0000` instead. **A NOP-filled image cannot distinguish
> "executing your code" from "executing your padding".** Always probe with a payload that writes a
> distinctive value to RAM, never with a NOP sled.

### xemu — the route that should actually work

[xemu](https://github.com/lgblgblgb/xemu) (LGB) is the real MEGA65 emulator and is actively maintained. It
is not packaged in Ubuntu or in the foundry repo (`apt.foundrylinux.org resolute main` — its
`foundry-emulators-*` metapackages cover dosbox-x, hatari, fs-uae, openmsx, vice, atari800, fbzx,
mame-extra, none of which emulate a 65CE02 machine), so it needs building from source (SDL2).

The remaining question is the **MEGA65 ROM**, which is third-party copyrighted. Under this repo's
link-don't-vendor rule it would be handled exactly like the SNES SPC700 BIOS: gitignored, user-supplied,
fetched out of band, never committed. Sourcing/approving that is a user decision, not something to do
unilaterally.

Pairing xemu with the SDK's existing `mega65` platform (`mos-mega65-clang`, produces a `.prg`) would avoid
the bare-metal work entirely and is the shortest path to a real result.

### VICE — not applicable

VICE is in the foundry repo but emulates C64/C128/PET/Plus4/VIC-20/CBM-II and the C64DTV. None uses a
65CE02.

---

## What we can honestly claim today

For #585 we validated the CPU-independent half by execution (SNES corpus + gcc c-torture, four-way
differential on two emulators) and the 65CE02-specific half by **codegen inspection, encoding check, byte
measurement and lit only**. That limitation is stated plainly in both the investigation and the draft
review comment. Nothing here changes that; it records how far the execution route got and where it stops.

## Artifacts

| path | status |
|---|---|
| `dev/c65asr/build.sh` | ✅ works — bare-metal 65CE02 image builder, with the gc-sections guard |
| `dev/c65asr/{link.ld,start.s}` | ✅ works — bare-metal link + fall-through reset |
| `dev/c65asr/asrkernel.h` | ✅ works — shared ASR kernel, host oracle `0xE0E8` |
| `dev/c65asr/{host.c,target.c}` | ✅ works — oracle and target entry points |
| `dev/c65asr/run-c65.sh` | ⛔ blocked on MAME's incomplete c65 memory model — kept as the record |
