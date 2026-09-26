# Compiler defect-baseline backup, 2026-09-26

Destination: private Cloudflare R2 Standard bucket `llvm-mos-evidence`, account
`f7e1e6cd8b3414a6d2226152533c21f2`, object prefix
`defect-baselines/2026-09-26/03feae4f9611523d/`.

The original archive is 410,225,620 bytes. Its SHA-256 is
`03feae4f9611523dc471f21003cbf33186f187a8e7944982d459359a7d585de7`.
Two byte-for-byte parts accommodate Wrangler 4.84.1's 300 MiB upload limit.
Part 00 is 209,715,200 bytes; part 01 is 200,510,420 bytes. Concatenate them in
numeric order to recover the original archive, without recompression.

`manifest.json` is the unchanged capture-time file inventory. Its
`remote_backup: pending destination` field describes capture time, not the later
transfer. `remote-receipt.json`, published only after the round-trip verification,
records the remote backup result. `SHA256SUMS` covers the uploaded package files;
`ARCHIVE-SHA256SUMS` covers the reconstructed archive and original manifest.

## Restore into a new directory

Requires an authenticated Wrangler CLI in PATH, GNU coreutils, tar, and zstd.
Log in to the account above using `wrangler login`, or use appropriately scoped
credentials. Never put credentials in this directory or the repository.

```sh
set -eu
restore_dir=$(mktemp -d)
cd "$restore_dir"
export CLOUDFLARE_ACCOUNT_ID=f7e1e6cd8b3414a6d2226152533c21f2
backup_prefix=llvm-mos-evidence/defect-baselines/2026-09-26/03feae4f9611523d
for name in README.md manifest.json ARCHIVE-SHA256SUMS SHA256SUMS remote-receipt.json \
  defect-baselines-2026-09-26.tar.zst.part00 \
  defect-baselines-2026-09-26.tar.zst.part01
do
  wrangler r2 object get "$backup_prefix/$name" --remote --file "$name"
done
sha256sum -c SHA256SUMS
cat defect-baselines-2026-09-26.tar.zst.part00 \
  defect-baselines-2026-09-26.tar.zst.part01 > defect-baselines-2026-09-26.tar.zst
sha256sum -c ARCHIVE-SHA256SUMS
zstd -t defect-baselines-2026-09-26.tar.zst
tar --zstd -xf defect-baselines-2026-09-26.tar.zst
```

The archive contains a top-level `defect-baselines/` directory. Keep the original
local `build/defect-baselines/` intact; never restore over preserved evidence.

## Scope and limitations

- Exact captured contents of `build/defect-baselines/`: five dated compiler
  baseline directories, associated files, resource headers, and symlinks.
- Other build directories, host shared libraries, and container images are not
  included. This is not a self-contained runnable environment for every compiler.
- SDK driver aliases pointing to absent SDK-local clang names are preserved as
  captured. The recorded far-memset commands explicitly use the separately
  archived `bin/clang`; the archive does not repair captured symlinks.
- No object-expiration rule is configured. The default seven-day abort rule
  applies only to incomplete multipart uploads, not completed backup objects.
- No retention lock or scheduled backup job is configured. Dated, content-hash
  prefixes are a naming convention, not protection against administrative deletion.
- This backup does not recover missing original evidence for the separate
  historical #320 failure behind patch 0023 and changes no defect status.

Packaging and transfer: OpenAI Codex CLI 0.157.0 (`codex-tui`), model
`gpt-6-astra`, `xhigh` reasoning effort; verified session
`01a0db16-f6a0-7e32-ada6-0c8098813933`. Earlier captured evidence retains its
original attribution.
