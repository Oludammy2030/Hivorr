# EP-00-001 — Decision record and amendment log

Task: **EP-00-001 — Toolchain, lockfile and first commit**
Recorded: 2026-11-06
Status: **`Verified`** — G2 acceptance recorded 2026-11-06 (§G2 below). The phase remains `In build`.

This record exists because the approved Task Implementation Plan (§13 "Platform honesty", §20)
requires every pre-implementation decision to be written down where the next contributor looks,
rather than discovered from a failed build. It amends nothing in the approved plan or phase plan;
it records only what was decided and why.

---

## PC-01 — Platform path (finding F-01)

**Decision: Option C — local-only execution, with the lockfile pinned.**

| Field | Value |
|---|---|
| Chosen | `pnpm install --force --frozen-lockfile` on the Windows workstation |
| Committed configuration change | **None.** `pnpm-workspace.yaml` and `.mise.toml` are byte-identical to the starting tree |
| Rejected — A | WSL2 is not installed, the session is non-elevated (`Administrators` is deny-only), and the feature cannot be enabled without elevation and a reboot |
| Rejected — B | Adding `win32` to `supportedArchitectures` would edit `pnpm-workspace.yaml`, which this task's own Definition of Done (§18, line 393) and plan §5 forbid |

**Effect.** `--force` bypasses the platform filter, so all 321 platform variants resolve into
`node_modules/`. `--frozen-lockfile` guarantees the lockfile cannot be rewritten: the SHA-256 is
identical before and after (`DAF9AC73BCE30FCD6C94027CFD03582FF4196021FE4477611DC32B8EA9E27167`).

**Known parity gap.** A plain `pnpm install --frozen-lockfile` on Windows installs only the Linux
native binaries that `supportedArchitectures` selects; `--force` is required locally to build. CI
runs Linux and is unaffected. This gap disappears when either CI is the only build environment or
an architect-approved `supportedArchitectures` amendment is made in a later task.

**Consequence for T4.** `pnpm build` is verified on this workstation only through the `--force`
install. The clean-clone replay (T10) reproduces the same command sequence from the tag.

---

## PC-02 — Commit identity

Name: `Prince Abidemi Oluwadamilare` (governance signatory on `EP-00-000`).
Email: `oludammy2030@gmail.com`.
Set with `git config --local` only. Author and committer of `8029466` and tagger of
`v0.0.1-bootstrap`; the identity was supplied by the founder and was not invented by an agent.

---

## PC-03 — Tag style

Annotated `v0.0.1-bootstrap`, message naming the task, the toolchain versions and the verification
result. Provenance (tagger + date) is the point of a bootstrap tag.

---

## PC-04 — Line endings

`.gitattributes` gains, at the top of the file:

```
*                    text=auto eol=lf
```

so Windows and Linux checkouts are byte-identical. The existing LFS rules below it override with
`-text`, so binaries are unaffected. Approved as a scope amendment before the first commit — the
only cheap moment to set repository-wide normalisation. Without it, `core.autocrlf = true` would
check the tree out as CRLF on Windows and produce format-gate noise in `EP-00-004`.

One file, `documents/Engineering-Execution/Engineering-Execution-Structure/ENGINEERING_EXECUTION_STRUCTURE.md`,
was stored with CRLF; `git add` normalised it to LF and warned once. No content changed.

---

## Cross-reference — `EP-00-012`

`EP-00-001` T3 initially failed with 47 type errors (46 in `src/app/App.tsx`, 1 in
`vite.figma.config.ts`). Per plan §6.5 the work stopped and a separate founder-approved package was
opened: **`EP-00-012 — Prototype typecheck remediation`**. It is included in this tree and is a
prerequisite for T3, not a widening of `EP-00-001`.

---

## Verification status at the time of writing

| Test | Result |
|---|---|
| T1 before | Failed as designed — `ERR_PNPM_OUTDATED_LOCKFILE`, 4 extras + 5 mismatched specifiers |
| T2 importer parity | Pass — 62 entries (53 + 9), zero caret specifiers |
| T1 after | Pass — frozen install exits 0, lockfile hash unchanged |
| T3 typecheck | Pass — exit 0 after `EP-00-012` |
| T4 build | Pass — exit 0, `dist/` produced (4 files, 611,906 bytes) via `--force` install |
| T5 ignore proof | Pass — `node_modules/ dist/ .env coverage/ .pnpm-store/` ignored; `.env.example` negated |
| T6 staged scan | Pass — 102 paths, no denied path, no credential-shaped string; seeded fixture proved the check can fail |
| T7 LFS | Pass — `git add -A` completed against `git-lfs/3.8.1` |
| T8 protected files | Expected delta only — `pnpm-lock.yaml`, `.gitignore`, `.gitattributes`, plus the two `EP-00-012` source fixes |
| T9 history integrity | Pass with a recorded delta — annotated tag `v0.0.1-bootstrap` resolves to `8029466`, the bootstrap commit; `HEAD` has since advanced (see §G2.2) |
| T10 clean-clone replay | Pass under PC-01 — frozen install and typecheck exit 0 without `--force`; build exits 0 only after `--force --frozen-lockfile`, lockfile hash unchanged |

---

## G2 — Acceptance record

**Accepted:** 2026-11-06 by Prince Abidemi Oluwadamilare, holding the architect and founder roles
(`EES` §5.1 — the roles are recorded separately and are not merged; the `DEV-001` second-reviewer
arrangement remains the compensating control).

Class: `[REVIEW]`. This is the G1 → G2 transition for `EP-00-001`.

### G2.1 — Accepted deviation: Windows build parity (PC-01)

`T10` as written ("frozen install → typecheck → build") does not pass on the Windows workstation,
because `supportedArchitectures.os: [linux]` filters the native optional packages. Reproduced from
a clean clone at the tag:

| Step | Result |
|---|---|
| `pnpm install --frozen-lockfile` | exit 0, lockfile unchanged |
| `pnpm typecheck` | exit 0 |
| `pnpm build` | exit 1 — `Cannot find module @rollup/rollup-win32-x64-msvc` |
| `pnpm install --force --frozen-lockfile` then `pnpm build` | exit 0 — `dist/` 4 files, 611,906 bytes |

**Accepted on the basis that** the lockfile is provably unchanged before and after `--force`
(`DAF9AC73BCE30FCD6C94027CFD03582FF4196021FE4477611DC32B8EA9E27167`), so the committed artefact is
not platform-tainted, and CI on Linux — the reference environment — is unaffected. The gap is local
only and is re-examined in `EP-00-002` (CI/local parity), which is the correct owner.

### G2.2 — Accepted deviation: tag does not point at `HEAD`

`T9` checks that the annotated tag resolves to `HEAD`. At tagging time it did. `HEAD` then advanced
by one documentation commit, `e96ed89` (`docs(ep-00-000): approve DoD with recorded FA-14
exception`), which does not belong to the `EP-00-001` change surface.

**Accepted on the basis that** the tag correctly marks the bootstrap tree (`8029466`, 103 paths), and
re-pointing it at a later governance commit would misrepresent what `v0.0.1-bootstrap` contains. The
check is read as "resolved to `HEAD` at tagging time"; the delta is permanent and intentional.

### G2.3 — Accepted inclusion: `EP-00-012`

The bootstrap commit contains the `EP-00-012` type fixes (`src/app/App.tsx`,
`vite.figma.config.ts`) and its work-package record. This exceeds the original two-file change
surface (`.gitignore` comment + generated `pnpm-lock.yaml`) and is accepted because the fixes were
required for `T3` to pass at all, were approved as a separate bounded package, and contain no visual
or behavioural change and no type suppression.

### G2.4 — Tag provenance corrected

The original annotated tag object (`e5752d2`) stated that pnpm `10.34.3` was executed. Every
verification run used `10.34.9`, the repository pin. With no remote, no consumer and no CI depending
on the tag object, it was deleted and re-created at the same commit (`8029466`) with the corrected
toolchain line. New tag object: `e6fcd38`. The tagged tree is byte-identical.

### G2.5 — Status

`EP-00-001` moves `Ready` → `Verified`. `EX-19` and the commit half of `EX-12` are closed. The phase
remains `In build` (`QUA-37`). `EP-00-002` is the next item and inherits the PC-01 parity gap.
