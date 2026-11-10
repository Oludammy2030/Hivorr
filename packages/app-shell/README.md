# Hivorr app shell

Shared client runtime for the four Hivorr applications (EP-01-052).

## What it owns

| Area | Module |
| --- | --- |
| Slice route table and path matching | `route-manifest.ts` |
| Reachable routes and the 404 | `routes.tsx`, `not-found.tsx` |
| Server-state client | `providers.tsx` (TanStack Query) |
| Session and capability presentation | `session-context.tsx`, `session-state.ts` |

## Route rule

`@hivorr/shared` declares every approved URL family. This package registers **only** the EP-01 slice
(`/`, `/login`, `/signup`, `/onboarding`, `/activities`). A slice route without a supplied screen is
not registered; every unknown path, and every approved path outside the slice, renders the real
`NotFound` page. Adding a route to the slice is a deliberate edit to `SLICE_ROUTE_IDS`.

## Session rule

- The only source is `GET /v1/session`, read through TanStack Query.
- The context exposes `status`, `session`, `presentedCapabilities` and `canPresent`.
- `canPresent` is **presentation only**: it hides or labels a control. The API re-checks every
  capability inside the transaction. Nothing is persisted; a reload re-reads the session.
- A `401` maps to `anonymous`; any other failure maps to `error`, not to an empty authenticated state.

## What it does not own

- Screens. The application supplies them to `SliceRoutes`; this package never imports a screen.
- The prototype entry (`src/main.tsx`). The prototype stays a static visual reference.
- Portal-specific navigation. `054` builds the four bundles and their per-portal shells.

## Evidence

```sh
pnpm test -- tests/app-shell.test.tsx
```

Covers approved-route coverage, slice-only registration, the 404 for unknown and out-of-slice paths,
the fail-closed missing-screen case, the `GET /v1/session` query, and the four session states.
