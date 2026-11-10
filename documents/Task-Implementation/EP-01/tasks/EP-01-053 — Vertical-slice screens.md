# EP-01-053 — Vertical-slice screens

## 1. Task identification

| Field | Value |
|---|---|
| **Task ID** | `EP-01-053` |
| **Task title** | Vertical-slice screens |
| **Parent phase** | `EP-01` — Core Platform Foundation & Infrastructure |
| **Priority** | High |
| **Class** | `[REVIEW]` — wired slice |
| **Execution order** | 30 of 39 |
| **Governing plan** | EP-01 phase plan §11, Stage F |
| **Dependencies** | `EP-01-032`, `EP-01-034`, `EP-01-035`, `EP-01-051`, `EP-01-052` |

## 2. Objective

Wire the EP-01 slice — sign-in with MFA, registration, reset/verification capture, session bootstrap,
the activity switcher/activation and a labelled deny path — against `@hivorr/api-client`, with the
sign-in screen matching the prototype exactly at 375 / 768 / 1280.

## 3. Rulings that unblocked the task

| ID | Ruling (2026-11-10) |
|---|---|
| `F-47` | Add `--hivorr-gradient-auth` and the two deep-blue anchors to `theme.css`. Additive; no existing rendering changes. |
| `F-48` | Registration uses Full name, Email and Password. Phone and Country are deferred, and this divergence is accepted for EP-01. |
| `F-46` | Approved URLs: `/forgot-password`, `/reset-password`, `/verify-email`. The token is read from the query, never the path. |

## 4. Scope

### 4.1 Included

- `src/features/identity/` — sign-in, MFA challenge, registration, reset request, reset completion,
  email verification, session bootstrap, one API client.
- `src/features/profile/` — activity switcher and activation, with a labelled denial message.
- The three approved recovery URLs added to `@hivorr/shared`.
- `slice.html` + `src/slice-main.tsx` — the runnable slice entry, mounted through `@hivorr/app-shell`.
- `scripts/slice-screen-parity.mjs` — exact sign-in comparison against the prototype at three widths.
- Tests: sign-in anatomy, approved registration divergence, recovery screens, activity pending state.
- Theme tokens: auth gradient and deep-blue anchors.

### 4.2 Excluded / recorded

- Live API E2E. No staging API on the current image serves the session/activity routes (`F-49`); `063`.
- Phone and Country registration fields (`F-48` accepted divergence).
- An onboarding screen; `/onboarding` redirects to `/login` in the slice rather than rendering a blank.
- Navigating to the full dashboard routes. They are outside the slice and would 404; activation reports
  success inline instead.
- Pixel parity for registration (divergence), recovery and the activity screen. Sign-in is exact.
- Any change to `src/app/App.tsx`.

## 5. Requirements

| ID | Requirement | Source |
|---|---|---|
| R-01 | Every call uses `@hivorr/api-client`. | Plan `053` |
| R-02 | Sign-in matches the prototype at three widths. | Plan `053` |
| R-03 | The MFA challenge is handled, not a dead end. | API contract |
| R-04 | Registration uses only API fields. | `F-48` ruling |
| R-05 | Reset/verification use the approved URLs and query token. | `F-46` ruling |
| R-06 | Session bootstrap redirects on loading/anonymous/authenticated. | Plan `053` |
| R-07 | Activity activation is available and denial is labelled. | Plan `053` |
| R-08 | No dead controls; keyboard focus is preserved. | `AGENTS.md` §2.11 |
| R-09 | No raw hex outside the token layer. | `AGENTS.md` §2.12 |

## 6. Implementation plan

1. Record the three rulings and add the approved tokens and routes.
2. Build the identity screens against the generated client.
3. Build the activity switcher with activation and a labelled denial.
4. Mount the slice entry through the app shell.
5. Add the slice screen parity and unit tests.
6. Run the gates and the approved baseline.

## 7. Existing components and reusability

| Existing asset | Decision | Reason |
|---|---|---|
| `@hivorr/design` Button/TextField/Pill | **Reuse** | Exact prototype parity |
| `@hivorr/app-shell` routes, 404, providers, session | **Reuse** | Already tested |
| `@hivorr/api-client` | **Reuse** | Generated methods |
| `@hivorr/shared` routes | **Extend** | Approved URLs |
| Approved visual baseline | **Reuse** | Sign-in comparison and no-drift check |
| Prototype screens | **Transcribe** | The visual authority |

**Must not be duplicated:** a second client, a second auth layout, a second activity map, or a second
session state.

## 8. Files and systems affected

| Path | Change |
|---|---|
| `src/styles/theme.css` | Auth gradient and deep-blue tokens (approved `F-47`) |
| `packages/shared/src/routes.ts` | Three approved URLs |
| `packages/design/src/tokens.ts` | Gradient reference |
| `src/features/identity/**` | Screens and client |
| `src/features/profile/**` | Activity switcher |
| `src/slice-main.tsx`, `slice.html` | Slice entry |
| `vite.config.ts` | Second rollup input |
| `scripts/slice-screen-parity.mjs` | **New** |
| `tests/slice-screens.test.tsx` | **New** |
| `tests/app-shell.test.tsx`, `tests/workspace-contracts.test.ts` | Route list |
| `package.json` | Slice parity script; API client and Query dependencies |

No API or migration changed.

## 9. Definition of Done

| # | Condition |
|---|---|
| DoD-01 | Sign-in matches the prototype exactly at 375/768/1280. |
| DoD-02 | Sign-in handles the MFA challenge. |
| DoD-03 | Registration uses name/email/password only. |
| DoD-04 | Reset and verification capture the query token and strip it from use. |
| DoD-05 | Session bootstrap redirects correctly. |
| DoD-06 | Activities can be activated; a denial is labelled. |
| DoD-07 | Every call uses the generated client. |
| DoD-08 | No raw colour outside the token layer. |
| DoD-09 | Keyboard focus is not removed. |
| DoD-10 | The approved baseline and design parity are unchanged. |
| DoD-11 | Local gates pass. |
| DoD-12 | Live staging E2E — deferred to `063` (`F-49`). |

## 10. Acceptance criteria

- `pnpm test:slice-parity` reports OK at three widths.
- `pnpm test -- tests/slice-screens.test.tsx` passes.
- The sign-in screen renders “Welcome back”, both fields and both links.
- Registration has no Phone/Country field.
- A token-less reset or verification link shows a labelled error.
- Activity activation shows a success or a labelled denial, never a silent failure.

## 11. Testing and validation

| Test | Method |
|---|---|
| T-01 | `pnpm test -- tests/slice-screens.test.tsx tests/app-shell.test.tsx` |
| T-02 | `pnpm test:slice-parity` after `pnpm build` |
| T-03 | `pnpm test:design-parity` |
| T-04 | Visual baseline capture + zero-tolerance diff |
| T-05 | Full suite, typecheck, lint, boundaries, format, config |
| T-06 | Live staging E2E — `063` |

## 12. Risks and considerations

| Risk | Handling |
|---|---|
| The screen diverges from the prototype. | Sign-in is pixel-compared; registration divergence is ruled. |
| A capability is treated as authority. | The client never gates writes; the API denies and the UI labels it. |
| A token leaks in the URL. | The token is read from the query; the URL is not persisted or logged. |
| The slice ships in the web bundle. | `slice.html` is a separate entry; the prototype `index.html` is unchanged. |
| No live API locally. | Unit/SSR tests and the parity harness; E2E is `063`. |
| Registration lacks phone/country. | Accepted `F-48` divergence. |

## 13. Execution status

| Field | Value |
|---|---|
| **Status** | `REQUIRES_REVIEW` |
| **Started** | 2026-11-10 |
| **Code complete** | 2026-11-10 |
| **Closes when** | The CI run is green and `063` proves the slice against the deployed API |
| **Execution record** | `execution-records/EP-01-053.md` |
