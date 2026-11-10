# EP-01-054 — Four-bundle build and deployment targets

## 1. Task identification

| Field | Value |
|---|---|
| **Task ID** | `EP-01-054` |
| **Task title** | Four-bundle build and deployment targets |
| **Parent phase** | `EP-01` — Core Platform Foundation & Infrastructure |
| **Priority** | High |
| **Class** | `[REVIEW]` — build and release targets |
| **Execution order** | 31 of 39 |
| **Governing plan** | EP-01 phase plan §11, Stage F |
| **Dependencies** | `EP-01-002`, `EP-01-052` |

## 2. Objective

Produce four independent bundles (`web`, `control`, `staff`, `partner`) with per-app entries, shared
packages and enforced import boundaries; prove them in CI on every PR; keep the privileged bundles
noindex; keep the root web bundle inside the route-JS budget; and leave the Figma Make preview
unaffected.

## 3. Scope

### 3.1 Included

- `scripts/verify-bundles.mjs` and `pnpm bundles:check`:
  - all four bundle directories exist with an `index.html` and a JavaScript entry;
  - `control`, `staff` and `partner` carry `noindex, nofollow`;
  - each bundle's initial JavaScript is measured with gzip and compared with the 200 KB PER-01
    budget;
  - a missing referenced script is a failure.
- CI: `bundles:check` runs in the build job after `pnpm build:all`.
- `verify` includes `bundles:check` after the build.
- `tests/bundle-targets.test.ts` — release layout, unique portal outputs, noindex source, distinct
  workspace packages, shared build list, Figma preview entry.
- Three seeded-failure proofs: four good bundles pass; a privileged bundle without noindex fails; an
  over-budget initial bundle fails.
- Evidence run of the release manifest over the four built bundles.

### 3.2 Excluded

- Deploying the bundles to hosting. `060` provisions the environments; `061` promotes a build.
- Production indexability of the web bundle. The root build is the Figma Make preview in EP-01 and is
  deliberately `noindex` through `.figma/make/site.json`; `060` owns the production flip.
- Screens. `053` is blocked (`F-46`/`F-47`/`F-48`).
- New dependencies or a second build system.

## 4. Requirements

| ID | Requirement | Source |
|---|---|---|
| R-01 | Four bundles build from their own entries. | Plan `054` |
| R-02 | No bundle imports another app or the server. | `ARCHITECTURE.md` §14.4; boundary lint |
| R-03 | Privileged bundles carry `noindex, nofollow`. | Plan `054` outcome |
| R-04 | The root web initial JS stays within 200 KB gzip. | `PER-01` |
| R-05 | All four build in CI on every PR. | Plan `054` outcome |
| R-06 | The Figma Make preview is unaffected. | Plan `054` outcome |
| R-07 | The release manifest records exactly four bundles. | `ARCHITECTURE.md` §8.12 |
| R-08 | The gate is proven by seeded failures. | `EP-01-004` |

## 5. Dependencies

| Dependency | State |
|---|---|
| `EP-01-002` workspace | **COMPLETED** |
| `EP-01-052` shell | **REQUIRES_REVIEW** — not required for the bundles to build |
| `apps/*` scaffolds | Present from `002` |
| Release manifest | Present from `004`/`061` groundwork |

## 6. Implementation plan

1. Read the build script, portal configs, release layout and CI build job.
2. Build all four and measure the real output.
3. Add the bundle verification gate.
4. Add the unit test and the seeded proofs.
5. Wire the gate into CI and `verify`.
6. Re-check the visual baseline and the release manifest.
7. Update the records.

## 7. Existing components and reusability

| Existing asset | Decision | Reason |
|---|---|---|
| `scripts/build-portals.mjs` | **Reuse** | Already builds control/staff/partner |
| `pnpm build:all` | **Reuse** | Root web + portals in one command |
| `apps/*/vite.config.ts` | **Reuse** | Distinct `dist/portals/<app>` outputs |
| `BUNDLE_LAYOUT` | **Reuse** | Already the four-bundle release contract |
| `lint:boundaries` | **Reuse** | Enforces no cross-app imports at source |
| `test-ci-gates.mjs` | **Extend** | Seeded proofs for the new gate |
| `release-manifest.mjs` | **Reuse** | Records and verifies the four bundles |

**Must not be duplicated:** a second portal build script, a second bundle layout, or a second import
boundary check.

## 8. Files and systems affected

| Path | Change |
|---|---|
| `scripts/verify-bundles.mjs` | **New** |
| `tests/bundle-targets.test.ts` | **New** |
| `scripts/test-ci-gates.mjs` | Three seeded proofs |
| `package.json` | `bundles:check`; added to `verify` |
| `.github/workflows/ci.yml` | `bundles:check` in the build job |
| `documents/Task-Implementation/EP-01/**` | Task record, tracker, overview, execution record |

No app source, dependency, migration, secret or protected file changed.

## 9. Definition of Done

| # | Condition |
|---|---|
| DoD-01 | `pnpm build:all` produces `dist` and `dist/portals/{control,staff,partner}`. |
| DoD-02 | `pnpm bundles:check` passes and prints the four gzip sizes. |
| DoD-03 | Every privileged bundle is noindex; the web preview is deliberately noindex. |
| DoD-04 | Each initial bundle is ≤ 200 KB gzip. |
| DoD-05 | A privileged bundle without noindex fails the gate. |
| DoD-06 | An over-budget bundle fails the gate. |
| DoD-07 | No bundle imports another app or the server (boundary lint). |
| DoD-08 | The release manifest records and verifies all four bundles. |
| DoD-09 | The Figma Make preview entry and config are unchanged. |
| DoD-10 | `pnpm typecheck`, `lint`, `lint:boundaries`, `format:check`, `test:gates`, `config:check` pass. |
| DoD-11 | The approved visual baseline is unchanged. |

## 10. Acceptance criteria

- `bundles:check` prints `main 121.5 KB`, `control/staff/partner 71.0 KB` gzip at this commit.
- Deleting the noindex meta from `control` fails the gate.
- A 260 KB incompressible script in a bundle fails the gate.
- `release-manifest` reports `main, control, staff, partner` and verification passes.
- `src/main.tsx`, `vite.figma.config.ts` and `site.json` remain the preview entry.

## 11. Testing and validation

| Test | Method |
|---|---|
| T-01 | `pnpm build:all` then `pnpm bundles:check` |
| T-02 | `pnpm test -- tests/bundle-targets.test.ts` |
| T-03 | `pnpm test:gates` — 23/23 |
| T-04 | `pnpm release:manifest` + `pnpm release:verify` over the built bundles |
| T-05 | `pnpm typecheck`, `lint`, `lint:boundaries`, `format:check`, `config:check` |
| T-06 | Visual capture + zero-tolerance diff |
| T-07 | CI build job |

## 12. Risks and considerations

| Risk | Handling |
|---|---|
| A portal stops carrying noindex. | The gate fails; the unit test also checks the source HTML. |
| The web bundle grows past the budget. | Measured on the built artifact; the gate fails at 200 KB gzip. |
| The preview is mistaken for production. | `site.json` keeps it noindex; `060` owns the production target. |
| Portal size grows when screens arrive. | The budget is per bundle and leaves ~129 KB headroom at this commit. |
| A missing asset still passes. | The gate resolves every script referenced by `index.html`. |
| Boundary lint is the only import control. | It is the authoritative source-level check; the build does not re-bundle apps. |

## 13. Execution status

| Field | Value |
|---|---|
| **Status** | `REQUIRES_REVIEW` |
| **Started** | 2026-11-10 |
| **Code complete** | 2026-11-10 |
| **Closes when** | The CI build job runs `bundles:check` successfully |
| **Execution record** | `execution-records/EP-01-054.md` |
