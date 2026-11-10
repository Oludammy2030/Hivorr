# EP-01 — Phase Execution Tracker
## Core Platform Foundation & Infrastructure

| Field | Value |
|---|---|
| **Phase** | `EP-01` |
| **Governing plan** | `documents/Engineering-Execution/Engineering-Phase-Plan/EP-01 — Core Platform Foundation & Infrastructure.md` |
| **Phase record** | `documents/Engineering-Execution/Engineering-Phase-Records/EP-01/EP-01-ENTRY-RECORD.md` |
| **Tracker updated** | 2026-11-10 |
| **Phase status** | `In build` |
| **Tasks total** | 39 |
| **Completed** | 5 |
| **Requires review** | 32 |
| **Pending** | 2 |
| **Blocked** | 0 |

> **Status rule.** A task moves to `COMPLETED` only when its task-specific DoD in `tasks/` has been
> satisfied and validated, and an execution record exists in `execution-records/`. Existing code is
> never sufficient on its own. A criterion without an artifact is unmet.

---

## 1. Tracker

| # | Task | Title | Dependencies | Status | Completed | Record |
|---:|---|---|---|---|---|---|
| 1 | `EP-01-001` | Entry gate closure and decision register | EP-00 exit | **COMPLETED** | 2026-11-07 | `Engineering-Phase-Records/EP-01/EP-01-ENTRY-RECORD.md` |
| 2 | `EP-01-002` | Workspace topology and package boundaries | `001` | **COMPLETED** | 2026-11-09 | `execution-records/EP-01-002.md` |
| 3 | `EP-01-003` | Shared contracts package | `002` | **COMPLETED** | 2026-11-09 | `execution-records/EP-01-003.md` |
| 4 | `EP-01-004` | CI pipeline extension | `002`, `003` | **REQUIRES_REVIEW** | — | `execution-records/EP-01-004.md` |
| 5 | `EP-01-010` | API bootstrap and runtime configuration | `002`, `004` | **REQUIRES_REVIEW** | — | `execution-records/EP-01-010.md` |
| 6 | `EP-01-011` | Common request pipeline and error contract | `010` | **REQUIRES_REVIEW** | — | `execution-records/EP-01-011.md` |
| 7 | `EP-01-012` | Ten-module boundary skeleton | `010`, `011` | **COMPLETED** | 2026-11-09 | `execution-records/EP-01-012.md` |
| 8 | `EP-01-013` | OpenAPI 3.1 contract and generated client | `010`–`012` | **REQUIRES_REVIEW** | — | `execution-records/EP-01-013.md` |
| 9 | `EP-01-014` | Worker, PostgreSQL queue and outbox | `012`, `024` | **REQUIRES_REVIEW** | — | `execution-records/EP-01-014.md` |
| 10 | `EP-01-020` | Managed PostgreSQL and environment configuration | `001` | **REQUIRES_REVIEW** | — | `execution-records/EP-01-020.md` |
| 11 | `EP-01-021` | Migration runner and baseline schemas | `020` | **REQUIRES_REVIEW** | — | `execution-records/EP-01-021.md` |
| 12 | `EP-01-022` | Database roles, grants and default privileges | `021` | **REQUIRES_REVIEW** | — | `execution-records/EP-01-022.md` |
| 13 | `EP-01-023` | Identity schema | `021`, `022` | **REQUIRES_REVIEW** | — | `execution-records/EP-01-023.md` |
| 14 | `EP-01-024` | Profile, activity and platform schema | `021`, `022` | **REQUIRES_REVIEW** | — | `execution-records/EP-01-024.md` |
| 15 | `EP-01-025` | RLS pattern, identity context and policy tests | `022`-`024` | **REQUIRES_REVIEW** | — | `execution-records/EP-01-025.md` |
| 16 | `EP-01-026` | Repository and transaction foundation | `021`-`025` | **REQUIRES_REVIEW** | — | `execution-records/EP-01-026.md` |
| 17 | `EP-01-030` | Identity domain and repositories | `023`, `026` | **REQUIRES_REVIEW** | — | `execution-records/EP-01-030.md` |
| 18 | `EP-01-031` | Registration, credentials and account recovery | `030` | **REQUIRES_REVIEW** | — | `execution-records/EP-01-031.md` |
| 19 | `EP-01-032` | Session lifecycle, audiences and session endpoint | `031` | **REQUIRES_REVIEW** | — | `execution-records/EP-01-032.md` |
| 20 | `EP-01-033` | Activity registry and activation state machine | `024`, `030` | **REQUIRES_REVIEW** | — | `execution-records/EP-01-033.md` |
| 21 | `EP-01-034` | Capability computation engine | `033` | **COMPLETED** | 2026-11-09 | `execution-records/EP-01-034.md` |
| 22 | `EP-01-036` | Audit logging service and immutability | `024`, `026` | **REQUIRES_REVIEW** | — | `execution-records/EP-01-036.md` |
| 23 | `EP-01-035` | Service-layer enforcement and vertical-slice endpoints | `032`, `034`, `036` | **REQUIRES_REVIEW** | — | `execution-records/EP-01-035.md` |
| 24 | `EP-01-040` | Structured logging, correlation and error-tracking seam | `010`, `011` | **REQUIRES_REVIEW** | — | `execution-records/EP-01-040.md` |
| 25 | `EP-01-042` | Authentication abuse controls | `032` | **REQUIRES_REVIEW** | — | `execution-records/EP-01-042.md` |
| 26 | `EP-01-043` | Secret management and configuration contract | `020` | **REQUIRES_REVIEW** | — | `execution-records/EP-01-043.md` |
| 27 | `EP-01-041` | Edge and origin security posture | `032`, `060` | **REQUIRES_REVIEW** | — | — |
| 28 | `EP-01-050` | Visual regression baseline and harness | `004` | **REQUIRES_REVIEW** — baseline approved 2026-11-10; first CI run remains | — | `execution-records/EP-01-050.md` |
| 29 | `EP-01-051` | Design tokens and primitive extraction for the slice | `050`, `002` | **REQUIRES_REVIEW** — tokens + 3 primitives; 9 exact parity checks; baseline unchanged; CI parity run remains | — | `execution-records/EP-01-051.md` |
| 30 | `EP-01-052` | Route manifest, router and providers | `003`, `013`, `050`, `051` | **REQUIRES_REVIEW** — slice routes + real 404 + TanStack Query/session context; 15 checks pass; CI and the `053` mount remain (`F-46`) | — | `execution-records/EP-01-052.md` |
| 31 | `EP-01-053` | Vertical-slice screens | `032`, `034`, `035`, `051`, `052` | **REQUIRES_REVIEW** — slice live; sign-in exact at 3 widths; MFA/reset/verify/activity wired; live E2E in `063` | — | `execution-records/EP-01-053.md` |
| 32 | `EP-01-054` | Four-bundle build and deployment targets | `002`, `052` | **REQUIRES_REVIEW** — four bundles + noindex + 200 KB gzip budget gate; release manifest verified; CI remains | — | `execution-records/EP-01-054.md` |
| 33 | `EP-01-060` | Environment topology and staging provisioning | `001`, `020`, `043` | **REQUIRES_REVIEW** — four hosts, TLS and Access observed; staging `verified`; `F-49` stale API image and `F-08` remain | — | `execution-records/EP-01-060.md` |
| 34 | `EP-01-061` | Build-once artifact and promotion | `004`, `054`, `060` | **REQUIRES_REVIEW** — release identity in health; digest artifact + promotion checks; deployed SHA unobserved (`F-49`/`F-50`/`F-51`) | — | `execution-records/EP-01-061.md` |
| 35 | `EP-01-062` | Migration application pipeline | `021`, `022`, `060`, `061` | **REQUIRES_REVIEW** — plan/apply/verify + 8 unit checks; no DB/workflow run; `F-29` credential and `F-28` baseline remain | — | `execution-records/EP-01-062.md` |
| 36 | `EP-01-063` | Staging smoke, E2E and gate wiring | `061`, `062`, `053` | **REQUIRES_REVIEW** — smoke + E2E wired as blocking promotion gates; both correctly fail on `F-49`/`F-50` | — | `execution-records/EP-01-063.md` |
| 37 | `EP-01-070` | Phase evidence pack and traceability index | all prior | **REQUIRES_REVIEW** — pack complete; C1 met, 11 partial, 2 unmet, 2 open | — | `execution-records/EP-01-070.md` |
| 38 | `EP-01-071` | Phase-level security and quality review | `070` | **REQUIRES_REVIEW** — review complete; 0 critical, **2 high** (`F-49`, `F-50`); CI green | — | `execution-records/EP-01-071.md` |
| 39 | `EP-01-072` | G5 phase closure record | `070`, `071` | **PENDING** | — | — |

---

## 2. Next eligible task

**None.** `EP-01-072` cannot be signed while two high findings remain:

1. `F-49` — staging API stale.
2. `F-50` — slice/Pages rollout.

CI run `42835621656` is green on every job, closing H-04. H-01 (`F-29`) is an accepted residual; H-05
(`F-04`) is resolved by the no-Doppler ruling. `DEV-003` (single reviewer) ends at `G5` or on
appointment of a second reviewer.

---

## 3. Review queue — `REQUIRES_REVIEW`

These work packages have working code but no verified DoD. They must be reviewed and evidenced before
they can count toward the phase exit.

| Task | What exists | What is unverified or missing |
|---|---|---|
| `010` | NestJS/Fastify bootstrap, `/v1`, config validation, health, correlation, error filter | No task DoD; request timeout/body limit values not evidenced; no structured log |
| `014` | Lease-based outbox worker, retry/backoff, dead-letter, health | Recorded selection was `graphile-worker` — deviation needs ratification (`F-03`); no registered handlers |
| `020` | Supabase staging project, per-environment databases, connection validation | Local container parity not evidenced; `DATABASE_SSL_CA` unset (`F-08`) |
| `021` | 11 versioned migrations, custom runner, 10 module schemas + `private` | Recorded runner was Supabase CLI — deviation (`F-03`); `db diff` not implemented |
| `022` | Five roles, grants, default privileges | No per-role deny test proving the API cannot DDL/truncate/bypass RLS |
| `023` | Identity tables, constraints, indexes, comments | No verified RLS policy matrix |
| `025` | RLS on identity tables, `FORCE ROW LEVEL SECURITY`, `hivorr.account_id`/`user_id` context | Per-policy allow **and** deny tests not demonstrated; profile/activity tables absent |
| `026` | Pool, `DatabaseService`, parameterised queries | Transaction-local context setter not evidenced as universally applied |
| `030` | Identity service with domain rules | No separate domain/repository layer; invariants live in the service |
| `032` | Sign-in, host-only cookies, refresh rotation, reuse detection, revocation, `GET /v1/session`, MFA | Session-lifetime decision implemented; DoD not evidenced |
| `034` | Pure default-deny capability function and tests | Capability constants not in `@hivorr/shared` (`F-11`); stable deny reasons not implemented |
| `041` | HSTS, `nosniff`, frame deny, referrer policy, permissions policy, `noindex`, `/api` proxy | CSP absent; edge rules not tested on every host |
| `054` | Four bundles build and deploy targets exist | DoD, import-boundary and budget evidence not produced |
| `060` | Eight hosts live, TLS, Access, same-origin `/api` | Readiness 503, TLS CA, automated Pages deploy (`F-08`) |
| `061` | Release manifest, digest verification, approval policy | Not exercised end to end on staging |
| `062` | Migration runner applied twice in CI; staging apply workflow exists | `db diff` clean check absent; failure-abort not proven on staging |

---

## 4. Status history

| Date | Task | From | To | Record |
|---|---|---|---|---|
| 2026-11-07 | `EP-01-001` | `PENDING` | `COMPLETED` | `EP-01-ENTRY-RECORD.md` |
| 2026-11-09 | `EP-01-002` | `PENDING` | `COMPLETED` | `execution-records/EP-01-002.md` |

---

**Tracker status:** current to 2026-11-09. Every later status change requires a task doc, an
execution record, and this table.
