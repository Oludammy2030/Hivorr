# EP-01-051 — Design tokens and primitive extraction for the slice

## 1. Task identification

| Field | Value |
|---|---|
| **Task ID** | `EP-01-051` |
| **Task title** | Design tokens and primitive extraction for the slice |
| **Parent phase** | `EP-01` — Core Platform Foundation & Infrastructure |
| **Priority** | Critical |
| **Class** | `[REVIEW]` — design-system foundation |
| **Execution order** | 28 of 39 |
| **Governing plan** | EP-01 phase plan §11, Stage F |
| **Dependencies** | `EP-01-050` (approved 2026-11-10), `EP-01-002` |

## 2. Objective

Establish `packages/design` with the theme tokens and extract only the primitives the EP-01 slice
uses, without visual change. The extracted primitives must render exactly like the prototype at 375 /
768 / 1280, add no raw colour, and leave the dormant shadcn kit untouched.

## 3. Scope

### 3.1 Included

- `packages/design/src/tokens.ts` — CSS custom-property references for colour, type, radius and
  shadow. No values; `src/styles/theme.css` remains the only colour layer.
- `Button`, `TextField`, `Pill` — the three primitives the entry slice and every later screen need.
  Each is a direct transcription of the prototype's `Btn`, `Input` and `Pill`.
- Literal-to-token migration inside the extracted code only: `C.primary` → `var(--hivorr-blue)`,
  `#F4F6FB` → `var(--hivorr-surface-subtle)`, and so on. No restyling.
- Label association on `TextField` (a non-visual accessibility fix: `htmlFor`/`id`).
- `packages/design/README.md` — the boundary rules and evidence commands.
- `visual/primitives/` — a test-only gallery used by the parity check. Never part of a production
  build.
- `scripts/design-parity.mjs` and `pnpm test:design-parity` — exact computed-style and pixel
  comparison against the prototype at three widths.
- `tests/design-primitives.test.tsx` — token discipline, token existence, variants, sizes, disabled
  state and label association.
- CI: the visual job runs the parity check after installing Chromium.
- Root workspace dependency on `@hivorr/design`.

### 3.2 Excluded

- Rewiring screens to consume the package. That is `052` (router/providers) and `053` (slice screens).
- Extracting `Card`, `SelectField`, `StatCard`, `Section`, dialogs or shells. They are not used by the
  EP-01 slice yet, and extracting them now would be speculative.
- Adopting any shadcn component (`EX-06` remains dormant).
- New colours, gradients, shadows, dark mode or type sizes. `theme.css` is untouched.
- Changing `src/app/App.tsx`, `src/styles/theme.css`, the design tokens or the approved baseline.
- A per-primitive screenshot baseline. Parity is anchored to the prototype itself, which is stronger.

## 4. Requirements

| ID | Requirement | Source |
|---|---|---|
| R-01 | `packages/design` owns tokens and primitives; no second design source. | `ARCHITECTURE.md` §8.4 |
| R-02 | Tokens reference `theme.css`; the package adds no colour value. | `AGENTS.md` §2.12 |
| R-03 | Extracted primitives render exactly like the prototype at 375/768/1280. | Plan `051` |
| R-04 | Every variant and size the prototype defines is preserved. | Plan `051` |
| R-05 | Labels are associated with their fields. | `AGENTS.md` §2.11 |
| R-06 | The shadcn kit stays dormant. | `EX-06`, `ARCHITECTURE.md` §2.4 |
| R-07 | The approved visual baseline does not move. | `EP-01-050` |
| R-08 | A token reference that `theme.css` does not declare fails a test. | Token discipline |
| R-09 | The parity check runs in CI. | Plan `051` |
| R-10 | No production screen or protected file changes. | Phase guard |

## 5. Dependencies

| Dependency | State |
|---|---|
| `EP-01-050` baseline | **REQUIRES_REVIEW** — approved 2026-11-10; first CI run pending |
| `EP-01-002` workspace | **COMPLETED** |
| `EX-06` shadcn kit | Dormant by ruling; not adopted |
| `theme.css` | Protected input; read-only |

## 6. Implementation plan

1. Read the plan, `theme.css`, the prototype primitives and the visual-identity rules.
2. Define token references with no values.
3. Transcribe `Btn`, `Input` and `Pill` as `Button`, `TextField` and `Pill`.
4. Add the test-only gallery and the parity script.
5. Add token-discipline and rendering tests.
6. Add the workspace dependency and the CI step.
7. Prove parity at three widths and re-run the approved screen baseline.
8. Run the local gates; update the records.

## 7. Existing components and reusability

| Existing asset | Decision | Reason |
|---|---|---|
| `packages/design` boundary | **Filled** | It existed from `002` with the correct ownership |
| `src/styles/theme.css` | **Reuse read-only** | The only colour layer; no value is restated |
| Prototype `Btn`, `Input`, `Pill` | **Extract** | They are the visual authority |
| `scripts/visual-diff.mjs` / PNG codec | **Reuse** | Baseline comparison unchanged |
| `scripts/visual-capture.mjs` | **Reuse** | Re-checks the approved screens |
| Playwright 1.64.1 | **Reuse** | Installed in `050` |
| `test:gates` | **Unchanged** | No new gate category; the parity test is its own command |

**Must not be duplicated:** a second palette, a second button/field/pill, a second image comparator,
or a second screenshot harness.

## 8. Files and systems affected

| Path | Change |
|---|---|
| `packages/design/src/tokens.ts` | **New** |
| `packages/design/src/primitives/button.tsx` | **New** |
| `packages/design/src/primitives/text-field.tsx` | **New** |
| `packages/design/src/primitives/pill.tsx` | **New** |
| `packages/design/src/index.ts` | Exports |
| `packages/design/README.md` | Rules and evidence |
| `packages/design/package.json` | React peer dependency |
| `visual/primitives/index.html` | **New** — test-only gallery |
| `visual/primitives/main.tsx` | **New** |
| `scripts/design-parity.mjs` | **New** |
| `tests/design-primitives.test.tsx` | **New** |
| `package.json` | `test:design-parity`; `@hivorr/design` workspace dependency |
| `.github/workflows/ci.yml` | Parity step in the visual job |
| `documents/Task-Implementation/EP-01/**` | Task record, tracker, overview, execution record |

No migration, secret or protected file changed.

## 9. Definition of Done

| # | Condition |
|---|---|
| DoD-01 | `packages/design` exports tokens and the three primitives. |
| DoD-02 | The package contains no hex, `rgb()`, `hsl()` or second palette. |
| DoD-03 | Every `var(--…)` reference exists in `theme.css`. |
| DoD-04 | `Button` keeps all variants, sizes, disabled and hover behaviour. |
| DoD-05 | `TextField` keeps the fill, border, focus colour and label. |
| DoD-06 | `Pill` keeps the tone palette, radius and label-as-title. |
| DoD-07 | Parity passes exactly at 375 / 768 / 1280 (styles and pixels). |
| DoD-08 | The approved screen baseline is unchanged. |
| DoD-09 | The shadcn kit is not imported. |
| DoD-10 | `pnpm typecheck`, `lint`, `lint:boundaries`, `format:check`, `test:gates`, `config:check` pass. |
| DoD-11 | CI runs `test:design-parity` in the visual job. |
| DoD-12 | `src/app/App.tsx` and `src/styles/theme.css` are unchanged. |

## 10. Acceptance criteria

- `pnpm test:design-parity` reports `OK — 9 exact comparison(s) across 375/768/1280 px`.
- `pnpm test -- tests/design-primitives.test.tsx` passes nine checks.
- Removing a token from `theme.css` (in a fixture) or adding a hex to the package fails the unit test.
- `pnpm visual:capture` + `visual:check` against the approved baseline reports no change.
- `pnpm build` still succeeds and the gallery is absent from `dist`.

## 11. Testing and validation

| Test | Method |
|---|---|
| T-01 | `pnpm test -- tests/design-primitives.test.tsx` |
| T-02 | `pnpm test:design-parity` |
| T-03 | `pnpm build` + `pnpm visual:capture` + `pnpm visual:check -- --threshold 0 --fail-on-diff` |
| T-04 | `pnpm test:gates` |
| T-05 | `pnpm typecheck`, `lint`, `lint:boundaries`, `format:check`, `config:check` |
| T-06 | CI visual job |
| T-07 | Prototype and theme diff against `v0.0.1-bootstrap` |

## 12. Risks and considerations

| Risk | Handling |
|---|---|
| The prototype uses literals; token substitution can drift. | Parity compares computed styles and element pixels against the live prototype at three widths. |
| `theme.css` lacks a dedicated `--hivorr-gray`. | `colorTokens.gray` uses `var(--muted-foreground)`, which holds the same value; recorded as `F-45`. |
| Parity covers primitives, not composed screens. | Screens are covered by the approved baseline; `053` will render them from the package. |
| The gallery could leak into a production build. | It lives under `visual/` and nothing in `src/` imports it; the build check confirms `dist` has no gallery entry. |
| Google Fonts is a network dependency. | Parity fails closed if Inter or Plus Jakarta Sans did not load. |
| A new workspace dependency. | `@hivorr/design` is first-party and private; no registry package was added. |
| `TextField` adds `htmlFor`/`id`. | Non-visual; pixel parity still passes. |

## 13. Execution status

| Field | Value |
|---|---|
| **Status** | `REQUIRES_REVIEW` |
| **Started** | 2026-11-10 |
| **Code complete** | 2026-11-10 |
| **Closes when** | The CI visual job runs the parity check successfully |
| **Execution record** | `execution-records/EP-01-051.md` |
