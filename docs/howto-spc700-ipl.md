# SPC700 IPL provisioning

MAME's SNES driver needs Nintendo's 64-byte SPC700 IPL at
`dev/roms/s_smp/spc700.rom`. The directory is gitignored because the firmware is
copyrighted and must not be committed. The retrievable project copy is the AWS
SSM SecureString `/llvm-mos-65816/snes/spc700_ipl_b64` in `us-west-2`.

## Fetch and verify

Configure the project AWS profile `65816-terraform`, then run:

```sh
task spc700
task spc700:check
```

The fetch is cached: a local file whose size and SHA-1 are correct causes no AWS
call. A cold fetch decodes into a temporary file, verifies 64 bytes and SHA-1
`97e352553e94242ae823547cd853eecda55c20f0`, and only then atomically installs it.
`dev/run.sh` performs this host-side preflight for tests that use the shared MAME
gate; credentials are never mounted into the development container.

Set `SPC700_AWS_PROFILE`, `SPC700_AWS_REGION`, or `SPC700_SSM_PARAMETER` to
override their defaults. `SNES_ROMPATH` changes the local ROM directory.

## Re-seed after total loss

Obtain a known-good IPL through an authorized out-of-band source, verify its
provenance, and run:

```sh
task spc700:seed ROM=/path/to/spc700.rom
```

The command validates the file before making any AWS call and refuses to replace
an existing parameter. After confirming replacement is intended, use:

```sh
task spc700:seed ROM=/path/to/spc700.rom -- --force
```

GitHub Actions may retain `SNES_SPC700_ROM_B64` as a deployment copy, but GitHub
secrets are write-only: they can be consumed by CI but cannot be retrieved as a
backup. SSM is the source of truth because an authorized project principal can
read it back, verify it, and provision a clean machine.

## Verified behavior

On 2026-08-06 the SSM value round-tripped to the expected SHA-1; cold fetch, cache hit, invalid seed,
corrupt remote, atomic non-overwrite, and restore controls all passed. With the fetched IPL, the complete
14-configuration cartsize matrix passed MAME and bsnes-jg, the width-mode corpus passed 62/62 on both
emulators, and a 30-test c-torture slice passed all configurations. Full raw summaries and the default
corpus runner's shorter-deadline limitation are recorded in
[`docs/plans/2026-08-06-spc700-ipl-ssm-and-mame-suite-unlock.md`](plans/2026-08-06-spc700-ipl-ssm-and-mame-suite-unlock.md).
