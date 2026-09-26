# Verified off-machine compiler-baseline backup — 2026-09-26

The five captured directories in `build/defect-baselines/` now have a private
Cloudflare R2 Standard backup. Downloaded archive parts were checked against the
original archive and the preserved source directory. The local originals remain
untouched. This is a one-time backup, not a scheduled backup service or retention
lock, and it does not change any compiler-defect status.

Packaging and verification: OpenAI Codex CLI 0.157.0 (`codex-tui`), model
`gpt-6-astra`, `xhigh` reasoning effort; verified session
`01a0db16-f6a0-7e32-ada6-0c8098813933`. Captured evidence retains its earlier
attribution.

## Location and restore

- Account: `f7e1e6cd8b3414a6d2226152533c21f2`.
- Bucket: `llvm-mos-evidence`.
- Prefix: `defect-baselines/2026-09-26/03feae4f9611523d/`.
- Archive: `defect-baselines-2026-09-26.tar.zst`, 410,225,620 bytes.
- Archive SHA-256:
  `03feae4f9611523dc471f21003cbf33186f187a8e7944982d459359a7d585de7`.

The archive is stored as `.part00` and `.part01` to accommodate Wrangler 4.84.1's
300 MiB upload limit. Concatenation in that order yields the original archive
without recompression. The small metadata files are retained here as well as in
R2, so the remote location and original checksums are not confined to ignored
build outputs:

- [Restore instructions](../defects/evidence/2026-09-26-r2-baseline-backup/README.md).
- [Remote verification receipt](../defects/evidence/2026-09-26-r2-baseline-backup/remote-receipt.json).
- [Capture-time file inventory](../defects/evidence/2026-09-26-r2-baseline-backup/manifest.json).
- [Package checksums](../defects/evidence/2026-09-26-r2-baseline-backup/SHA256SUMS).
- [Original archive checksums](../defects/evidence/2026-09-26-r2-baseline-backup/ARCHIVE-SHA256SUMS).
- [Verification output](../defects/evidence/2026-09-26-r2-baseline-backup/verification.log).

The original inventory's `remote_backup: pending destination` is preserved as a
capture-time statement; the separate remote receipt records the later transfer.
Use a new empty directory for a restore. Do not overwrite immutable baselines.

## Verification and retention

All package files were downloaded with `wrangler r2 object get --remote` into
`/tmp/llvm-mos-r2-restore.a2KcKC`. The downloaded checksum file matched the local
copy byte-for-byte, and every listed checksum passed. Concatenating the downloaded
parts gave the original SHA-256; `cmp` against the original archive, `zstd -t`,
and `tar --compare` against `build/defect-baselines/` all exited zero.

The bucket's `r2.dev` URL is disabled and it has no custom domains. No object
expiration rule is configured. Its sole default lifecycle rule aborts incomplete
multipart uploads after seven days; it does not expire completed objects. Dated,
content-addressed names are a convention, not protection from an administrator
deleting objects. No new credentials or public access endpoints were created.

## Scope and missing evidence

The inventory contains 1,415 files, 141 symlinks, and 232 directories in:

- `2026-09-25-coalescing-0015`
- `2026-09-25-historical-recovery`
- `2026-09-25-mos-correctness`
- `2026-09-25-trunc-imag8-i1`
- `2026-09-26-far-memset`

Other build directories, host shared libraries, and container images are not
included. Some captured SDK aliases point to absent SDK-local clang names; those
links are preserved exactly. The far-memset commands use the separately archived
`bin/clang`. This is not a claim that every compiler is a hermetic runnable bundle.

The separate historical #320 failure behind patch 0023 still lacks its original
evidence. Backing up reconstructed probes does not recover that evidence or close
the report; see the [qualified canonical record](../defects/mos-trunc-imag8-i1.json)
and the [defect evidence workflow](../howto-defect-evidence.md).
