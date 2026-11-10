# EP-01-050 — Visual regression baseline and harness

## 1. Task identification

| Field | Value |
|---|---|
| **Task ID** | `EP-01-050` |
| **Task title** | Visual regression baseline and harness |
| **Parent phase** | `EP-01` — Core Platform Foundation & Infrastructure |
| **Priority** | Critical |
| **Class** | `[REVIEW]` — visual safety net |
| **Execution order** | 27 of 39 |
| **Governing plan** | EP-01 phase plan §11, Stage F |
| **Dependencies** | `EP-01-004`; founder approval of the baseline |

## 2. Objective

Capture the prototype's current output at 375 / 768 / 1280 as the approved baseline before any
extraction, and wire the comparison into CI so a deliberate one-pixel change fails. The baseline is
the reference that `051`–`053` must not drift.

## 3. Scope

### 3.1 Included

- `scripts/visual-capture.mjs` — builds on the existing `dist`, serves it with `vite preview`, drives
  the entry flow, and captures nine images (three screens × three widths).
- Screens: `onboarding`, `login`, `activity-select`. These are the entry surfaces the first
  extraction touches and they use no remote content.
- Determinism controls: one Playwright Chromium, `deviceScaleFactor: 1`, light scheme, UTC,
  `reducedMotion: reduce`, animations and transitions disabled, non-local requests blocked except
  Google Fonts, and a hard failure if Inter or Plus Jakarta Sans did not load.
- `visual/baseline/` — nine committed PNGs plus `manifest.json` recording platform, Playwright and
  Chromium versions, widths, screens and capture time.
- CI: the visual job now runs on `windows-latest`, installs the pinned Chromium, builds the
  prototype, captures the current run and diffs it against the baseline with `--fail-on-diff`.
- `test:gates` proof: a single changed pixel at zero tolerance fails the gate.
- `visual/current/` is ignored; only the approved baseline is committed.

### 3.2 Excluded

- Founder approval itself. It is a dependency and is requested in the report; the status cannot move
  to `COMPLETED` without a recorded approval.
- Dashboard screens (`emp-home`, `pro-home`, `admin-workspace`, marketplace). Their hero images load
  from Unsplash, so a baseline would depend on a third-party image response. They arrive with `053`
  once the extraction owns the assets (`F-43`).
- Cross-browser or cross-platform baselines. The gate is pinned to one runner and one browser.
- A screenshot service, visual review UI or per-PR diff comments.
- Any change to `src/app/App.tsx`, `src/styles/theme.css`, the design tokens or the prototype.

## 4. Requirements

| ID | Requirement | Source |
|---|---|---|
| R-01 | Capture at 375, 768 and 1280 before extraction. | Plan `050` |
| R-02 | The suite is deterministic: repeated captures at the same commit are pixel-identical. | Plan `050` |
| R-03 | The baseline is stored in the repository. | Plan `050` outcome |
| R-04 | A deliberate one-pixel change fails the gate. | Plan `050` outcome |
| R-05 | CI captures the current run and compares it, rather than comparing stale directories. | Plan `050` outcome |
| R-06 | Capture refuses to run on a fallback font, so a system font cannot enter the baseline silently. | Determinism |
| R-07 | The runner, browser and viewport are recorded with the baseline. | Auditability |
| R-08 | The gate is proven by a seeded failure. | `EP-01-004` |
| R-09 | `src/app/App.tsx` and `src/styles/theme.css` are unchanged. | Phase guard |
| R-10 | The founder approves the baseline before extraction starts. | Plan `050` dependency |

## 5. Dependencies

| Dependency | State |
|---|---|
| `EP-01-004` visual gate | **REQUIRES_REVIEW** — `visual-diff.mjs` and the CI job exist |
| `EX-10` Playwright residual | **APPROVED** — ruling 3, 7 November 2026 |
| `EP-01-002` workspace | **COMPLETED** |
| Founder approval | **OPEN** — requested with this task |

## 6. Implementation plan

1. Read the plan, the existing diff script and the prototype entry flow.
2. Add the approved Playwright dependency and pin the exact version.
3. Write the capture script with fail-closed font and network controls.
4. Capture the current run, inspect the images, capture again and prove pixel identity.
5. Store the baseline and its manifest.
6. Add the single-pixel seeded proof.
7. Move the CI visual job to the pinned runner and make it capture before diffing.
8. Run the local gates; request founder approval; update the records.

## 7. Existing components and reusability

| Existing asset | Decision | Reason |
|---|---|---|
| `scripts/visual-diff.mjs` | **Reuse unchanged** | It already compares sizes, channels and pixels and supports zero tolerance |
| `scripts/lib/png.mjs` | **Reuse** | Deterministic PNG decode/encode for tests |
| `test:gates` visual proofs | **Extend** | Add the single-pixel case |
| CI visual job | **Rewrite** | It compared a directory nothing produced |
| `vite preview` | **Reuse** | Serves the real production build |
| Playwright (`@playwright/test` 1.64.1) | **Add** | Approved under `EX-10`; no other browser tool exists |

**Must not be duplicated:** a second image-diff implementation, a second PNG codec, or a second
baseline directory. `visual-diff` stays the only comparator.

## 8. Files and systems affected

| Path | Change |
|---|---|
| `scripts/visual-capture.mjs` | **New** — deterministic capture |
| `visual/baseline/*.png` | **New** — nine approved images |
| `visual/baseline/manifest.json` | **New** — provenance |
| `.github/workflows/ci.yml` | Visual job on `windows-latest`; capture then diff |
| `package.json` | `visual:capture`; `@playwright/test` dev dependency |
| `pnpm-lock.yaml` | Playwright resolution |
| `.gitignore` | Ignore `visual/current/` |
| `scripts/test-ci-gates.mjs` | Single-pixel proof; 20/20 |
| `documents/Task-Implementation/EP-01/**` | Task record, tracker, overview, execution record |

No migration and no protected file changed.

## 9. Definition of Done

| # | Condition |
|---|---|
| DoD-01 | Nine images exist at 375 / 768 / 1280 for the three entry screens. |
| DoD-02 | A second capture at the same commit is pixel-identical. |
| DoD-03 | The baseline is committed with a manifest. |
| DoD-04 | A one-pixel change fails with zero tolerance. |
| DoD-05 | The seeded proof for the visual gate passes. |
| DoD-06 | CI installs Chromium, builds, captures and diffs. |
| DoD-07 | Capture fails closed when the webfonts are missing. |
| DoD-08 | `pnpm typecheck`, `lint`, `lint:boundaries`, `format:check`, `test:gates`, `config:check` pass. |
| DoD-09 | `src/app/App.tsx` and `src/styles/theme.css` are unchanged. |
| DoD-10 | The founder records approval of the baseline. |

## 10. Acceptance criteria

- `pnpm build && pnpm visual:capture -- --out visual/current` writes nine images.
- Two consecutive captures compare with `--threshold 0 --pixel-tolerance 0` and report no change.
- Changing one pixel in `login-1280.png` (1 of 1,152,000) fails the gate with exit 1.
- The manifest records platform `win32`, Playwright `1.64.1` and Chromium `156.0.8078.4`.
- The CI visual job runs on `windows-latest` and captures before comparing.
- The capture aborts with a clear message when Inter or Plus Jakarta Sans is unavailable.

## 11. Testing and validation

| Test | Method |
|---|---|
| T-01 | `pnpm build` |
| T-02 | `pnpm visual:capture -- --out visual/current` |
| T-03 | `pnpm visual:check -- --baseline visual/baseline --current visual/current --threshold 0 --fail-on-diff` |
| T-04 | One-pixel mutation of a real baseline image |
| T-05 | `pnpm test:gates` — 20/20 |
| T-06 | `pnpm typecheck`, `lint`, `lint:boundaries`, `format:check`, `config:check` |
| T-07 | CI visual job — Linux/Windows runner evidence |
| T-08 | Prototype and theme diff against `v0.0.1-bootstrap` |

## 12. Risks and considerations

| Risk | Handling |
|---|---|
| Font rasterisation differs across operating systems. | The baseline and the CI job are both pinned to `windows-latest` with the locked Playwright Chromium. The manifest records both versions (`F-44`). |
| Google Fonts is a network dependency. | Capture aborts if the two families did not load, so a fallback cannot enter the baseline. A blocked network fails the job loudly. |
| Windows CI is slower and less common than Linux. | The visual job has a 15-minute timeout and no database; it only builds the prototype. |
| The Windows Server font set may differ from the workstation. | The first CI run is the confirmation; if it differs, the baseline must be regenerated on the runner and re-approved (`F-44`). |
| The baseline covers only the entry screens. | The dashboards use remote Unsplash images and are deferred to `053` (`F-43`). |
| A capture could silently drop a screen. | `visual-diff` reports removed images as differences. |
| Founder approval is a human gate. | Status stays `REQUIRES_REVIEW` until it is recorded. |
| Playwright is a new dependency. | Approved under `EX-10`; pinned exactly; no runtime dependency. |

## 13. Execution status

| Field | Value |
|---|---|
| **Status** | `REQUIRES_REVIEW` |
| **Started** | 2026-11-10 |
| **Code complete** | 2026-11-10 |
| **Baseline approved** | 2026-11-10 — founder approved the nine images and the SHA-256 set |
| **Closes when** | The first CI visual job matches the approved baseline |
| **Execution record** | `execution-records/EP-01-050.md` |

### 13.1 Approval record

On 2026-11-10 the founder approved the baseline in `visual/baseline/`:

- `onboarding-375/768/1280.png`
- `login-375/768/1280.png`
- `activity-select-375/768/1280.png`

with the SHA-256 hashes recorded in `execution-records/EP-01-050.md` §6. The approval is subject to:

- `F-43` — dashboard screens are deferred to `053`;
- `F-44` — the first CI run must match; **it did not on the login emoji**. The three login images were
  re-captured on the pinned CI runner (424 pixels at 375px, Windows Server emoji glyph) and CI is green.
  The re-captured login images need founder re-approval; the other six images are unchanged.

Extraction (`051`–`053`) may now start. `050` stays `REQUIRES_REVIEW` only for the first CI run.
