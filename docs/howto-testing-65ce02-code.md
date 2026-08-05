# HOWTO — testing 65CE02 / 45GS02 code built with llvm-mos

**Why this exists.** Validating [llvm-mos PR #585](https://github.com/llvm-mos/llvm-mos/pull/585)
([investigation](investigations/2026-08-05-585-gashre-validation.md)) needed to *execute* 65CE02 code —
the PR's whole point is selecting the native `asr`. This repo's differential battery is SNES/65816-only,
so none of it applies. This is what we found out: what can be checked today, what is blocked and why, and
the trap that wasted an hour.

**Status in one line:** **this works end to end** — build a bare-metal 65CE02 image from C and execute it
on xemu's Commodore 65 target, with **no copyrighted ROM of any kind**, reading the result back from a
memory dump. MAME's `c65` driver is the one that does *not* work; see Level 3.

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
  exactly like a successful inertness result. `build.sh` now fails if the image has under 24 bytes of
  content.
- **Reset code must be a fall-through `.init.N` section, not a `jmp main`.** llvm-mos concatenates
  `.init.*` in order and the chain ends by calling `main`; jumping straight there skips soft-stack init and
  the data copy. See `dev/c65asr/start.s`.

`dev/c65asr/asrkernel.h` is a ready-made arithmetic-right-shift kernel (every width, every shift amount,
both signs, the multi-byte carry chain, store-folded shapes, and signed bitfield read-back) folded into one
16-bit checksum, shared verbatim by `host.c` (the oracle) and `target.c`. Host oracle value: **`0xE0E8`**.

---

## Level 3 — executing it

### xemu Commodore 65 — ✅ this is the one that works

[xemu](https://github.com/lgblgblgb/xemu) (LGB) builds in about a minute and needs only SDL2 (plus GTK for
its menu), both already present here:

```bash
git clone --depth 1 https://github.com/lgblgblgb/xemu /tmp/xemu
make -C /tmp/xemu -j8 TARGETS=c65 ARCH=native      # -> /tmp/xemu/build/bin/xc65.native
```

**No Commodore ROM is required.** `c65_load_rom()` reads *any* file that is exactly `0x20000` bytes into
`memory + 0x20000` with no checksum or version check:

```c
int c65_load_rom ( const char *fn, unsigned int dma_rev )
{
	if (xemu_load_file(fn, memory + 0x20000, 0x20000, 0x20000, ...) != 0x20000)
		return -1;
```

So hand it 128 KiB of our own code and let the CPU reset through it. `dev/c65asr/run-xemu.sh` does exactly
that, using four xemu options that make this a proper test harness:

| option | why |
|---|---|
| `-skipconfigfile` | **must be the first option** — xemu errors out otherwise |
| `-headless` | no window; documented as "for testing!" |
| `-sleepless` | run flat out, not at 1 MHz |
| `-dumpmem FILE` | dump memory on exit — this is the read-back path |
| `-rom FILE` | our synthesised 128 KiB image |

xemu writes the dump on its **normal exit path**, so the run is ended with `timeout -s INT`; exit status
130 is the success case. The dump is 128 KiB of RAM, so a value the program stored at `$0400` is at file
offset `0x400`.

The script places the payload at **both** candidate file offsets for CPU `$E000` — `0x0E000`
(`ROM_C64_KERNAL_REMAP 0x20000`) and `0x1E000` (`ROM_E000_REMAP 0x30000`) — plus both vector sets, so it
runs whichever window the reset mapping selects rather than depending on us guessing right.

End to end:

```console
$ dev/c65asr/build.sh build/llvm-mos-install dev/c65asr/target.c /tmp/k.bin mos65ce02
/tmp/k.bin: 8192 bytes, ~1068 bytes of content, reset vector $E000
$ dev/c65asr/run-xemu.sh /tmp/k.bin 90
XEMU_RESULT=0xE0E8          # == the host oracle from dev/c65asr/host.c
```

This is what closed the #585 gap. The measured matrix, all agreeing with the host oracle `0xE0E8`:

| build | native `asr` | `cmp #128` | image | executed result |
|---|---:|---:|---:|---|
| pre-#585 | 0 | 18 | 1168 B | `0xE0E8` |
| #585 | 15 | 6 | 1068 B | `0xE0E8` |
| #585 + `getDemandedBits` fix | 15 | 6 | 1068 B | `0xE0E8` |

The `asr` counts matter: they prove the #585 run really executed the new instruction path rather than
quietly falling back.

**One footgun:** build the payload with `-mcpu=mos65ce02`, not `mos45gs02`. This target is a CSG 4510, and
a 45GS02 build may use instructions it does not have. (That is a harness constraint, not a coverage gap —
anything gated on `has65CE02()` behaves the same on both.) Use xemu's `mega65` target if you ever
specifically need 45GS02.

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

### VICE — related, but not a 65CE02 execution target

VICE is in the foundry repo and its machines are certainly *close enough* to exercise instructions and
compiler fallbacks shared with the 6502 family. It emulates C64/C128/PET/Plus4/VIC-20/CBM-II and the
C64DTV, however, and none of those machines uses a 65CE02. The C64DTV adds its own extensions to a
6510-like CPU; those extensions are not the 65CE02 instruction set.

That distinction is decisive for #585. Its native path emits the 65CE02 accumulator `asr`, encoded as
`$43`. A VICE CPU does not decode `$43` as that instruction: depending on the selected core, the byte is
an unsupported or undocumented NMOS-family opcode with different operands and semantics. Executing the
image in VICE would therefore test different code, not merely the same code with different timing.

VICE remains useful for the **non-65CE02 fallback** (`cmp #128; ror`) and other shared 6502 behavior. It
cannot validate the native `$43 = asr` selection, nor other 65CE02 facilities such as the `Z` register,
relocatable base page, added addressing modes, or 16-bit relative branches. For the native half of this
test, xemu's C65 target is appropriate because its CSG 4510 incorporates the 65CE02 core.

---

## What we can honestly claim today

For #585 we validated the CPU-independent half by execution (SNES corpus + gcc c-torture, four-way
differential on two emulators) **and the 65CE02-specific half by execution too**, on xemu's C65 target:
host oracle `0xE0E8` == pre-#585 @ 65CE02 == #585 @ 65CE02 == #585+fix @ 65CE02, with the #585 builds
demonstrably running 15 native `asr` instructions where the baseline ran none.

## Artifacts

| path | status |
|---|---|
| `dev/c65asr/build.sh` | ✅ bare-metal 65CE02 image builder, with the gc-sections guard |
| `dev/c65asr/run-xemu.sh` | ✅ **executes it on xemu's C65 target and reads the result back** |
| `dev/c65asr/{link.ld,start.s}` | ✅ bare-metal link + fall-through reset |
| `dev/c65asr/asrkernel.h` | ✅ shared ASR kernel, host oracle `0xE0E8` |
| `dev/c65asr/{host.c,target.c}` | ✅ oracle and target entry points |
| `dev/c65asr/run-c65.sh` | ⛔ MAME route — blocked on its incomplete c65 memory model; kept as the record |
