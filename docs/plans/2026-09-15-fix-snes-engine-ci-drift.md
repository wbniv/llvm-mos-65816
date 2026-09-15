# Fix `@wbniv/bsnes-jg-player` CI drift so both SNES sites can deploy again

## Context

Both consumer sites' deploy CI runs `npx bsnes-jg-player sync --check <dest>` as a hard gate
(`~/biohack.net/.github/workflows/deploy.yml:60`, `~/indri.studio/.github/workflows/deploy.yml:44`)
— it fails the deploy if the vendored-in engine copy under `public/` differs byte-for-byte from
what's actually installed in `node_modules/@wbniv/bsnes-jg-player`.

Both sites already have the **1.1.0 engine files vendored and committed** (biohack.net `a09b30f`,
already pushed to `origin/master`; indri.studio `1eed322`, committed but not yet pushed) — that's
the badge base-class fix (drops the browser-badge bug documented in
[the selfcheck plan](2026-07-28-gallery-per-image-selfcheck.md)) plus `.rp-badge.warn` styling.

But `node_modules` on both sites is still resolving the **old** commit:

```
$ grep bsnes-jg-wasm ~/biohack.net/pnpm-lock.yaml | head -1
specifier: github:wbniv/bsnes-jg-wasm#npm-package
version: .../tarball/1ec048f8c16daa7d5280d786781077ef93c66afc

$ grep '"version"' ~/biohack.net/node_modules/@wbniv/bsnes-jg-player/package.json
"version": "1.0.0"
```

Commit `1ec048f` on `~/bsnes-jg-wasm`'s `npm-package` branch is `1.0.0`. The two release commits
that bump it to `1.1.0` (`af2c4ca` bundle fix, `f1557ce` release prep) exist locally on that branch
but were **never pushed to origin** — both sites depend on
`"@wbniv/bsnes-jg-player": "github:wbniv/bsnes-jg-wasm#npm-package"` (a git ref, not a registry
version), so pushing that branch *is* the release. Until it's pushed, `pnpm update` on either site
has nothing newer to fetch, the vendored 1.1.0 files never match an installed 1.1.0 package, and
`sync --check` fails every deploy — this is the drift gate correctly catching an incomplete release,
not a bug in the gate.

## Approach

Three-step release, in dependency order — each step is a `git push`/registry-adjacent action, so
each one runs and is verified before the next:

1. **`~/bsnes-jg-wasm`: push `npm-package`.** `git push origin npm-package`. This is the actual
   release for both sites (see above) — no `npm publish` needed for them to pick it up.

2. **Per site (`~/biohack.net`, `~/indri.studio`), in either order:**
   - `pnpm update @wbniv/bsnes-jg-player` — repins `pnpm-lock.yaml` to the new commit/`1.1.0`.
   - `npx bsnes-jg-player sync --check <dest>` locally to confirm the drift is gone before pushing
     (`public/play` on biohack.net, `public/apps/llvm-mos-65816/play` on indri.studio).
   - Commit only `pnpm-lock.yaml` (nothing else — each site's working tree has unrelated in-flight
     changes from other agents that must not be swept into this commit).
   - `task bump` (both sites define it: auto-increment patch tag, `git push origin <branch> <tag>`)
     to push and fire the tag-triggered deploy workflow.

3. **Verify via CI, not a local build** — per [[site-builds-are-ci-only]]: `gh run list` for the
   conclusion on each site's repo, then confirm the live site's served engine version, not a local
   `pnpm build`.

Registry `npm publish` of `@wbniv/bsnes-jg-player` is optional per the original release plan and
not needed for either site — skipped here (see Out of scope).

## Mockups

No visible surface — this is dependency/CI plumbing, not a UI or content change (the badge fix
itself already shipped in the commits described above).

## Out of scope

- **`npm publish` to the public registry.** Only matters for outside consumers; neither site
  installs from the registry. Left for the user to trigger separately if wanted.
- **Gallery republish + `mode: "live-record"` manifest flip** (item (5) in
  [the selfcheck plan](2026-07-28-gallery-per-image-selfcheck.md)). That's the next stage of the
  separate per-image verify-fidelity button rollout, gated on its own ROM republish sequencing —
  not required to unblock the CI drift gate, which only compares engine files, not manifest mode.
- **`bsnes-jg-wasm`'s own unexercised retarget rows** (`running`/`fail` navigation states) —
  already tracked in that repo's own `TODO.md`.

## Verification

1. **`bsnes-jg-wasm` `npm-package` pushed; local HEAD matches `origin/npm-package`.**

```
$ cd ~/bsnes-jg-wasm && git push origin npm-package
To github.com:wbniv/bsnes-jg-wasm.git
   1ec048f..f1557ce  npm-package -> npm-package
```

**PASS** — origin now has the `1.1.0` release commits.

2. **`biohack.net`: lockfile repinned to the new commit, `sync --check` passes locally.**

```
$ pnpm update @wbniv/bsnes-jg-player
dependencies:
- @wbniv/bsnes-jg-player 1.0.0
+ @wbniv/bsnes-jg-player 1.1.0

$ npx bsnes-jg-player sync --check public/play
✓ ENGINE_VERSION  site has 1.1.0, installed package is 1.1.0
public/play matches @wbniv/bsnes-jg-player@1.1.0.
```

**PASS**.

3. **`indri.studio`: lockfile repinned to the new commit, `sync --check` passes locally.**

```
$ pnpm update @wbniv/bsnes-jg-player
dependencies:
- @wbniv/bsnes-jg-player 1.0.0
+ @wbniv/bsnes-jg-player 1.1.0

$ npx bsnes-jg-player sync --check public/apps/llvm-mos-65816/play
✓ ENGINE_VERSION  site has 1.1.0, installed package is 1.1.0
public/apps/llvm-mos-65816/play matches @wbniv/bsnes-jg-player@1.1.0.
```

**PASS**.

4. **`biohack.net`: tag pushed via `task bump`, CI run concludes `success`.**

```
$ task bump
Bumping v1.0.589 -> v1.0.590
   3c58c2c..ad4bf74  master -> master
 * [new tag]         v1.0.590 -> v1.0.590
```

CI run: [`34926081782`](https://github.com/wbniv/biohack.net/actions/runs/34926081782).

```
$ gh run view 34926081782 --json conclusion,status,jobs
{"conclusion":"success","status":"completed","jobs":[{"name":"deploy","conclusion":"success"}]}
```

**PASS**.

5. **`indri.studio`: tag pushed via `task bump`, CI run concludes `success`.**

```
$ task bump
Bumping v0.1.156 -> v0.1.157
   773af17..4819305  main -> main
 * [new tag]         v0.1.157 -> v0.1.157
```

CI run: [`34926111906`](https://github.com/wbniv/indri.studio/actions/runs/34926111906).

```
$ gh run view 34926111906 --json conclusion,status,jobs
{"conclusion":"success","status":"completed","jobs":[{"name":"deploy","conclusion":"success"}]}
```

**PASS**.

6. **Live sites serve the synced 1.1.0 engine** (no local build used to claim this).

```
$ curl -s https://biohack.net/play/ENGINE_VERSION
{"package": "@wbniv/bsnes-jg-player", "version": "1.1.0", ...}

$ curl -s https://indri.studio/apps/llvm-mos-65816/play/ENGINE_VERSION
{"package": "@wbniv/bsnes-jg-player", "version": "1.1.0", ...}
```

Both live, same SHA256s across both sites' `app.js`/`cores/*`. **PASS.**
