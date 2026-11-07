# EP-01 — Entry decision pack

> **STATUS: APPLIED — 2026-11-07.** The founder approved the entry gate on 2026-11-07 and the
> outcomes are recorded in `standards` §13.3 (`DEV-003`), `standards` §16, `ARCHITECTURE.md` §16.4
> and `EP-01-ENTRY-RECORD.md` v0.6. This file is evidence of **what was put to the founder**, not a
> source of decisions — the owning registers and the entry record govern.

**Purpose.** EP-01 is `Blocked` on nine items (`EP-01-ENTRY-RECORD.md` §9.3). This pack turns eight
of them into a single sitting of ticks and one signature; the ninth is the phase-opening signature
itself. Nothing here is applied to any document.

**How to use it.**

1. Read Part A. If the wording is acceptable, say so; it is then inserted into `standards` §13.3 and
   §17, and the entry record's §5, §5.1, §9.3 and `R-P3` are updated to match.
2. Read Part B. For each row, tick one option or write your own. A row with no tick stays `PENDING`.
3. Sign §11 of the entry record after Part A is merged and Part B is folded in as version `0.4`.

**What this pack cannot do.** It cannot choose a provider, a hostname, an identifier, a lifetime, a
vendor or a tool. Where options are listed, they are options; the ranking of them is not a decision.
Vendor specifics (tiers, limits, features) are indicative and must be checked against current
pricing and documentation before a row is signed — they are not verified claims.

---

## Part A — `DEV-003` draft (for `standards` §13.3)

Inserted after the `DEV-002` table and before `GOV-18`. Format follows `GOV-13` and Appendix C.

| Field | Value |
| --- | --- |
| **ID** | `DEV-003` |
| **Rule** | `QUA-29` — "No change reaches `main` without review by someone other than its author. Self-merge is prohibited on `main`." and `QUA-31` — "A pull request that changes authentication, authorisation, money, migrations, crypto, uploads, webhooks or CI configuration requires two reviewers, one of whom is the architect or a named security reviewer (AUT-39)." |
| **Scope** | EP-01 pull requests that change authentication, authorisation, session handling, identity or capability computation, a schema migration, or CI configuration — items `023`, `025`, `030`–`036` and `071`, and the CI configuration those items introduce. It does not waive any rule, gate, branch or repository control outside that scope. It does **not** apply to `G4`. |
| **Reason** | The project is a one-person team plus AI agents. The founder is the only person who holds the architect role and the only person who holds the founder role (`EES` §5.1), and the founder stated on 2026-11-07 that no second reviewer exists. `QUA-31` requires two reviewers, one of whom is the architect or a named security reviewer; one person cannot occupy both seats, and no appointment is possible while no second person exists. `QUA-29`'s self-merge limb separately blocks the founder merging a document change the founder authored. `DEV-001` does not cover this scope — it is limited to EP-00 CI configuration (`EP-00-006`–`EP-00-008`) — so EP-01 has no deviation in force for these items. |
| **Risk** | A defect in an authentication, capability or migration change could merge with one human review, and on some changes the author and the approver are the same person. The exposure is to repository history and to pre-release environments only: no staging or production environment exists for EP-01 (§9.4 of the entry record), and no customer, personal or financial data is processed in this phase. A migration defect is the highest-consequence case, because a wrong grant or policy is silent until a deny path is exercised. |
| **Compensating control** | The founder reads every diff, not the description (`QUA-30`), against the `QUA-33` checklist; the agent produces an independent review pass on each PR and records it there; every gate has a seeded-failure proof (a change that must fail CI and does); CI enforces type check, lint, format, unit tests, secret scan, dependency scan, migration lint and `db diff`; the `.githooks/pre-push` hook and the CI `Protected branch guard` reject direct pushes to `main` and `staging`; no change is self-approved — where the founder is the author, an agent records the review and the founder still cannot merge without the CI gate passing; migration items additionally pass the `Database-Migration-and-Supabase-Data-API-Rules.md` §9–§10 checklist and are applied to staging before production; `DEV-002` remains the only statement about host protection, and these controls are compensating controls, **not** protection. |
| **Owner** | Prince Abidemi Oluwadamilare (Founder) |
| **Expiry** | Ends when a second reviewer is appointed, or when the EP-01 `G5` closure record is signed, whichever is earlier. It does **not** extend to `G4` (production release), which has no deviation path (`EES` §7.3). *Optional backstop: add a hard date here if you want a second trigger; none is proposed, because that date would be invented.* |
| **Approval** | `PENDING` — founder approval and date to be supplied. |

**Changelog line for `standards` §17** (insert at the top, dated on approval):

> ### [date] — deviation `DEV-003` recorded
>
> Recorded `DEV-003` in §13.3: a time-boxed deviation from `QUA-29` and `QUA-31` for EP-01 pull
> requests that change authentication, authorisation, session handling, identity, capability
> computation, schema migrations or CI configuration. The reason is that no second reviewer exists
> and one person cannot occupy both the architect and security-reviewer seats. The deviation ends
> when a second reviewer is appointed or when the EP-01 `G5` closure record is signed, whichever is
> earlier, and does not extend to `G4`. No rule changed meaning and no `[OPEN]` item was settled.

**Entry-record edits this implies** (made only after approval):

| File | Section | Change |
| --- | --- | --- |
| `EP-01-ENTRY-RECORD.md` | §5 | Second-reviewer row → `RECORDED`; evidence `standards` §13.3 `DEV-003`; follow-up "ends at reviewer appointment or EP-01 `G5`" |
| `EP-01-ENTRY-RECORD.md` | §5.1 | The 2026-11-07 statement now sits beside an approved deviation, not instead of one |
| `EP-01-ENTRY-RECORD.md` | §9.3 row 4 | Cleared; note the expiry condition |
| `EP-01-ENTRY-RECORD.md` | §10.1 `R-P3` | Handling changes from "appoint or record a deviation" to "`DEV-003` in force; re-review at `023`" |
| `EP-01-ENTRY-RECORD.md` | §11.1 | E16 added: `DEV-003` recorded |
| `EP-01-ENTRY-RECORD.md` | §12 | Version `0.4` row |

**Three things `DEV-003` does not do**, and must not be read as doing:

1. It does not make `main` or `staging` protected. That is `DEV-002`, and only until EP-01 `G5`.
2. It does not renew `DEV-001`. `DEV-001` keeps its own scope and expiry; `GOV-18` forbids extending
   it by implication.
3. It does not clear the other eight items in §9.3. The phase still cannot open on this alone.

---

## Part B — Decision sheet

Eight rows, in the order the entry record sets. Each row is independent: one decision unblocks its
own items and nothing else. "Blocks" is copied from the entry record, not re-derived.

### B1. `ARCHITECTURE.md` §16.4 `#1` — managed Postgres provider

**Class** `[FOUNDER]` · **Owner** Founder + architect · **Blocks** `020`–`026`, `060`, `062`
**No deviation path** (`EES` §7.3).

| Option | What it gives EP-01 | What it costs or constrains |
| --- | --- | --- |
| **Supabase** (managed Postgres only, Position A) | Postgres 16, pooled connections, PITR, and an optional declarative-schema workflow (`supabase/schemas/` + `pg-delta`); the database-rules §4–§8 applicability paths are already written for this choice | Ties migration tooling to the Supabase CLI (`database rules` §9.11); tempts use of Supabase Auth/Data API, which the identity design does not use; free tier has project-pause and backup limits |
| **Neon** | Serverless Postgres with per-branch databases, cheap staging, PITR, standard Postgres wire protocol | No RLS helper functions; migration tooling stays your choice; cold starts on the free tier; less regional choice |
| **RDS (AWS)** | Most mature operations, IAM auth, automated backups, predictable compliance story | Heaviest setup: VPC, security groups, parameter groups; a second instance for staging is a real monthly cost; slowest path from today to a running `020` |

**What each choice changes downstream:** the migration runner (`B7`), the connection-pooling story,
and the backup tier (`§16.4 #13`). Choosing Supabase also settles whether `EX-19` is unblocked via
the CLI or via `pnpm`.

**Decision:** ☐ Supabase ☐ Neon ☐ RDS ☐ Other: ______________ **Date:** __________

---

### B2. `ARCHITECTURE.md` §16.4 `#17` — hosting, DNS and TLS

**Class** `[FOUNDER]` · **Owner** Founder + architect · **Blocks** `041`, `054`, `060`, `063`
**No deviation path.**

Fixed by the architecture, whatever you choose: five hostnames (`hivorr.com`, `staging.`, `control.`,
`staff.`, `partners.`), no wildcard DNS, HSTS `max-age=31536000; includeSubDomains` without
`preload`, `noindex` on the four non-public hosts, one host per environment, and **`/api/*` served
same-origin from the edge** (§4.9). That last rule is the binding constraint: the edge must be able
to proxy to an API origin that the browser cannot resolve directly.

| Option | Edge / static | API + worker | Consequence |
| --- | --- | --- | --- |
| **Cloudflare** | Pages + DNS + TLS in one account | Workers, or Fly.io/Render behind a Worker route | Single vendor for DNS and edge; same-origin rewrite is a Worker; R2 storage is already decided (§9.12), so one bill; Workers runtime is not Node, so a Node API still needs a Node host |
| **Vercel + separate API host** | Vercel projects per bundle, Vercel DNS, managed TLS | Fly.io, Render or Railway | Fastest path for the five bundles; `rewrites` gives same-origin `/api/*`; two vendors and two bills; `control.`/`staff.` need extra care on `noindex` and auth headers |
| **Cloudflare DNS + mixed hosts** | Cloudflare DNS and TLS, static on whichever host | Any of the three | Maximum flexibility, most configuration to keep consistent; the topology rules become your responsibility per host |

**What to decide explicitly:** who issues TLS (provider-managed or ACM), and whether staging shares
the production edge account or gets its own. Sharing is cheaper and risks a staging misconfiguration
touching production DNS.

**Decision:** ☐ Cloudflare end-to-end ☐ Vercel + Fly/Render/Railway ☐ Cloudflare DNS + mixed ☐ Other: ______________
**DNS:** ______________ **TLS:** ______________ **Date:** __________

---

### B3. `ARCHITECTURE.md` §16.4 `#14` — sign-in identifier

**Class** `[FOUNDER]` · **Owner** Founder only · **Blocks** `031`, `032`, `053`
**No deviation path.**

`§9.7` already decides: email + password with Argon2id; phone OTP for Nigerian numbers via Termii;
email verification; no social login. The open question is **which identifier is primary and which is
mandatory at registration** — not whether phone or email exists.

| Option | Registration | Identity schema | Auth screens | Recovery |
| --- | --- | --- | --- | --- |
| **Email-first** | Email + password required; phone optional, added before a phone-dependent action | `email` unique, `phone` nullable unique | One path, one validation set | Email token |
| **Phone-first** | Phone + OTP required; email optional but verified before notifications | `phone` (E.164) unique, `email` nullable unique | One path, OTP-centric | OTP to the registered phone |
| **Either** | User picks; one of the two is required and verified | Both unique, at least one non-null (check constraint) | Branching screens, more states, more deny-path tests | Depends on which was verified |

**Consequence for EP-01:** `031` builds the schema and `032` the session flow; an "either" answer
roughly doubles the registration and recovery test matrix in `033` and `034`. Email-first is the
narrowest build; phone-first matches the Termii investment and the Nigerian market; "either" is the
most forgiving for users and the most expensive to verify.

**Decision:** ☐ Email-first ☐ Phone-first ☐ Either **Date:** __________

---

### B4. `standards` §16 `#1`, `#2`, `#3`, `#6`, `#8`, `#9`

**Class** mixed (`[REVIEW]`, `[FOUNDER]`, or both — per row) · **Blocks** `003`, `011`, `013`, `020`,
`032`, `040`, `041`, `043`, `060`

#### B4a. §16 `#1` — validation and client-data library `[REVIEW]`

| Option | Consequence |
| --- | --- |
| Confirm both `zod` and TanStack Query | Matches `ARCHITECTURE.md` §16.3 #11; one validator shared client/server; caching decided once |
| `zod` only, defer TanStack Query | Smaller surface now; `003` still unblocked; client fetching decided later |
| Neither now | `003` and `011` stay blocked |

**Decision:** ☐ Both ☐ `zod` only ☐ Defer **Date:** __________

#### B4b. §16 `#2` — API versioning `[REVIEW]`

| Option | Consequence |
| --- | --- |
| Additive-only within an unversioned v1 | Proposed default; no `/v1` in paths; a breaking change forces a new major path later |
| Path version `/v1` from the first contract | Breaking change is a new path; every route carries the prefix forever |
| Header-based versioning | Clean URLs; harder to debug, easy to forget in clients |

**Decision:** ☐ Additive-only ☐ Path `/v1` ☐ Header **Date:** __________

#### B4c. §16 `#3` — session lifetimes per audience `[FOUNDER]` + `[REVIEW]`

The numbers are the decision. The four audiences are set by §5.4 (public, control, staff, partners).
Illustrative sets only — **none is approved**:

| Set | Public | Privileged (`control.`/`staff.`) | Shape |
| --- | --- | --- | --- |
| **A — conservative** | 12 h absolute / 30 min idle | 8 h / 15 min idle | Short idle on privileged hosts; §5.4 recommends exactly this shape |
| **B — user-friendly** | 30 d absolute / 7 d idle | 12 h / 30 min idle | Fewer re-logins on `hivorr.com`; longer exposure window on a stolen device |
| **C — strict** | 8 h / 20 min idle | 4 h / 10 min idle | Highest friction; safest for a pre-launch product |

Also decide: does a privileged session require re-authentication (password or TOTP) to start, and
does an idle timeout apply across tabs?

**Decision:** ☐ Set A ☐ Set B ☐ Set C ☐ Own numbers: ______________ **Date:** __________

#### B4d. §16 `#6` — CSP posture given `EX-01`/`EX-02` `[REVIEW]` + `[FOUNDER]`

`EX-01` is the cause (1,065 lines of inline styles); `EX-02` is the consequence
(`style-src 'unsafe-inline'` is required). `standards` §16 `#6` cites `EX-01`, the entry record
cites `EX-02`; they are the same question, and the row should cite both after the ruling.

| Option | Consequence |
| --- | --- |
| Accept `style-src 'unsafe-inline'` until the inline styles are migrated | Unblocks `041`; a real weakening of XSS defence, mitigated by script-src and the absence of user HTML |
| Serve a nonce/hash-based `style-src` from day one | Strongest posture; needs every inline style to carry a nonce, which the prototype's 1,065 inline-style lines make impractical now |
| Block on migrating inline styles first | Correct end state, but delays `041` and effectively becomes a refactor project |

If the first option is chosen, it is recorded as an `EX-` row and `EX-02` is updated, not deleted.

**Decision:** ☐ Accept `unsafe-inline` ☐ Nonce now ☐ Block on migration **Date:** __________

#### B4e. §16 `#8` — secret manager `[FOUNDER]` + `[REVIEW]`

| Option | Consequence |
| --- | --- |
| Host/CI secrets only (GitHub Actions secrets + environment variables) | Zero new vendor; rotation is manual and undocumented; acceptable at EP-01 scale, weak by `060` |
| Managed store (Doppler, Infisical, AWS Secrets Manager, Cloudflare Secrets) | Per-environment scoping and rotation; one more vendor and one more credential to bootstrap |
| Self-hosted Vault | Strongest control, most operations; disproportionate for one person |

Also decide the rotation mechanism and who holds break-glass access.

**Decision:** ☐ Host/CI only ☐ Managed: ______________ ☐ Vault **Rotation:** ______________ **Date:** __________

#### B4f. §16 `#9` — error tracking and APM `[FOUNDER]`

| Option | Consequence |
| --- | --- |
| Sentry SaaS | Fastest; personal data leaves the region unless scrubbing is configured first; free tier is sufficient at EP-01 |
| Self-hosted (GlitchTip/Sentry) | Data stays in-region; you now operate another service |
| No vendor at EP-01; structured `pino` logs only | `040` ships with the no-op adapter (already allowed by the entry record); no visibility into staging errors |

Whatever is chosen, decide whether the vendor may receive personal data and record the scrubbing
rule before first use.

**Decision:** ☐ Sentry SaaS ☐ Self-hosted ☐ No vendor at EP-01 **May receive PII:** ☐ Yes ☐ No **Date:** __________

---

### B5. `EX-10` residual — Playwright, Testcontainers, Testing Library

**Class** `[REVIEW]` via `GOV-09` · **Owner** Architect · **Blocks** `004`, `025`, `050`, `063`

`EX-10` is already partially closed: Vitest runs (`EP-00-003`). Three tools remain.

| Option | What it enables | Consequence |
| --- | --- | --- |
| **Full residual** — Playwright + Testcontainers + Testing Library | E2E, disposable real Postgres per test run, component DOM tests | Largest install and CI time; Testcontainers needs Docker in CI, which is a new CI dependency |
| **Playwright + Testing Library, Postgres via a CI service container** | E2E and component tests; real Postgres without Testcontainers | Simpler CI; local runs need a manual database or compose file |
| **Testing Library now; Playwright + Testcontainers deferred** | `004` and `050` partly unblocked | `025` (policy tests) and `063` (E2E) stay blocked, so the phase cannot finish |

`025` needs a real Postgres, and RLS policy tests that do not hit a real database prove nothing —
so the second or first option is the one that actually clears the phase.

**Decision:** ☐ Full residual ☐ Playwright + Testing Library + service container ☐ Testing Library only **Date:** __________

---

### B6. §4.3 rulings R1 and R2

**Class** `[REVIEW]` · **Owner** Architect · **Blocks** `002`, `054` (R1) and `050`–`053` (R2)

#### B6a. R1 — bundle count

The plan says "five frontend bundles"; `ARCHITECTURE.md` §8.12 enumerates **four** bundles (`web`,
`control`, `staff`, `partners`) and treats `staging` as a deployment target.

- ☐ **Confirm "four bundles, five deployments"** — the plan's reading stands; `ARCHITECTURE.md` is
  unchanged; `002` and `054` start.
- ☐ **Rule "five bundles"** — `ARCHITECTURE.md` §8.12 must be amended first, which is a separate
  recorded act outside EP-01.

**Ruling text (verbatim, to be copied into the entry record §6.1):**

> ______________________________________________________________________________

#### B6b. R2 — extraction scope

The plan says "screens extracted from `App.tsx` without visual change", and proposes extracting only
the screens and primitives the vertical slice uses, rather than all 82.

- ☐ **Confirm slice-only extraction** — later phases extract on touch; `050`–`053` start with a
  bounded scope.
- ☐ **Require full extraction in EP-01** — this is a rewrite, contradicts bounded scope (`AGENTS.md`
  §3), and should be rejected explicitly if raised.

**Ruling text (verbatim):**

> ______________________________________________________________________________

**Date:** __________

---

### B7. Technical selections

**Class** `[REVIEW]` · **Owner** Architect · **Blocks** `002`, `014`, `021`
Named in `002`'s G0 record. Each choice is reversible, but not cheaply once migrations exist.

| Selection | Options | Trade-off |
| --- | --- | --- |
| **DB driver** | `pg` · `postgres` (postgres.js) | `pg` is the mature default with the widest tooling support and the deepest ecosystem; `postgres` is faster and smaller with tagged-template ergonomics, but fewer libraries assume it. `ARCHITECTURE.md` §15.4 defers the choice here |
| **Migration runner** | `node-pg-migrate` · Atlas · `dbmate` · Supabase CLI | Must deliver forward-only, versioned, CI-applied SQL (§9.5) and destructive-change gates. `node-pg-migrate` is JS-native and simple; Atlas adds declarative diff and linting, which fits the destructive-change gate best; `dbmate` is plain SQL with the least magic; the Supabase CLI only exists as an option if B1 chooses Supabase, and choosing it hard-couples B1 and B7 |
| **Queue** | `graphile-worker` · `pg-boss` | Both are Postgres-backed (§15.4). `graphile-worker` has better throughput, cron and observability; `pg-boss` has a simpler API and job-state model. Neither adds infrastructure |
| **OpenAPI generator** | `@nestjs/swagger` · hand-written spec + `zod`-to-OpenAPI | `@nestjs/swagger` is the architecture's recommendation and needs a `zod` bridge (`nestjs-zod`) because NestJS decorators and `zod` schemas are two sources of truth; the `zod`-first route keeps one source but loses decorator-driven generation |
| **Boundary lint** | `dependency-cruiser` · `eslint-plugin-boundaries` · custom script | `QUA-12` forbids cycles and the repo already runs a custom `scripts/lint.mjs`. `dependency-cruiser` expresses module-boundary and layer rules most directly and emits a graph; the ESLint plugin fits only if ESLint becomes the single linter |

**Decision:**

DB driver: ☐ `pg` ☐ `postgres`  · Migration runner: ☐ `node-pg-migrate` ☐ Atlas ☐ `dbmate` ☐ Supabase CLI
Queue: ☐ `graphile-worker` ☐ `pg-boss` · OpenAPI: ☐ `@nestjs/swagger` ☐ `zod`-first
Boundary lint: ☐ `dependency-cruiser` ☐ `eslint-plugin-boundaries` ☐ custom
**Date:** __________

---

### B8. Phase opening

**Class** `[FOUNDER]` · **Owner** Founder · **Blocks** every item

This is the signature in `EP-01-ENTRY-RECORD.md` §11, taken only after Part A is merged and B1–B7
are folded in as version `0.4`. It is not a separate document.

- ☐ I confirm the record's contents are accurate as of the signature date.
- ☐ I open EP-01 for build, with `DEV-003` in force and the residual risks in §10.1 accepted.

**Signature:** ______________________ **Date:** __________

---

## What happens after the ticks

| Step | Owner | Output |
| --- | --- | --- |
| Insert Part A into `standards` §13.3 and §17 | Agent, on your approval | `DEV-003` exists |
| Apply the entry-record edits listed in Part A | Agent | §5, §5.1, §9.3, `R-P3`, E16, §12 updated |
| Fold B1–B7 outcomes into §5, §5.1, §6, §9.3 and the owning registers | Agent | Decisions recorded, not summarised |
| Fold into `ARCHITECTURE.md` §16.4 and `standards` §16 as a **separate recorded act** | Architect | `R-P5` respected — no register is edited from inside an EP-01 task |
| Re-issue the record as **v0.4** and sign §11 | Founder | Phase status `Ready` |
| Branch → PR → `staging` → `main` | Founder + agent | Merged through the gate, not pushed |

**What stays true regardless:** the repository remains private (`#25`); `DEV-002` still ends at
EP-01 `G5` or when host protection exists, whichever is earlier, and never extends to `G4`;
`R-P1` (broken local toolchain) still has to be fixed before any item that needs a local build.
