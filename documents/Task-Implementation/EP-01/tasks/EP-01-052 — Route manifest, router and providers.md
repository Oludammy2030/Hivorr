# EP-01-052 — Route manifest, router and providers

## 1. Task identification

| Field | Value |
|---|---|
| **Task ID** | `EP-01-052` |
| **Task title** | Route manifest, router and providers |
| **Parent phase** | `EP-01` — Core Platform Foundation & Infrastructure |
| **Priority** | Critical |
| **Class** | `[REVIEW]` — client runtime |
| **Execution order** | 29 of 39 |
| **Governing plan** | EP-01 phase plan §11, Stage F |
| **Dependencies** | `EP-01-003`, `EP-01-013`, `EP-01-050`, `EP-01-051` |

## 2. Objective

Replace the prototype's `Screen` union with a typed route manifest and a real router, register only the
EP-01 slice, render a real 404 for everything else, and provide session/capability context from
`GET /v1/session` as presentation-only state. Server state moves to TanStack Query.

## 3. Scope

### 3.1 Included

- New `@hivorr/app-shell` package: route manifest, routes, 404, providers, session context.
- `SLICE_ROUTE_IDS` — `/`, `/login`, `/signup`, `/onboarding`, `/activities`.
- `SliceRoutes` — registers a slice route only when a screen is supplied; everything else falls to
  `NotFound`. A missing screen fails closed instead of rendering blank.
- `NotFound` — a real, labelled 404 using design tokens, outside the prototype screens.
- `AppProviders` — `QueryClientProvider` + `SessionProvider`; no persistence.
- `sessionQueryOptions` — the single `GET /v1/session` query definition.
- `sessionStateFrom` — pure mapping to `loading` / `authenticated` / `anonymous` / `error`;
  `presentedCapabilities` and `canPresent` are explicitly presentation-only.
- TanStack Query added (pinned `5.105.3`, the newest version inside the 7-day release-age policy).
- Tests: route coverage, slice-only reachability, 404 for unknown and out-of-slice paths, missing
  screen, the session query, and all four session states (including server-rendered provider output).

### 3.2 Excluded

- Screen implementations and wiring. `053` supplies the screens to `SliceRoutes`.
- Mounting the shell in `src/main.tsx`. The prototype stays a static visual reference.
- The four application bundles and per-portal shells. `054`.
- Password-reset and email-verification URLs. The approved URL table does not define them; recorded
  as `F-46` rather than invented.
- Persisting the session or capabilities; service-worker caching; optimistic capability grants.
- Changing `src/app/App.tsx`, `src/styles/theme.css`, the API or the database.

## 4. Requirements

| ID | Requirement | Source |
|---|---|---|
| R-01 | The manifest declares every approved route family. | Plan `052` |
| R-02 | Only the slice routes are reachable. | Plan `052` outcome |
| R-03 | Unknown paths render a real 404. | Plan `052` outcome |
| R-04 | A slice route without a screen fails closed. | Fail-closed rule |
| R-05 | Session state comes only from `GET /v1/session`. | Plan `052` outcome |
| R-06 | Capabilities are presentation-only and never persisted. | `ARCHITECTURE.md` §8.8 |
| R-07 | A 401 is `anonymous`; other failures are `error`. | Auth correctness |
| R-08 | Server state uses TanStack Query. | `ARCHITECTURE.md` §8.7 |
| R-09 | The 404 is labelled and keyboard reachable, not colour-only. | `AGENTS.md` §2.11 |
| R-10 | No screen, protected file or API contract changes. | Phase guard |

## 5. Dependencies

| Dependency | State |
|---|---|
| `EP-01-003` shared contracts | **COMPLETED** — `ROUTES` vocabulary |
| `EP-01-013` generated client | **REQUIRES_REVIEW** — `SessionResponse` and `session()` |
| `EP-01-050` visual baseline | **REQUIRES_REVIEW** — approved; first CI run pending |
| `EP-01-051` design package | **REQUIRES_REVIEW** — tokens and primitives |
| TanStack Query | Added here per `ARCHITECTURE.md` §8.7 |

## 6. Implementation plan

1. Read the approved URL families, the state tiers and the generated client.
2. Create the shell package and the slice manifest.
3. Add `SliceRoutes` and the real 404.
4. Add the query client and the session query.
5. Map the query to presentation state; keep authority on the server.
6. Add route, 404 and session tests.
7. Add workspace wiring and run the local gates.
8. Re-check the approved visual baseline and update the records.

## 7. Existing components and reusability

| Existing asset | Decision | Reason |
|---|---|---|
| `@hivorr/shared` `ROUTES` | **Reuse** | Already the approved vocabulary; no second list |
| `@hivorr/api-client` `session()` | **Reuse** | Generated; no hand-written fetch |
| `@hivorr/design` tokens | **Reuse** | The 404 uses the approved palette |
| `react-router` 7 | **Use** | Already a dependency, previously unused |
| TanStack Query | **Add** | Recorded decision in `ARCHITECTURE.md` §8.7 |
| Prototype `Screen` union | **Not reused** | It is the pattern being replaced |

**Must not be duplicated:** a route path list, a session fetcher, a capability list, or a 404 page.

## 8. Files and systems affected

| Path | Change |
|---|---|
| `packages/app-shell/package.json` | **New** package |
| `packages/app-shell/src/route-manifest.ts` | **New** |
| `packages/app-shell/src/routes.tsx` | **New** |
| `packages/app-shell/src/not-found.tsx` | **New** |
| `packages/app-shell/src/providers.tsx` | **New** |
| `packages/app-shell/src/session-context.tsx` | **New** |
| `packages/app-shell/src/session-state.ts` | **New** |
| `packages/app-shell/src/index.ts` | **New** exports |
| `packages/app-shell/README.md` | **New** |
| `tests/app-shell.test.tsx` | **New** |
| `package.json` | `@hivorr/app-shell` workspace dependency |
| `pnpm-lock.yaml` | TanStack Query and the workspace link |
| `documents/Task-Implementation/EP-01/**` | Task record, tracker, overview, execution record |

No migration, secret or protected file changed.

## 9. Definition of Done

| # | Condition |
|---|---|
| DoD-01 | Every approved route family is covered by the manifest. |
| DoD-02 | Only the five slice paths are registered. |
| DoD-03 | Unknown paths and out-of-slice approved paths render `NotFound`. |
| DoD-04 | A missing screen renders the 404, never a blank page. |
| DoD-05 | The session query calls `client.session()` and nothing else. |
| DoD-06 | `loading`, `authenticated`, `anonymous` and `error` are mapped correctly. |
| DoD-07 | A 401 maps to `anonymous`, not `error`. |
| DoD-08 | `presentedCapabilities` is frozen and `canPresent` is presentation-only. |
| DoD-09 | The 404 is labelled and has a visible focus target. |
| DoD-10 | `pnpm typecheck`, `lint`, `lint:boundaries`, `format:check`, `test:gates`, `config:check` pass. |
| DoD-11 | The approved visual baseline is unchanged. |
| DoD-12 | `src/app/App.tsx` and `src/styles/theme.css` are unchanged. |

## 10. Acceptance criteria

- `pnpm test -- tests/app-shell.test.tsx` passes fifteen checks.
- `/login` renders the supplied screen; `/wallet` and `/not-a-route` render “Page not found”.
- `/login` with no screen supplied renders the 404.
- `sessionStateFrom` returns `anonymous` for a 401 and `error` for a 500.
- The server-rendered provider probe prints `authenticated:true:person@example.test`.
- `pnpm build` + `pnpm visual:check --threshold 0` reports no visual change.

## 11. Testing and validation

| Test | Method |
|---|---|
| T-01 | `pnpm test -- tests/app-shell.test.tsx` |
| T-02 | `pnpm test:gates` |
| T-03 | `pnpm typecheck`, `lint`, `lint:boundaries`, `format:check`, `config:check` |
| T-04 | `pnpm build` + visual capture + zero-tolerance diff |
| T-05 | CI full suite |
| T-06 | Prototype and theme diff against `v0.0.1-bootstrap` |

## 12. Risks and considerations

| Risk | Handling |
|---|---|
| A capability could be treated as authority. | The API re-checks; the context names the field `presentedCapabilities` and documents it; no persistence. |
| The session could be cached across users. | TanStack Query is in-memory per page; the query is not persisted; a reload re-reads. |
| Registering a route early creates an unreachable screen. | Only the five slice paths are registered; everything else is 404. |
| A missing screen could render blank. | Route registration requires the screen; otherwise it falls to 404. |
| Password reset has no approved URL. | `F-46`; the shell does not invent one. |
| TanStack Query is new. | Pinned `5.105.3`, inside the release-age policy; only used for server state. |
| The shell is not mounted yet. | `053` mounts it with screens; `054` builds the bundles. |

## 13. Execution status

| Field | Value |
|---|---|
| **Status** | `REQUIRES_REVIEW` |
| **Started** | 2026-11-10 |
| **Code complete** | 2026-11-10 |
| **Closes when** | CI runs the suite and `053` mounts the shell without changing the approved baseline |
| **Execution record** | `execution-records/EP-01-052.md` |
