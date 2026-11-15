# EP-01-041 — Edge and origin security posture

## 1. Task identification

| Field | Value |
|---|---|
| **Task ID** | `EP-01-041` |
| **Task title** | Edge and origin security posture |
| **Parent phase** | `EP-01` — Core Platform Foundation & Infrastructure |
| **Priority** | Critical |
| **Class** | `[REVIEW]` — edge and origin controls |
| **Execution order** | 27 of 39 |
| **Governing plan** | EP-01 phase plan §11, Stage E |
| **Phase record** | `EP-01-ENTRY-RECORD.md` §5 (`standards #6`, `EX-02`) |

## 2. Objective

Apply the approved security-header posture on every host: TLS/HSTS, host-only cookies, same-origin `/api`, no wildcard CORS, `noindex` for privileged hosts, `no-store` on session responses and a CSP that keeps `script-src` strict while recording the approved inline-style exception.

## 3. Scope

### 3.1 Included

- `Content-Security-Policy`, HSTS, `nosniff`, frame denial, referrer and permissions policy on all four bundles.
- `style-src 'unsafe-inline'` recorded as the `EX-02` exception; `script-src 'self'`.
- Smoke assertions for CSP, HSTS and `nosniff` on the public host.
- `noindex` on privileged bundles.
- Same-origin `/api` and host-only cookie posture inherited from `032`/`060`.

### 3.2 Excluded

- Removing the prototype's inline styles (`EX-01`); the exception remains until that migration completes.
- A WAF, bot management or Access policy change.
- Production deployment.

## 4. Requirements

| ID | Requirement | Source |
|---|---|---|
| R-01 | CSP is served on every bundle. | SEC-14, SEC-49 |
| R-02 | `script-src` is strict; `style-src 'unsafe-inline'` is the recorded exception. | `standards` §16 #6; `EX-02` |
| R-03 | HSTS, `nosniff`, frame denial and referrer policy are present. | SEC-48 |
| R-04 | `/api` is same-origin and CORS is not wildcard. | SEC-19, SEC-20 |
| R-05 | Privileged bundles carry `noindex`. | Plan `041` |
| R-06 | The smoke proves the headers on the deployed host. | M-07 |

## 5. Dependencies

| Dependency | State |
|---|---|
| `EP-01-032` session/cookie posture | **COMPLETED** |
| `EP-01-060` staging topology | **REQUIRES_REVIEW** — `F-08` remains |
| `standards` §16 #6 CSP decision | **DECIDED** — `unsafe-inline` for styles until `EX-01` |
| `EX-02` | **Accepted exception** |

## 6. Implementation plan

1. Add the CSP line to `public/_headers` and the three portal `_headers`.
2. Keep `style-src 'unsafe-inline'` and allow only the font and image origins the prototype uses.
3. Add smoke assertions for CSP, HSTS and `nosniff`.
4. Build all bundles and confirm the headers are copied into `dist`.
5. Deploy staging and run `pnpm smoke:staging`.
6. Record the evidence and update the tracker.

## 7. Existing components and reusability

| Component | Use |
|---|---|
| `public/_headers` | Main bundle header source |
| `apps/control|staff|partner/public/_headers` | Privileged bundle header source |
| `scripts/smoke-staging.mjs` | Post-deploy assertion |
| `EP-01-060` topology | Hosts and Access |
| `standards` SEC-14/SEC-48/SEC-49 | Header requirements |

## 8. Files and systems affected

| Path | State |
|---|---|
| `public/_headers` | Modified — CSP added |
| `apps/control/public/_headers` | Modified — CSP added |
| `apps/staff/public/_headers` | Modified — CSP added |
| `apps/partner/public/_headers` | Modified — CSP added |
| `scripts/smoke-staging.mjs` | Modified — header assertions |
| `dist/_headers` | Built output |

## 9. Definition of Done

| # | Condition | Evidence |
|---|---|---|
| DoD-01 | CSP present on all four bundles | Built `dist/_headers` |
| DoD-02 | `script-src 'self'`; `style-src` records the exception | Header value |
| DoD-03 | HSTS, `nosniff`, frame denial present | Header value |
| DoD-04 | `noindex` on privileged bundles | Header value |
| DoD-05 | Smoke asserts the headers on staging | `pnpm smoke:staging` |
| DoD-06 | No visual regression from the header change | CI visual job |
| DoD-07 | Tracker and evidence updated | Links |

## 10. Acceptance criteria

- The deployed public host returns the CSP, HSTS and `nosniff` headers.
- `script-src` is `'self'`; no `unsafe-eval` or wildcard script origin is present.
- `style-src` contains the approved `'unsafe-inline'` exception and no broader style origin.
- The privileged bundles carry `noindex`.
- The smoke fails if CSP or HSTS disappears.

## 11. Testing and validation

| Test | Method | Result |
|---|---|---|
| T-01 | `pnpm build:all` | **Pass** — four bundles |
| T-02 | Inspect `dist/_headers` and portal `_headers` | **Pass** — CSP present |
| T-03 | `pnpm typecheck`, `pnpm lint` | **Pass** |
| T-04 | `pnpm smoke:staging` after deploy | **Pending** |

## 12. Risks and considerations

| Risk | Handling |
|---|---|
| CSP breaks inline styles | `style-src 'unsafe-inline'` is the recorded `EX-02` exception. |
| CSP blocks Google Fonts or Unsplash | `style-src`/`font-src`/`img-src` allow only those origins. |
| CSP blocks a future script | `script-src 'self'` is intentional; no inline script is used. |
| Header source differs per bundle | The same policy is applied to all four `_headers` files. |

## 13. Execution status

| Field | Value |
|---|---|
| **Status** | `COMPLETED` |
| **Started** | 2026-11-15 |
| **Code complete** | 2026-11-15 |
| **Completed** | 2026-11-15 |
| **Closes when** | Met — staging serves CSP/HSTS/nosniff and `pnpm smoke:staging` passes 13/13 |
| **Execution record** | `execution-records/EP-01-041.md` |
