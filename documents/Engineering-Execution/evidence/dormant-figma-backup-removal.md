# Maintenance Record — Dormant `.figma/backup` removal

| Field | Value |
|---|---|
| **Change** | Remove the dormant Figma Make backup manifest `.figma/backup/package.json` |
| **Date** | 2026-11-06 |
| **Class** | Repository maintenance. No product, architecture or security decision is taken |
| **Approval** | Founder selected this change explicitly on 2026-11-06 (Option A: delete the dormant tree) |
| **Predecessor evidence** | `EP-00-008` — Dependabot status and accepted risk; `EP-00-011` — residual risk `R-3` |
| **Branch** | `chore/remove-dormant-figma-backup`, based on `origin/staging` at `c6d7cdf` |
| **Rollback** | `git revert <commit>` restores the file byte-for-byte from history |

---

## 1. Why

`EP-00-008` recorded 24 open Dependabot alerts on the default branch, all in one manifest:
`.figma/backup/package.json`. The live alert snapshot on 2026-11-06 confirms the same position:

```text
$ gh api "repos/Oludammy2030/Hivorr/dependabot/alerts?state=open&per_page=100" --jq '…'
[{"count":24,"manifest":".figma/backup/package.json",
  "severities":[{"n":8,"severity":"high"},{"n":4,"severity":"low"},{"n":12,"severity":"medium"}]}]
```

No other manifest has an open alert. `EP-00-008` §Residual and accepted risk and `EP-00-011` `R-3`
both state that the tree is dormant and that removal is a later approved change. This is that change.

The alerts themselves are noise: the manifest is not installed, built, bundled or deployed. The cost
is that a genuine advisory on a shipped dependency could be hidden among 24 alerts that can never be
fixed without deleting an unused file.

## 2. Scope

Exactly one tracked file:

```text
.figma/backup/package.json    2,553 bytes    89 lines
```

Before state:

| Property | Value |
|---|---|
| SHA-256 | `ADE2D428CE6951917715E7D5D1E671A1BF1881570628CD252FA250A95019627D` |
| Git blob | `67da9a91b9373a6290cf898f877855df075d902b` |
| Added | `8029466` — the EP-00-001 bootstrap commit |

Nothing else is touched: `.figma/README.md`, `.figma/make/*`, `vite.figma.config.ts`,
`vite.config.ts`, `package.json`, `pnpm-lock.yaml` and every workflow remain unchanged.

## 3. Reference proof

The file was proven unreferenced before deletion.

| Check | Command | Result |
|---|---|---|
| Repository-wide string search | `grep -r "backup"` (all file types) | Only documentation and evidence mention it; no code, config or workflow |
| Root workspace membership | `pnpm-workspace.yaml` | `packages: ['.']` only — `.figma/backup` is not a workspace package |
| Figma install script | `.figma/make/install` | Runs `pnpm install` at the repository root; never enters `backup/` |
| Figma Vite config imports | `vite.figma.config.ts` | Imports `.figma/make/site.json`, `migrated-package-aliases.json`, `asset-filename-aliases.json`, `source-path-aliases.json`; serves `/.figma/make/kit.html`; ignores `**/.figma/**` for watching |
| Application Vite config | `vite.config.ts` | No `.figma` reference |
| CI workflows | `.github/workflows/*.yml` | No `.figma` or `backup` reference |
| TypeScript and package config | `tsconfig*.json`, `package.json`, `.gitignore`, `.gitattributes` | No `.figma` or `backup` reference |
| Git history | `git log --all -- .figma/backup` | Bootstrap commit plus two Dependabot branches (#6, #7) — no application change |

**Finding recorded, not resolved.** `EP-00-008` line 56 states the tree is "committed as-is under
`EX-06`/`EX-07`", but `standards` §13.3 defines `EX-06` (shadcn kit), `EX-07` (unused MUI/emotion and
Popper packages in `package.json`) and `EX-17` (`default_shadcn_theme.css`). None of them names
`.figma/backup`. The mapping is loose; this record states it rather than rewriting an approved record.

## 4. Change

```text
$ git rm -r .figma/backup
rm '.figma/backup/package.json'
```

Git does not track empty directories, so `.figma/backup/` no longer exists in the tree.

## 5. Verification

All gates were run locally on 2026-11-06. The pinned `mise`/`pnpm` toolchain is still unavailable in
this session (`EP-01-ENTRY-RECORD.md` `R-P1`), so the Node entry points were invoked directly.

| Gate | Command | Result |
|---|---|---|
| Secret scan | `node scripts/secret-scan.mjs` | **Pass** — clean, 192 files (was 193) |
| Lint | `node scripts/lint.mjs` | **Pass** — 20 baseline, 0 new, 0 stale |
| Typecheck | `node node_modules/typescript/bin/tsc --noEmit` | **Pass** — exit 0, no output |
| Tests | `node node_modules/vitest/vitest.mjs run` | **Pass** — 2 files, 18 tests |
| Format gate | `node scripts/format-check.mjs` | **Pass** — no changed formattable files |
| Build | `node node_modules/vite/bin/vite.js build --config vite.figma.config.ts` | **Pass** — 1,599 modules, `dist/` written in 6.86 s |

The build is the strongest proof that the deletion is inert: the whole application compiles and
bundles without the manifest.

### Expected effect on Dependabot

Dependabot scans the default branch. The 24 alerts stay open until this change reaches `main` and the
next scan runs; only then can the list be expected to fall to zero for this manifest. This record does
**not** claim the alerts are already cleared.

Open pull requests #6 (`vite`) and #7 (`react-router`) both target `.figma/backup`. They become
obsolete when the directory is gone and should be closed by their owner.

## 6. What this does not do

- It does not edit `EP-00-008` or `EP-00-011`. Marking `R-3` resolved in the closure record is the
  owner's fold-in act; an implementing agent does not rewrite approved records.
- It does not change the EP-01 status, entry gate or any `EP-01-001` decision. EP-01 remains `Blocked`.
- It does not remove the other dormant artefacts covered by `EX-06`, `EX-07` and `EX-17`.
- It does not touch `package.json`, `pnpm-lock.yaml`, the lockfile or any shipped dependency.
- It does not change the application, the prototype or the design system.

## 7. Rollback

```text
git revert <commit>
```

The file returns byte-for-byte; the SHA-256 above is the check. No cache, generated artefact, secret
or environment is involved.
