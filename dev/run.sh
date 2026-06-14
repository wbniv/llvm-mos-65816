#!/usr/bin/env bash
# Host-side driver: (re)build the dev image and run a dev/<target>.sh inside it
# against this repo. Usage: dev/run.sh [build|compile|validate|smoke|corpus|toolchain|far|far-run|far-bank1|xcheck|repro] (default: build)
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(dirname "$HERE")"
IMAGE=llvm-mos-65816-dev
TARGET="${1:-build}"

if [ "$TARGET" = "-h" ] || [ "$TARGET" = "--help" ]; then
  cat <<'USAGE'
Usage: dev/run.sh [TARGET] [ARGS...]   (default: build)

(Re)build the dev image and run dev/<TARGET>.sh inside it against this repo.

Targets:
  build      (re)build the dev image, vendor llvm-mos-sdk + platforms/snes,
             compile examples/snes/hello.c -> build/hello.sfc   (default)
  compile    compile the SNES example in the container (image must exist)
  validate   structural validation of build/hello.sfc (reset path, checksum)
  smoke      boot build/hello.sfc headless in MAME, assert sentinel==0x42
             (needs the SPC700 IPL at dev/roms/s_smp/spc700.rom)
  corpus     run the regression corpus headless in MAME: assert each program in
             examples/snes/corpus/ against examples/snes/corpus/expected.tsv
  toolchain  build llvm-mos (clang/lld) FROM SOURCE -> build/llvm-mos-install
             (for M1 codegen; long first build — see dev/toolchain.sh)
  far        #320 Increment 1: compile examples/65816/far-deref.c with the
             from-source toolchain and assert (at the disassembly level) that a
             far (addrspace 2) access lowers to 65816 absolute-long (LDA/STA
             $xxxxxx) while a near access stays 16-bit (needs `toolchain` first)
  far-run    #320 Increment 2: build examples/65816/far-run.c with -mcpu=mosw65816
             into a bootable .sfc, boot headless in MAME, and assert the byte
             produced by a far LOAD and written by a far STORE reads back == 0xF3
             (needs `toolchain` + `build` on the from-source toolchain first)
  far-bank1  #320 Increment 2b: build examples/65816/far-bank1.c against the
             snes-far 64 KiB platform (banks $00+$01), assert the far global lands
             in bank $01 ($018xxx), boot in MAME, and check the cross-bank far read
             round-trips == 0xF3 (needs `toolchain` + `build` first)
  xcheck     second-emulator fidelity cross-check: boot the far ROMs in bsnes-jg
             (cycle-accurate, independent of MAME) headless and assert the same
             WRAM results — confirms the bank-$01 far read isn't a MAME quirk
             (fetches+builds bsnes-jg once; needs `toolchain` + `build` first)
  repro      clean-room: fresh checkout, then build + corpus in it (host-side)

Extra ARGS are forwarded to repro.sh (only meaningful for `repro`).
Env forwarded into the container (when set): SMOKE_WANT, SMOKE_SETTLE, SNES_ROMPATH,
MOS_TOOLCHAIN (toolchain install prefix to build the bench with), BUILD_JOBS.
USAGE
  exit 0
fi

# `repro` is host-side orchestration (clean-room checkout, then build + smoke in it),
# not an in-container target — run it directly and stop.
if [ "$TARGET" = "repro" ]; then
  exec "$HERE/repro.sh" "${@:2}"
fi

docker build -t "$IMAGE" "$HERE" >/dev/null
mkdir -p "$ROOT/build"
# Forward the optional knobs into the container when set (name-only -e reads the
# value from this script's environment — safe under `set -u` via :+).
exec docker run --rm \
  -v "$ROOT":/work \
  --user "$(id -u):$(id -g)" \
  -e HOME=/work/build \
  ${SMOKE_WANT:+-e SMOKE_WANT} \
  ${SMOKE_SETTLE:+-e SMOKE_SETTLE} \
  ${SNES_ROMPATH:+-e SNES_ROMPATH} \
  ${MOS_TOOLCHAIN:+-e MOS_TOOLCHAIN} \
  ${BUILD_JOBS:+-e BUILD_JOBS} \
  "$IMAGE" bash "/work/dev/${TARGET}.sh"
