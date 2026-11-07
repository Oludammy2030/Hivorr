# Hivorr — Database Migration & Supabase Data API Rules

| Field | Value |
| --- | --- |
| **Status** | **APPROVED — 3 November 2026.** Position A adopted 3 November 2026. Supersedes the undated previous version. |
| **Supersedes** | `Database Migration & Supabase Data API Rules.md` (undated, 24 sections, previously supplied as a download) |
| **Owner** | Engineering governance |
| **Applies to** | Every schema change, every database role, every grant, every policy, every migration, and every environment |
| **Verified against** | Official Supabase documentation, checked **3 November 2026**. Sources listed in §14. |
| **Review trigger** | Any Supabase platform-default change; any change to `ARCHITECTURE.md` §7 or §9; the first migration written |

> **Position A is decided — 3 November 2026.** If Supabase is used at all, it is used as managed
> Postgres only: the Data API and GraphQL API are disabled, Supabase Auth is not used, and no
> Supabase key exists in any client. §2.4 records the decision; §3–§8 are the rules that follow
> from it.
>
> **The remaining decisions in §13 stay open.** They are not implied by this approval and must be
> recorded separately before implementation begins.

---

## How to read this document

Every rule carries a classification. The classification is the point: it tells you whether you are
looking at how Supabase behaves, what Supabase advises, a configuration choice, or a Hivorr rule.

| Tag | Meaning | Can Hivorr change it? |
| --- | --- | --- |
| **[REQUIREMENT]** | Current Supabase platform behaviour. It is how the product works, not a policy. | No. You can only stop using the feature. |
| **[RECOMMENDATION]** | Official Supabase security guidance. Strongly advised; **not** platform-enforced. | Yes — but you must record why. |
| **[OPTIONAL]** | A supported configuration choice. Neither required nor advised against. | Yes, freely. |
| **[HIVORR]** | A Hivorr engineering decision. It exists because of our domain, not because Supabase requires it. | Yes, by decision. |
| **[DECIDED]** | A Hivorr decision that has been made and is binding. Changing it requires a recorded revision, not an edit. | Only by a new decision. |
| **[OPEN]** | Undecided. **Do not implement as though it were decided.** | — |

Two rules govern the whole document:

1. **A recommendation is never written as a requirement.** Where Supabase says "enable RLS on every
   exposed table", that is official guidance with a Danger callout — it is not a switch Supabase
   flips for you. It is tagged **[RECOMMENDATION]** and Hivorr adopts it as a **[HIVORR]** rule
   where stated.
2. **Hivorr's business rules are not Supabase's business rules.** Supabase governs *reachability*
   (grants, roles, keys). Hivorr governs *authorisation* (who may do what, to which row, in which
   activity). Conflating the two is the single most common way a Supabase project leaks data.

### Source-of-truth hierarchy

| Concern | Authority |
| --- | --- |
| Product purpose, activities, principles | `VISION.md` |
| Account, activity, verification, permission model | `Unified-Account-and-Activity-Permission-Matrix.md` |
| Stack, data layer, backend, authorisation layers | `ARCHITECTURE.md` — **approved** |
| Engineering and security rules | `AGENTS.md` |
| UI | The prototype (`src/app/App.tsx`) — the only UI source of truth |
| **Database mechanics and migration practice** | **This document** |

If this document contradicts `ARCHITECTURE.md`, `ARCHITECTURE.md` wins and this document has a
defect. If it contradicts the permission matrix on who may do what, the matrix wins. Report the
conflict; do not pick a side.

---

## 1. Purpose and scope

### 1.1 What this document governs

- How the database is reached, by which role, from which process.
- Grants, roles, row-level security, function privileges, and key handling.
- How schema changes are written, reviewed, versioned, tested, and deployed.
- How environments are separated and how credentials are handled.
- How the database enforces Hivorr's one-account/six-activity model.
- How migrations are reviewed for security before they reach production.

### 1.2 What this document does not govern

- Application authorisation logic. That is the service layer (`ARCHITECTURE.md` §5.2, §9.2).
- UI or presentation. The prototype governs.
- The choice of managed Postgres provider. That is `ARCHITECTURE.md` §15 and remains **[OPEN]**.
- Business rules for fees, escrow, disputes, KYC limits, or retention. Those are founder decisions.

### 1.3 Why the previous version needed revision

The previous document was competent on migration discipline and least privilege, and it correctly
identified the October 2026 exposure change. But it was written for an architecture Hivorr does not
have:

| Previous assumption | Approved reality |
| --- | --- |
| The browser reaches Postgres through the Supabase Data API | The SPA calls a NestJS/Fastify REST API; the API reaches Postgres directly |
| Supabase Auth supplies `auth.uid()` to RLS policies | Hivorr builds its own auth (Argon2id, Termii OTP, server sessions). There is no Supabase JWT. |
| RLS and RPC are the primary enforcement mechanism | Authorisation is service-layer; RLS is defence in depth (`ARCHITECTURE.md` §7.5, §9.2) |
| Supabase Storage holds user documents | Object storage is Cloudflare R2, private buckets, signed URLs |
| `anon` and `authenticated` are the roles that matter | The roles that matter are the API's own Postgres role and the migrator role |

That gap is the reason for §2.

### 1.4 The provider question

`ARCHITECTURE.md` §15 lists the database as **"Managed PostgreSQL (Neon, Supabase, or RDS)"**. The
provider is **not chosen**. Therefore:

- **Everything in §9 (migration standards), §10 (environments), §11 (testing), and §12 (Hivorr
  governance) applies regardless of provider.** They are Hivorr rules about Postgres.
- **§4, §5, §6, §7, and §8 describe Supabase specifically.** They bind Hivorr **only if Supabase is
  selected**, or if any Supabase component (Data API, Storage, Auth) is ever adopted.
- If Neon or RDS is selected, this document's Supabase sections become reference material, and the
  provider's own migration and role guidance replaces them.

Do not implement Supabase-specific mechanics on the assumption that Supabase will be chosen.

---

## 2. The architecture this document must serve

### 2.1 The approved stack, in one paragraph

Hivorr is a **modular monolith**. A React SPA calls a **NestJS + Fastify** REST API over `/v1`. The
API owns all business logic in a service layer, opens an explicit transaction per mutation, and
reaches Postgres through a repository layer that issues SQL. Each of ten modules owns its own
PostgreSQL schema: `identity`, `profile`, `market`, `services`, `errands`, `logistics`, `finance`,
`messaging`, `admin`, `platform`. Authorisation is capability-based and computed server-side from
account, activated activities, verification state, KYC tier, and admin role. RLS is **defence in
depth**, not the primary gate.

### 2.2 The conflict the previous document created

**The previous document's entire security model depended on a component the approved architecture
does not use.** This was a real conflict, not a wording problem, and it has been settled.

The two sides were irreconcilable:

If Hivorr followed `ARCHITECTURE.md`:

- The SPA never holds a Supabase key.
- The browser never calls `/rest/v1/`.
- There is no Supabase JWT, so `auth.uid()` returns `NULL` and every policy written against it fails
  closed for every user.
- `anon` and `authenticated` receive no requests, so grants to them are irrelevant — and, if the Data
  API is left enabled, are pure attack surface.
- RLS, if it is to mean anything, must be driven by something the API sets, not by Supabase Auth.

If Hivorr had followed the previous document:

- The SPA would call the Data API directly with a publishable key.
- Supabase Auth would issue the JWT.
- RLS would become the primary gate.
- This would contradict `ARCHITECTURE.md` §5.1, §7.5, §9.2, §10, and §8.2.

**Both could not be true.** The conflict was resolved on 3 November 2026 in favour of the approved
architecture. §2.4 records the decision; §3 states the resulting posture; §6.4 states the identity
mechanism that replaces `auth.uid()`. Position B is retained in this document only as a documented
counterfactual, so that the cost of reversing the decision is visible rather than implied.

### 2.3 What follows from the approved architecture

| Consequence | Status |
| --- | --- |
| The Data API is not Hivorr's data path | **[DECIDED]** — follows from `ARCHITECTURE.md` §5, §10; §2.4 |
| The Data API and GraphQL API are disabled when Supabase is the provider | **[DECIDED]** — §2.4, §3.2 |
| The SPA holds no Supabase publishable key, secret key, or `service_role` key | **[DECIDED]** — §2.4, §5.6 |
| The API connects with a dedicated, least-privilege Postgres role | **[DECIDED]** — §6.9 |
| `auth.uid()` is unavailable and must not appear in Hivorr policies | **[REQUIREMENT]** — it is a Supabase Auth helper |
| RLS policies key off a value the API sets per transaction | **[DECIDED]** — §6.4 |
| Supabase Storage is not used; R2 is | **[DECIDED]** — `ARCHITECTURE.md` §15, §8.1 |
| Supabase Auth is not used; Hivorr auth is | **[DECIDED]** — `ARCHITECTURE.md` §8.2 |
| Supabase Branching is optional, not assumed | **[OPTIONAL]** |

### 2.4 Decision — Position A, adopted 3 November 2026

> **[DECIDED] — Position A. Adopted by the founder on 3 November 2026.**
>
> **Position A — Postgres-only.** Supabase, if chosen as the managed Postgres provider, is used
> strictly as managed Postgres:
>
> - The **Data API and GraphQL API are disabled** (§3.2).
> - **Supabase Auth is not used**; Hivorr's own authentication issues sessions (`ARCHITECTURE.md`
>   §8.2).
> - **No Supabase key exists in any client** — no publishable key, no secret key, no
>   `service_role` key (§5.6).
> - The API connects **directly** over Postgres with a dedicated, least-privilege role (§6.9).
> - RLS is **defence in depth**, keyed off a transaction-scoped session variable set by the
>   repository layer (§6.4).
> - **Storage is Cloudflare R2**, not Supabase Storage (§8.1).
>
> **What this settles:**
>
> - Every Supabase-specific rule in §4 applies only if a Data API surface is ever deliberately
>   enabled under §3.3. Until then they are conditional knowledge, not active requirements.
> - §5.4 (`anon`), §5.5 (`service_role`), §6.3 (Data-API policy style), §8.2–§8.4 (Storage policies)
>   are dormant unless their surface is enabled.
> - §6.4 is the binding identity mechanism for Hivorr.
>
> **What this does not settle.** Position A decides the *shape* of the data path, not the
> infrastructure behind it. Still open in §13: the managed Postgres provider itself, role names,
> the exact identity mechanism implementation, and the ten product and operational decisions
> listed there.
>
> **Position B — Data-API-first — is rejected.** It would have required the SPA to call the Data API,
> Supabase Auth to issue the JWT, and RLS to become the primary gate. Reversing Position A is not an
> edit to this document: it requires rewriting `ARCHITECTURE.md` §5, §8, §9, and §10, and the
> permission matrix §11, and then revising §2–§8 of this document. It is a much larger change than
> it appears, and the cost is the reason it is recorded here rather than deleted.

---

## 3. Data API posture

### 3.1 What the Data API is

**[REQUIREMENT]** The Supabase Data API is an auto-generated REST interface (PostgREST) — and,
separately, a GraphQL interface (`pg_graphql`) — reflected directly from the database schema. It is
reached at `https://<project_ref>.supabase.co/rest/v1/`. Every table, view, and function in an
exposed schema is a potential endpoint the moment grants allow it.

It is a **two-tier** architecture: the client talks to the database. Hivorr is a **three-tier**
architecture: the client talks to our API, and our API talks to the database.

### 3.2 Hivorr's default: disabled

**[DECIDED]** If Supabase is the managed Postgres provider, the Data API is **disabled**. This is
Position A (§2.4), adopted 3 November 2026. It is not a default that can be changed per environment
or per sprint.

**[OPTIONAL]** Supabase supports this directly: Data API integration → **Enable Data API** off.
With it off, no auto-generated REST endpoint responds, regardless of grants or RLS.

Rationale:

- It removes an entire internet-facing surface that Hivorr does not use.
- It removes the need for any publishable key, which removes the need to reason about `anon`.
- It eliminates the class of bug where a new table is accidentally reachable because a default grant
  survived.
- It makes the security model auditable in one place: the API's own routes.

**GraphQL follows the same rule.** **[REQUIREMENT]** `pg_graphql` stopped being enabled by default
on 18 May 2026. **[DECIDED]** It stays disabled; `ARCHITECTURE.md` §10 records GraphQL as not at MVP.

### 3.3 If a Data API surface is ever enabled

Any decision to enable it is a security decision, not a convenience. Before it is enabled, all of
the following must be true and recorded:

1. A named, written use case exists that the REST API cannot serve.
2. The exposed schema set is the **minimum** — never `public` by default (§4.6).
3. Every exposed table has RLS enabled and a policy per operation (§6).
4. `anon` and `authenticated` hold only the privileges that use case needs (§5.4).
5. `service_role` is not reachable from any client.
6. A policy test file exists per exposed table and passes under `supabase test db` (§11.2).
7. The security review in §11.4 is signed off.
8. The decision, the owner, and the review date are recorded in the changelog of this document.

Partial enablement is not permitted. "Just one table for an internal dashboard" is how exposed
surfaces grow.

### 3.4 What the Data API is not

- It is not an authorisation system. Grants decide reachability; RLS decides rows; neither knows what
  a "verified seller" is.
- It is not a replacement for the service layer.
- It is not a migration tool. It reflects schema; it does not version it.
- It is not a place to put business logic in RPCs. See §7.5.

---

## 4. Current Supabase Data API rules

*Verified 3 November 2026. Applies only if a Data API surface exists (§3.3).*

### 4.1 The 2026 exposure change

**[REQUIREMENT]** Supabase changelog **45329**, *"Breaking Change: Tables not exposed to Data and
GraphQL API automatically"*, published **28 April 2026**:

| Date | What happened |
| --- | --- |
| **28 April 2026** | New projects can opt in to *not* auto-exposing `public` tables. |
| **18 May 2026** | `pg_graphql` is no longer enabled by default. |
| **30 May 2026** | The new default begins rolling out to new projects. |
| **30 October 2026** | The setting is applied to **all existing projects**. |

**As of 3 November 2026 this change is already in force.** It is not a future event.

**[REQUIREMENT]** After rollout, a **new** table created in `public` requires an explicit Postgres
`GRANT` before it is reachable through the Data API or GraphQL API. A table can exist, be correct,
and be entirely invisible to the API.

The previous document dated this to "starting October 30, 2026" as a future change and treated it
as a permanent Hivorr engineering rule. The date was right; the tense was wrong. It has happened.

### 4.2 What the change does and does not do

| Does | Does not |
| --- | --- |
| Apply to **new** tables in `public` | Remove grants from **existing** tables |
| Apply to the Data API (PostgREST) and GraphQL API | Affect a **direct Postgres connection** |
| Require an explicit `GRANT` for reachability | Enable RLS, or change any policy |
| Apply regardless of which tool created the table | Apply to tables outside the exposed schema set |

**[REQUIREMENT]** Existing tables keep their grants. Nothing is retroactively revoked.

**[HIVORR]** Do not mass-rewrite existing tables because of this change. Audit them (§4.5), remove
unnecessary exposure, and let future migrations be explicit.

### 4.3 Default privileges on new objects

**[REQUIREMENT]** Default privileges differ by project age and Data API settings. On projects that
still grant automatically, a new object in `public` receives:

| Object | Roles | Privileges granted |
| --- | --- | --- |
| Tables | `anon`, `authenticated`, `service_role` | `select`, `insert`, `update`, `delete`, `truncate`, `references`, `trigger`, and `maintain` (Postgres 17) |
| Functions | `anon`, `authenticated`, `service_role` | `execute` |
| Sequences | `anon`, `authenticated`, `service_role` | `usage`, `select`, `update` |

Three consequences the previous document did not capture:

1. **The grant set is wider than the Data API uses.** Tables also get `truncate`, `references`,
   `trigger`, and `maintain`. A database function running as `anon` or `authenticated` can use them.
2. **Functions are callable by every role by default.** Postgres grants `execute` to `PUBLIC`
   through a *global* default. A revoke limited to one schema does not remove it.
3. **Disabling "Automatically expose new tables" is not the same as revoking everything.** It removes
   what the Data API uses; the wider grants and the `PUBLIC` execute grant remain.

**[RECOMMENDATION]** To make exposure truly opt-in, revoke the defaults explicitly:

```sql
alter default privileges for role postgres in schema public
  revoke all on tables from anon, authenticated, service_role;

alter default privileges for role postgres in schema public
  revoke all on sequences from anon, authenticated, service_role;

alter default privileges for role postgres in schema public
  revoke all on functions from anon, authenticated, service_role;

-- Global, deliberately not scoped to a schema.
alter default privileges revoke execute on functions from public;
```

**Warning carried from the official guidance:** the last statement also restricts functions
`postgres` creates in *other* schemas, including helper functions RLS policies call. Grant `execute`
back on each helper, or those policies fail.

**[HIVORR]** Hivorr does not rely on any default privilege. Every grant is written explicitly in a
migration. This is true whether or not the platform still grants by default.

### 4.4 Missing grants: the `42501` error

**[REQUIREMENT]** A missing grant raises PostgREST error `42501` **before any policy runs**, and the
hint names the exact statement needed:

```json
{
  "code": "42501",
  "message": "permission denied for table your_table",
  "hint": "Grant the required privileges to the current role with: GRANT SELECT ON public.your_table TO anon;"
}
```

**[RECOMMENDATION]** When a request fails that a policy should allow, **check the grant before
changing the policy.** A `42501` is a grant problem; an empty result is a policy problem. They look
different and must not be debugged the same way.

### 4.5 Existing tables: the audit

**[HIVORR]** If Supabase is adopted with an existing project, audit before changing anything:

1. List every table in every exposed schema.
2. For each, record: exposed? granted to whom? RLS on? policies per operation? owner column?
3. Remove `anon` and `authenticated` grants from anything the application does not serve directly.
4. Enable RLS on anything still exposed.
5. Write a policy test per table.
6. Record the audit result. Do not change a table without a migration.

### 4.6 Exposed schemas

**[REQUIREMENT]** By default only `public` is exposed to the Data API. Additional schemas are exposed
by adding them to **Exposed schemas** in API settings **and** granting usage and object privileges.

**[RECOMMENDATION]** Use a dedicated exposed schema (for example `api`) that contains only views and
functions intended as the API surface. Keep internal tables in schemas that are not exposed. This
makes the exposed surface enumerable and auditable.

**[HIVORR]** Hivorr's schemas are module schemas (`market`, `finance`, …) and are **not** an API
surface. If a Data API surface ever exists, it is a separate, thin schema — never a module schema,
and never `public`.

**A conflict to note, not silently resolve.** The official *Using Custom Schemas* guide's setup
snippet grants `ALL` on all tables, routines, and sequences to `anon`, `authenticated`, and
`service_role`, and sets matching default privileges. That snippet is a **setup example**, not a
least-privilege recommendation, and it contradicts the same documentation's own least-privilege
guidance. **Hivorr must never copy it.** Grant only the specific privilege on the specific object to
the specific role.

### 4.7 Pre-request checks

**[OPTIONAL]** PostgREST can run a Postgres function before every Data API request:

```sql
alter role authenticator set pgrst.db_pre_request = 'public.check_request';
notify pgrst, 'reload config';
```

Used for rate limiting, extra key checks, quota enforcement, or blocking direct access to certain
objects.

**Limitation that matters:** **[REQUIREMENT]** `pgrst.db_pre_request` works only with the Data API.
It does **not** apply to Storage, Realtime, or any other product. If the same check must hold
everywhere, it must also be called inside the RLS policy.

**[HIVORR]** Hivorr does not use pre-request checks. Rate limiting and quota enforcement belong in
the API layer (`ARCHITECTURE.md` §10), where they are testable and provider-independent.

### 4.8 Classification summary

| Rule | Class |
| --- | --- |
| New `public` tables need an explicit grant for API reachability | **[REQUIREMENT]** |
| Existing tables keep their grants | **[REQUIREMENT]** |
| Direct Postgres connections are unaffected | **[REQUIREMENT]** |
| Default privileges are wider than the Data API uses | **[REQUIREMENT]** |
| `execute` is granted to `PUBLIC` globally | **[REQUIREMENT]** |
| Revoke defaults to make exposure opt-in | **[RECOMMENDATION]** |
| Use a dedicated exposed schema | **[RECOMMENDATION]** |
| Check grants before policies on `42501` | **[RECOMMENDATION]** |
| Pre-request checks | **[OPTIONAL]** |
| Data API disabled | **[HIVORR]** |
| No Data API surface without a recorded decision | **[HIVORR]** |

---

## 5. Access and security principles

### 5.1 Grants and RLS are separate controls

**[REQUIREMENT]** Postgres runs two checks before a client touches a table:

1. **Grants** — can this role run this operation on this object at all?
2. **Policies** — which rows does the operation apply to?

> A `GRANT` controls whether a role can reach the object. RLS controls which rows that role can
> access.

Neither replaces the other. A table with RLS but no revoke still hands `anon` an insert path if the
grant survived. A table with a grant but no RLS is fully readable to that role.

**[HIVORR]** Every table gets both decisions written down, in the same migration, even when one of
them is "no access".

### 5.2 Least privilege

**[HIVORR]** Every role gets the minimum privilege on the minimum object for the minimum time.

| Never do | Do instead |
| --- | --- |
| `grant all on all tables in schema …` | Grant the named privilege on the named table |
| Grant `service_role` "just in case" | Grant nothing; add it when a named job needs it |
| Grant `anon` because a page is public | Serve public data through the API's own public route |
| Grant DDL to a runtime role | Keep DDL in the migrator role |
| Grant `truncate` to a runtime role | Delete rows through the API, with an audit record |

### 5.3 Do not use a grant as a security workaround

**[HIVORR]** A permission error is information, not an obstacle. Before adding a grant:

1. Identify the exact object.
2. Identify the role making the request.
3. Decide whether that access is intended at all.
4. Identify the exact operation.
5. Review RLS and existing policies.
6. Apply the minimum grant.
7. Test the full request, allow and deny.

A `42501` must never be answered with `grant all`, and never with a grant to `anon`, `authenticated`,
or `service_role` "to see if it fixes it".

### 5.4 `anon`

**[REQUIREMENT]** `anon` is the Postgres role used when a request carries a publishable key and no
signed-in user. It is **not** the same as a Supabase anonymous user, which assumes `authenticated`
and carries an `is_anonymous` claim.

**[HIVORR]** `anon` receives **no** grant on any Hivorr table. The public surfaces Hivorr needs —
catalogue browsing, public professional profiles — are served by the API from a projection, not by
opening a table to `anon`.

### 5.5 `service_role` and secret keys

**[REQUIREMENT]** `service_role` has the `BYPASSRLS` attribute. **RLS never applies to it.** A
missing grant still produces a permission error for it; a present grant reaches every row.

**[REQUIREMENT]** A secret key authorises through `service_role` and bypasses RLS **only when the
request carries no user access token**. If the request carries one, it runs under that user's
policies even when the client was initialised with a secret key.

**[HIVORR]** No secret key, and no `service_role` JWT, exists in any Hivorr application process. The
API connects as its own role with explicit grants and no `BYPASSRLS`.

### 5.6 API keys and secrets

**[REQUIREMENT]** Supabase has four key types:

| Type | Format | Privileges | Use |
| --- | --- | --- | --- |
| Publishable | `sb_publishable_…` | Low | Anything shipped to a user |
| Secret | `sb_secret_…` | Elevated | Server-side only; bypasses RLS |
| `anon` (legacy) | JWT, `eyJ…` | Low | Deprecated |
| `service_role` (legacy) | JWT, `eyJ…` | Elevated | Deprecated |

**[REQUIREMENT]** The `anon` and `service_role` keys are **deprecated by the end of 2026**. The
replacements are the publishable and secret keys.

**[REQUIREMENT]** Publishable and secret keys are **not JWTs**. Send them on the `apikey` header, not
`Authorization: Bearer`. Anything that tries to verify one as a JWT fails.

**[REQUIREMENT]** A secret key is rejected from a browser — Supabase matches the `User-Agent` and
returns `401`. This is a safety net, **not** a control. Do not rely on it.

**[HIVORR]** The strongest rule in this document:

> **The SPA holds no Supabase key of any kind.** No publishable key, no secret key, no legacy
> `anon` key, no legacy `service_role` key. The SPA's only credential is the Hivorr session cookie or
> bearer token.

If a build ever needs a Supabase key in the browser, the architecture has changed and §2.4 must be
reopened.

Secret handling rules, adopted from the official guidance:

- Never in source control, a URL, a query string, a log line, a chat message, or a screenshot.
- Never printed. If a key must be identified, record no more than six characters after the prefix,
  or a SHA-256 hash.
- One secret per backend component, so a leak is contained.
- Stored in the platform secret store, injected at boot, validated by schema
  (`ARCHITECTURE.md` §5.4).
- Rotated immediately on suspected exposure.

### 5.7 Views

**[REQUIREMENT]** Views bypass RLS by default, because Postgres creates them with `security definer`
semantics under the creating role. A view over a protected table can hand out every row the policies
were meant to withhold.

**[RECOMMENDATION]** On Postgres 15 and above, create views with `security_invoker = true` so the
caller's policies apply:

```sql
create view api.public_professional
with (security_invoker = true)
as select …;
```

**[HIVORR]** Every Hivorr view is either `security_invoker = true`, or lives in a schema no client
can reach, or both. A view is reviewed with the same rigour as a table.

### 5.8 The direct-connection equivalent

**[HIVORR]** Because Hivorr's API connects directly, the grant/RLS pair is replaced by a three-part
control:

| Control | Where it lives |
| --- | --- |
| Role privilege | `GRANT` on the API role, in a migration |
| Row visibility | RLS on tenant tables, driven by a transaction-scoped setting |
| Business authorisation | Service layer, inside the transaction |

All three are required. The first is the analogue of a grant; the second of a policy; the third has
no Supabase equivalent and is where Hivorr's rules actually live.

---

## 6. RLS and privilege rules

### 6.1 When RLS is required

**[RECOMMENDATION — strong]** Enable RLS on **every table in an exposed schema**. The official
guidance is unambiguous: a table in an exposed schema without RLS is readable and writable by any
role with a grant on it.

**[REQUIREMENT]** Tables created through the Supabase Dashboard have RLS enabled by default. Tables
created in the SQL Editor, by the CLI, or by a migration **do not**. The default is not a safety net;
it is a property of one creation path.

**[HIVORR]** RLS is enabled on every table that holds account-scoped data, in the same migration that
creates the table. Tables that hold no account-scoped data (reference data, taxonomy) either have RLS
with a read-only policy or live in a schema the API role cannot reach.

### 6.2 RLS is not the authorisation model

**[HIVORR]** This is the most important divergence from the previous document.

`ARCHITECTURE.md` §7.5 and §9.2 and the permission matrix §11.1 place authorisation in the
**service layer**. RLS exists so that a missed filter fails closed rather than leaking rows.

| Layer | Question it answers | If missing |
| --- | --- | --- |
| Route guard | Is this request in scope? | Noise, not a breach |
| Service policy | May this account perform this capability on this record? | **The breach** |
| Database tenancy | Can this connection even see the row? | Cross-account leakage |

RLS cannot express "a seller may publish a product only when the seller lane is `APPROVED` and the
store is active and the category is bound and the account is not suspended". Do not try. Put it in
the service layer and test it there.

### 6.3 Writing policies

**[RECOMMENDATION]** For every table:

1. Enable RLS.
2. Revoke existing grants from client roles.
3. Grant back only what the role needs.
4. Write **one policy per operation** — `select`, `insert`, `update`, `delete`. Postgres does not
   accept multiple operations in one `for` clause, and `for all` hides which rule covers what.
5. Always name the role with `to`.
6. Write a test file (§11.2).

**[RECOMMENDATION]** Use `using` to filter visible rows, and `with check` to constrain written rows. The
example below is the **official Supabase pattern for a Data API surface**. Position A (§2.4) is
adopted, so this pattern is **not** Hivorr's and is retained only as the reference for the
conditional case in §3.3. The binding equivalent is §6.4.

```sql
create policy "owner reads own rows"
on market.order for select
to authenticated
using ( (select auth.uid()) is not null
        and (select auth.uid()) = owner_account_id );

create policy "owner updates own rows"
on market.order for update
to authenticated
using ( (select auth.uid()) = owner_account_id )
with check ( (select auth.uid()) = owner_account_id );
```

**Two traps the previous document missed:**

- **[REQUIREMENT]** An `UPDATE` requires a corresponding `SELECT` policy. Without one, the update
  silently matches nothing.
- **[REQUIREMENT]** `auth.uid()` returns `NULL` when there is no authenticated user. `NULL = x` is
  never true, so the policy fails silently. Write the null check explicitly.

### 6.4 The identity function: `auth.uid()` is not available to Hivorr

**[REQUIREMENT]** `auth.uid()` is a Supabase Auth helper. It reads the `sub` claim from a Supabase
JWT. Hivorr does not use Supabase Auth (`ARCHITECTURE.md` §8.2), so **`auth.uid()` returns `NULL` for
every Hivorr request**.

**[DECIDED]** RLS policies read a transaction-scoped setting that the API sets inside each
transaction. This is the identity mechanism adopted with Position A (§2.4) on 3 November 2026:

```sql
-- In the repository layer, inside the transaction:
set local app.account_id = '0192f3c1-…';

-- In the policy:
create policy "tenant isolation"
on market.order for select
to hivorr_api
using (
  current_setting('app.account_id', true) is not null
  and owner_account_id = current_setting('app.account_id', true)::uuid
);
```

Rules that make this safe:

- **`set local`, never `set`.** `set local` is transaction-scoped. A session-level `set` leaks across
  pooled connections and is a cross-account breach waiting to happen.
- **`current_setting(…, true)` returns `NULL` when unset**, so the policy must include an explicit
  `is not null` check. Fail closed, not open.
- **Set the value from the authenticated session, never from a request body.** The service layer
  resolves the account from the session; the repository sets what it was given.
- **Clear or overwrite it at the start of every transaction.** Never rely on the previous one.
- **The API role must not own the tables and must not have `BYPASSRLS`.** Owners bypass RLS by
  default. If the API role must own them, add `alter table … force row level security`.
- **Transaction-mode pooling is compatible** with `set local`; session-mode assumptions are not.

If this pattern is later rejected, the alternative is to accept that RLS is partial and that the
repository layer is the only tenancy control. That is a legitimate choice, but it requires a new
recorded decision, because it changes what RLS is for. The **implementation detail** — the exact
setting name, whether it carries one account or a full actor context — remains open in §13.

### 6.5 `FORCE ROW LEVEL SECURITY`

**[REQUIREMENT]** Table owners bypass RLS unless `force row level security` is set. Superusers and
roles with `BYPASSRLS` always bypass it, and `force` does not change that.

**[HIVORR]** Migrations run as a migrator role that owns the objects. The API runs as a separate role
that owns nothing. This means `force` is not needed in normal operation — but it is required if the
API role ever becomes an owner. Verify with a test that the API role cannot see another account's
rows (§11.3).

### 6.6 Index the columns policies filter on

**[RECOMMENDATION]** Postgres evaluates the policy against each candidate row. An unindexed filter
column turns every read into a sequential scan. Add an index on every column a policy filters on.

**[REQUIREMENT]** A column counts as indexed only when it is the **leading** column of a `btree`
index. A composite primary key on `(account_id, id)` does not index `id`.

**[HIVORR]** Every `owner_account_id` and every party column used in a policy has a leading index.

### 6.7 Recursive policies

**[REQUIREMENT]** Two tables whose policies read each other never resolve. Postgres raises `42P17`,
*infinite recursion detected in policy for relation*, and the query fails for every role the policies
apply to.

**[RECOMMENDATION]** Break the cycle with a `security definer` function in a private schema that
reads the membership table as its owner, then reference it from both policies.

**[HIVORR]** Hivorr's transaction tables reference counterparties. Any policy that needs to check
"is this account a party to this order" must use a single helper function, not a mutual policy read.

### 6.8 What RLS cannot do

- It cannot enforce a capability. It has no knowledge of verification states or KYC tiers unless you
  join to them on every row — which is slow and duplicates the service layer.
- It cannot protect a `security definer` function. RLS does not apply to functions; only `execute`
  grants do.
- It cannot protect Storage, Realtime, or Auth.
- It cannot protect a view unless the view is `security_invoker`.
- It cannot stop a role with `BYPASSRLS`.

### 6.9 Privilege matrix for Hivorr roles

**[HIVORR — proposed]** Five roles, no exceptions:

| Role | Used by | Privileges | `BYPASSRLS` | DDL |
| --- | --- | --- | --- | --- |
| `hivorr_migrator` | CI migration step only | Owns objects; full DDL in module schemas | No | Yes |
| `hivorr_api` | API process | `select`, `insert`, `update`, `delete` on named tables; `execute` on named functions | **No** | No |
| `hivorr_worker` | Worker process | Same as API, plus the queue tables | **No** | No |
| `hivorr_readonly` | Analytics / read models | `select` on named views only | No | No |
| `postgres` | Break-glass only | Platform admin | Yes (platform) | Yes |

Rules:

- No Hivorr application role is a superuser, has `createdb`, `createrole`, or `BYPASSRLS`.
- The API role is never the table owner.
- The API role never receives `truncate`.
- The migrator role is used only by CI, with credentials scoped to the migration step.
- `postgres` is never used by application code. It is break-glass, audited.
- Every role has a distinct credential per environment.

**[OPEN]** The exact role names and whether `hivorr_worker` is separate from `hivorr_api` are
proposals, not decisions. They must be confirmed before the first migration.

---

## 7. Functions and RPC security

### 7.1 `security invoker` vs `security definer`

**[REQUIREMENT]** A function runs as its **invoker** by default. A `security definer` function runs
as its **creator** — on Supabase, typically `postgres`, which has `BYPASSRLS`.

**[RECOMMENDATION]** Prefer `security invoker`. Use `security definer` only when the function must
read data the caller cannot, and then apply every rule in this section.

### 7.2 Pin `search_path`

**[REQUIREMENT]** Every `security definer` function must set `search_path = ''` and schema-qualify
every name in its body:

```sql
create function private.has_good_role()
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
begin
  return exists (
    select 1 from public.roles_table
    where (select auth.uid()) = user_id and role = 'good_role'
  );
end;
$$;
```

Without a pinned `search_path`, a caller can point an unqualified name at their own object and have
it executed with the function owner's privileges.

### 7.3 Execute privileges

**[REQUIREMENT]** By default, **any role can run any function**, because Postgres grants `execute` to
`PUBLIC`. This is true even on a table with perfect RLS.

**[RECOMMENDATION]** Revoke per function:

```sql
revoke execute on function public.hello_world from public;
revoke execute on function public.hello_world from anon;
grant  execute on function public.hello_world to authenticated;
```

Or revoke by default and grant explicitly (§4.3).

**[REQUIREMENT]** An `execute` grant controls **who may call** the function. It does **not** limit
**which rows** the caller gets back. A `security definer` function that returns per-user data must
check ownership **inside the function body**, or every permitted caller sees every row.

### 7.4 Never create a `security definer` function in an exposed schema

**[REQUIREMENT]** A `security definer` function in an exposed schema is callable over the Data API
with the creator's privileges. Never create one there.

**[HIVORR]** All `security definer` helpers live in a `private` schema that the API role cannot
reach and that is not in any exposed schema set. `execute` is granted only to the roles that need
them.

### 7.5 Functions are not the API

**[HIVORR]** The previous document treated RPCs as a first-class API surface. Hivorr's API is REST,
versioned at `/v1`, generated from NestJS controllers (`ARCHITECTURE.md` §10). Database functions
exist for three narrow purposes:

1. RLS helpers (membership checks, party checks) — `security definer`, private schema.
2. Triggers (audit rows, `updated_at`, invariant guards).
3. Set-based maintenance jobs run by the worker.

A business operation implemented as an RPC is a defect: it moves logic out of the testable service
layer, out of the transaction boundary, and out of the audit trail.

### 7.6 Triggers

**[HIVORR]**

- Triggers enforce **invariants**, not authorisation. A trigger may refuse a state transition; it may
  not decide who the user is.
- Every trigger is `security invoker` unless there is a recorded reason.
- A trigger that writes to another module's schema is forbidden (module boundary, §12.2).
- Trigger functions live in the owning module's schema or in `platform`.
- `updated_at` maintenance is one shared trigger function, not one per table.

---

## 8. Storage access policies

### 8.1 Hivorr does not use Supabase Storage

**[HIVORR]** `ARCHITECTURE.md` §15 selects **Cloudflare R2** for object storage: private buckets and
signed URLs. Supabase Storage is not part of the approved stack.

Therefore, for Hivorr:

- No bucket is created in Supabase Storage.
- No `storage.objects` policy is written.
- No Storage key is issued to any client.
- Identity documents, KYC evidence, proof of delivery photos, and chat attachments live in R2 under
  private buckets, served by short-lived signed URLs issued by the API.

This section is retained because it is a **conditional** rule: if Supabase Storage is ever adopted,
everything below applies unchanged.

### 8.2 If Supabase Storage is ever adopted

**[REQUIREMENT]** Storage uses RLS on `storage.objects`. By default, **no upload is allowed** to a
bucket without a policy.

**[REQUIREMENT]** The policy required depends on the operation:

| Operation | Policy needed |
| --- | --- |
| Upload | `insert` on `storage.objects` |
| Overwrite (`upsert`) | `insert` **and** `select` **and** `update` |
| Download | `select` |
| Delete | `delete` |
| List | `select`, scoped so listing is not exposed |

**[RECOMMENDATION]** Scope by bucket and by folder:

```sql
create policy "owner uploads to own folder"
on storage.objects for insert
to authenticated
with check (
  bucket_id = 'private-documents'
  and (storage.foldername(name))[1] = (select auth.jwt()->>'sub')
);
```

**[RECOMMENDATION]** For a public bucket, remember that public buckets are already publicly
accessible. If you need read access without listing, use the operation-aware helper
`storage.allow_any_operation(...)`; without it, a `select` policy also permits listing.

### 8.3 Bucket rules

**[HIVORR]** If adopted:

- Identity, KYC, business registration, bank details, dispute evidence, and chat attachments live in
  **private** buckets only.
- No public URL is ever generated for a sensitive document.
- Object paths are namespaced by `account_id`, never by sequential identifiers.
- Access is signed, short-lived, and logged.
- A deleted object is not recoverable from a database backup (§10.6).

### 8.4 Bypassing Storage policies

**[REQUIREMENT]** A `service_role` key bypasses Storage RLS entirely. It must never be shared or
shipped.

**[HIVORR]** If Supabase Storage were adopted, the API would use a dedicated role with explicit
policies, not `service_role`.

---

## 9. Migration standards

*Applies regardless of provider.*

### 9.1 Migration-first

**[HIVORR]** Every database change is a versioned migration in the repository. No exceptions, and no
undocumented manual change in staging or production.

This includes: tables, columns, relationships, foreign keys, indexes, constraints, enums, functions,
triggers, views, materialised views, grants, revokes, RLS, policies, storage policies, extensions,
roles, and default privileges.

If it is not in a migration, it does not exist.

### 9.2 Tooling

**[HIVORR]** The standard is **plain SQL migrations**, forward-only, numbered and timestamped, stored
in the repository, applied in order. The tool is an implementation detail; the properties are not:

| Property | Requirement |
| --- | --- |
| Reproducible | A clean database built from migrations equals the deployed database |
| Ordered | Deterministic application order; no dependence on filesystem ordering |
| Idempotent at the runner level | The runner tracks what has been applied; re-running applies nothing twice |
| Reviewable | A human can read the SQL and understand the change |
| Atomic | A failed migration does not leave a half-applied state, where the engine allows it |
| Reversible in plan | The down path is known before the up path is applied |

**If the host is Supabase**, the CLI conventions in §9.10 apply. **If the host is Neon or RDS**, use
an equivalent runner; the rules below are unchanged.

### 9.3 Naming

**[HIVORR]**

```
<timestamp>_<module>_<verb>_<object>.sql
```

Examples:

```
20261103120000_market_create_order.sql
20261103120500_market_add_order_status_index.sql
20261104090000_identity_add_mfa_device.sql
```

Rules:

- One logical change per migration. A migration that creates a table, alters three others, and
  backfills data is four migrations.
- The module prefix matches the owning schema.
- The verb is `create`, `add`, `alter`, `drop`, `backfill`, `grant`, `policy`, `seed`.
- Never rename an applied migration. Never edit an applied migration.
- Never reuse a timestamp.

### 9.4 Self-containment

**[HIVORR]** A migration that creates an object creates its **complete security posture** in the same
migration:

```
table
├── columns, types, defaults, nullability
├── primary key
├── foreign keys and their delete behaviour
├── check constraints (state enums, money sign, date ordering)
├── indexes, including every policy filter column
├── RLS enabled
├── one policy per operation
├── grants / revokes for every role
└── comments on non-obvious columns
```

A table created in one migration and secured by hand in a dashboard is an incomplete migration. The
migration must represent the intended final state, not a step toward it.

### 9.5 Forward-only and expand/contract

**[HIVORR]** Migrations are forward-only (`ARCHITECTURE.md` §7.4). There is no "down" script applied
in production. Breaking changes use **expand/contract**:

| Phase | Action | Deployable alone? |
| --- | --- | --- |
| **Expand** | Add the new column / table / index. Keep the old one. Write to both if needed. | Yes |
| **Migrate** | Backfill in batches. Dual-read or dual-write. | Yes |
| **Switch** | Application reads the new shape. | Yes |
| **Contract** | Remove the old column / table, in a later release. | Yes |

A rollback of the application never requires a destructive database change. That is the whole point.

**[REQUIREMENT — Postgres]** Use `create index concurrently` for indexes on live tables, and set a
`lock_timeout` in the migration so a blocked `alter table` fails fast instead of queueing every
reader behind it.

### 9.6 Destructive changes

**[HIVORR]** A destructive change is any `drop`, `truncate`, type narrowing, `not null` addition
without a default, or constraint that existing rows violate.

Before a destructive change is approved:

1. The data is backed up, or provably reproducible.
2. The rows affected are counted in staging.
3. The change is in its own migration, never mixed with additive work.
4. The application no longer reads or writes the object (contract phase complete).
5. A rollback plan exists that does not require restoring the whole database.
6. Two reviewers sign off, one of whom is not the author.

**[HIVORR]** Financial and audit records are never deleted (`ARCHITECTURE.md` §7.3). A migration that
drops a ledger, journal, or audit table is rejected, not reviewed.

### 9.7 Data migrations

**[HIVORR]**

- Schema and data are separate migrations. A schema migration never contains a large `update`.
- Backfills are batched (for example 5,000 rows per statement), idempotent, and resumable.
- A backfill never runs inside the same transaction as a DDL change on a large table.
- Every backfill has a verification query that proves the intended end state.
- A backfill that changes money is reconciled against the ledger before and after.

### 9.8 Seeds and test data

**[HIVORR]**

- **Reference data** (taxonomy, categories, configuration defaults) is seeded by migration, because
  the application depends on it.
- **Development convenience data** lives in a seed file, never in a migration.
- **Test fixtures** are created by the test, in the test, and rolled back. They are not shared rows.
- **Production never receives seed data.** `--include-seed` is forbidden against production.
- **No real personal data in any non-production environment.** Identity documents, bank details, and
  phone numbers are generated or anonymised.

If Supabase is the host, seeds live in `supabase/seed.sql` and are applied by `supabase db reset`
locally, or `supabase db push --include-seed` against a non-production branch only.

### 9.9 Never change a remote database directly

**[HIVORR — and official guidance]** Once migrations exist, **all** schema changes go through
migration files. Editing a remote database through the SQL Editor or Table Editor bypasses the
migration history and causes `db push` to fail with sync errors.

The only legitimate exception is a documented, approved break-glass operation during an incident,
followed immediately by a migration that reproduces the change and a `migration repair` that records
it.

### 9.10 Migration history

**[REQUIREMENT — Supabase]** Supabase records applied migrations in
`supabase_migrations.schema_migrations`. `supabase db push --remote` compares the local
`supabase/migrations` directory against that table and applies only what is missing, in order.

Git tracks the **files**. Supabase tracks what was **applied to each database**. They are two systems
and they drift.

| Command | Purpose |
| --- | --- |
| `supabase migration new <name>` | Create an empty, timestamped migration file |
| `supabase migration up` | Apply pending migrations locally |
| `supabase db reset` | Drop and rebuild the local database from migrations + seed |
| `supabase db push --remote` | Apply pending migrations to the linked remote |
| `supabase db pull --remote` | Capture the remote schema as a new migration |
| `supabase migration list --remote` | Show local vs remote divergence |
| `supabase migration repair --status applied\|reverted <ts>` | Correct the **history table only** |

**[REQUIREMENT]** `migration repair` updates the tracking table. It does **not** apply or revert any
SQL. It is used only when you are certain the database state is correct and the record is wrong.

**[HIVORR]** A `migration repair` requires a written explanation in the pull request: what diverged,
why, what proves the database state is correct, and who verified it.

### 9.11 Declarative schemas

**[OPTIONAL]** Supabase supports declarative schemas: SQL files in `supabase/schemas/` describe the
desired state, and migrations are generated by diffing those files against the migration history
with `supabase db schema declarative sync`. The default diff engine is `pg-delta`; `migra` is legacy.

Facts that matter if it is adopted:

- The schema files are the source of truth. Direct changes in Studio, the SQL Editor, or `psql` are
  **invisible** to the diff and are silently dropped.
- DML (`insert`, `update`, `delete`) is never captured. Data changes belong in seed files or
  hand-written migrations.
- Generated migrations can include `GRANT`/`REVOKE` lines you did not write, reflecting default
  privileges. Review them.
- Some object kinds are not tracked (casts, operators, statistics, languages, transforms). They are
  reported as warnings; `--strict-coverage` turns warnings into failures.
- Platform objects in `auth` and `storage` are excluded, except your own customisations on top of
  them.

**[HIVORR]** Declarative schemas are not adopted at MVP. If adopted later, the same review gate
applies: a generated migration is reviewed exactly like a hand-written one, and a human must be able
to explain every line.

### 9.12 Review before execution

**[HIVORR]** No migration is applied to staging or production without review. The review checklist is
§11.4. Review is a gate, not a formality: a reviewer who cannot explain what a statement does has not
reviewed it.

### 9.13 Coordinating code and schema

**[HIVORR]** The expand/contract phases map to releases:

| Release | Schema | Code |
| --- | --- | --- |
| N | Expand: new column, nullable | Writes both old and new |
| N+1 | Backfill complete | Reads new, writes both |
| N+2 | Contract: drop old | Reads and writes new only |

Rules:

- A migration is applied **before** the code that needs it, never after.
- Code never assumes a migration that has not run.
- A migration never assumes code that has not deployed — hence nullable-first and defaulted columns.
- The API contract is versioned (`/v1`); a breaking schema change is a new API version, not a silent
  change.

---

## 10. Environment and deployment

### 10.1 Environments

**[HIVORR]** Four environments, never shared:

| Environment | Database | Data | Purpose |
| --- | --- | --- | --- |
| Local | Containerised Postgres (or `supabase start`) | Synthetic seed | Development, `db reset` |
| CI | Ephemeral container | Synthetic fixtures | Migration + policy tests |
| Staging | Dedicated Supabase project | Synthetic | Pre-production verification |
| Production | Dedicated Supabase project | Real | Live |

Rules:

- **One database per environment.** No schema is shared across environments.
- **No environment reads another environment's database.**
- **Production credentials exist only in production's secret store.**
- **Staging is structurally identical to production.** Same migrations, same extensions, same roles.
  It may differ in data volume and configuration values.

#### 10.1.1 Independent Supabase projects

**[HIVORR]** Staging and production are **separate Supabase projects**, not two branches of one
project and not two schemas in one database.

| Environment | Project reference | Status |
| --- | --- | --- |
| Production | `ahyizcwidkwyowroeqfp` | Verified 7 November 2026 — DNS resolves; REST endpoint returned `401` without a key |
| Staging | *not yet recorded in the repository* | Pending — the founder confirmed a new project exists; its reference must be recorded before provisioning |
| Production (retired) | `fxpcgtetvzlexbptqiwp` | Deleted by the founder; historical only |
| Staging (retired) | `cgxkiczmwzydhoroclvf` | Deleted by the founder; historical only |

A deployment must fail closed unless:

- `BACKEND_ENVIRONMENT` equals `HIVORR_ENV`;
- `SUPABASE_PROJECT_REF` equals the environment's recorded project reference;
- `DATABASE_URL` belongs to that reference;
- `EXPECTED_SUPABASE_PROJECT_REF` matches the selected project;
- staging and production references are different.

`scripts/verify-backend-target.mjs` performs these checks before deployment. It prints the
environment and project reference only; it never prints the connection string.

### 10.2 Credentials and connection

**[HIVORR]**

- Every environment has its own role credentials. No credential is reused.
- The API connects through a pooler with per-process connection limits
  (`ARCHITECTURE.md` §16).
- TLS is required. Certificate verification is on.
- The connection string is an environment variable, validated at boot.
- No credential appears in a migration, a seed, a test fixture, a log, or a screenshot.
- Rotation is possible without a code change.

**[OPTIONAL — Supabase]** If Supabase is the host, use the pooler connection string for the API and
the direct connection for migrations. Migrations need DDL and a session; the transaction pooler does
not support everything a migration needs.

### 10.3 Deployment flow

**[HIVORR]** Adopted from `ARCHITECTURE.md` §15:

```
pull request
  → CI: lint, typecheck, unit tests
  → CI: ephemeral database, apply all migrations from empty, run policy tests
  → review + approval
  → merge to main
  → automatic staging deploy: migrations, then API
  → staging smoke test
  → manual production approval
  → production: migrations, then API
  → post-deploy smoke test
```

Rules:

- Migrations run **before** the new application image.
- Exactly one migration job runs at a time. Concurrent `db push` from two machines can conflict
  because migrations are ordered by timestamp.
- A failed migration aborts the deploy. The previous image stays live.
- The deploy is idempotent: re-running it applies nothing twice.

### 10.4 Branch and preview databases

**[OPTIONAL — Supabase]** Supabase Branching creates isolated environments cloned from a base
project. Preview branches are ephemeral; persistent branches suit staging or QA. New branches are
**data-less by default**, and their schema is built from the migrations in the repository (GitHub
integration) or the base project's migration history (dashboard).

**[HIVORR]** If Branching is used:

- Preview branches never receive production data.
- If data is included, it is anonymised first.
- Auth secrets are placeholders; real values are set per branch.
- A branch is not a substitute for the CI migration test, which runs from empty every time.

### 10.5 Rollback and recovery

**[HIVORR]** Three distinct things, often confused:

| Situation | Action | Data loss |
| --- | --- | --- |
| **Application defect** | Roll back to the previous image | None |
| **Migration defect, not yet deployed** | Revert the file, regenerate, re-apply locally | None |
| **Migration defect, deployed** | Write a **new forward migration** that reverses it | Depends on the change |
| **Data corruption** | Point-in-time recovery to a timestamp | Everything after that timestamp |

Rules:

- **Production rolls forward.** A down migration is written as a new, reviewed migration. It is
  usually destructive; review it as such.
- **`db reset --version` is a local tool only.** Never reset a deployed version.
- **PITR is the recovery mechanism for data**, not for schema. Recovering to a point in time also
  reverts every transaction after it.
- **A rollback drill is run quarterly** (`ARCHITECTURE.md` §16) with a documented RTO.

### 10.6 Backups

**[REQUIREMENT — Supabase]** Automatic daily backups exist on Pro, Team, and Enterprise plans, with
7, 14, and 30 days of retention respectively. Free-tier projects have no automatic backups and must
export with `supabase db dump` and store off-site. PITR is an add-on, requires at least a Small
compute add-on, and targets a recovery point objective of about two minutes.

**Two limitations that change the plan:**

- **[REQUIREMENT]** Database backups do **not** include objects stored through the Storage API. The
  database holds metadata only. A restore does not bring back deleted files.
- **[REQUIREMENT]** Daily backups do not store passwords for custom roles. After a restore, custom
  role passwords must be reset.

**[HIVORR]** `ARCHITECTURE.md` §16 requires PITR (7–30 days) **plus** daily logical dumps to a
separate bucket, plus a quarterly restore drill. This is stricter than the platform default and
therefore constrains the plan choice:

- Free tier is insufficient.
- A plan without PITR is insufficient for production.
- Object storage backup is a **separate** process (R2 lifecycle + versioning), because database
  backups do not cover it.
- A restore drill that has never been run is not a backup strategy.

### 10.7 Drift

**[HIVORR]** Drift is any difference between the migrations and a live database. It is never
intentional.

Detection:

- CI builds a database from migrations and diffs it against a schema dump of staging.
- A DDL audit trigger logs every `create`, `alter`, and `drop` with the role and timestamp.
- A scheduled job compares the migration history table against the repository.
- Any drift finding is an incident, not a cleanup task.

Prevention:

- The SQL Editor and Table Editor are disabled for anyone who is not performing a documented
  break-glass operation.
- Dashboard access is restricted to the smallest possible group.
- Every break-glass change is followed by a migration within the same working day.

---

## 11. Testing and security review

### 11.1 Migration tests

**[HIVORR]** Every migration pipeline runs, from an empty database:

1. Apply all migrations in order. Any error fails the build.
2. Apply them again. Nothing is applied twice; no error.
3. Run the seed. It succeeds on a clean database.
4. Run the full policy test suite.
5. Diff the resulting schema against the expected schema.
6. Run the application's integration tests against the migrated database.

### 11.2 RLS policy tests

**[RECOMMENDATION — Supabase]** The official pattern is a pgTAP file per table under
`supabase/tests/`, created with `supabase test new <table>_rls` and run with `supabase test db`.

**[HIVORR]** The same discipline applies regardless of host: one test file per table, asserting
**allow and deny** for every operation, for every role.

What a test must cover:

| Case | Assertion |
| --- | --- |
| Owner reads own row | Row returned |
| Owner writes own row | Row changed, verified with `returning` |
| Other account reads owner's row | Empty result |
| Other account updates owner's row | No rows affected **and** the target row is intact |
| Other account inserts a row owned by someone else | `42501` |
| `anon` (or the unauthenticated path) | Denied |
| Missing grant | `42501`, not an empty result |
| Admin in scope | Allowed |
| Admin out of scope | Denied |

**[RECOMMENDATION]** Match the assertion to how the request is denied. Only two of the three raise an
error:

| Denied by | Postgres | Assert with |
| --- | --- | --- |
| Missing grant | `42501` | `throws_ok` |
| `with check` violation | `42501` | `throws_ok` |
| `using` filtering the row out | No error, zero rows | `is_empty` over a statement with `returning`, then a read proving the row is intact |

**Never prove an allowed write with `lives_ok`.** It passes when the write matched zero rows. Add
`returning` and assert the returned value.

**[HIVORR]** A table without a policy test is not migrated.

### 11.3 Access matrix tests

**[HIVORR]** Beyond RLS, the service layer is tested against the permission matrix. For every
capability, assert:

- Account A, activity active, verification `APPROVED` → allowed.
- Account A, activity **inactive** → denied with `AUTHZ_ACTIVITY_INACTIVE`.
- Account A, activity active, verification `SUBMITTED` → denied with `AUTHZ_VERIFICATION_REQUIRED`.
- Account A, verification `REJECTED` → denied with a distinguishable code.
- Account B attempting the same on A's record → not found (preferred over forbidden).
- Admin with the scope → allowed.
- Admin without the scope → denied.
- Suspended account → denied at every layer.

The question the suite answers is not "does the happy path work" but **"can I reach something I
should not"**.

### 11.4 Security review checklist

**[HIVORR]** Every migration is reviewed against this list before it is applied anywhere beyond
local.

**Exposure**

- [ ] Is the table in an exposed schema? If yes, is that intentional and recorded?
- [ ] Is the Data API disabled, or is this table deliberately part of a surface (§3.3)?
- [ ] Is a view involved? Is it `security_invoker`, or unreachable?
- [ ] Is a `security definer` function involved? Is it in a private schema?

**Grants**

- [ ] Is every grant explicit, and the minimum?
- [ ] Does `anon` hold anything? Why?
- [ ] Does `authenticated` hold anything? Why?
- [ ] Does `service_role` hold anything? Why?
- [ ] Is `truncate` granted to anyone who does not need it?
- [ ] Is `execute` on a new function revoked from `PUBLIC`?

**RLS**

- [ ] Is RLS enabled?
- [ ] Is there one policy per operation?
- [ ] Does every policy name its role with `to`?
- [ ] Does every `update` policy have a matching `select` policy?
- [ ] Does every policy handle the unset/NULL identity case?
- [ ] Is every policy filter column indexed as a leading column?
- [ ] Are policies free of recursion?
- [ ] Does `force row level security` apply, given the owner?

**Data**

- [ ] Does the table hold personal, identity, financial, or verification data?
- [ ] Is that data in a private bucket / private schema / private column?
- [ ] Is `owner_account_id` present and indexed?
- [ ] Are party columns present for transaction rows?
- [ ] Does any policy expose one activity's data to another activity?
- [ ] Does any response path return more than the caller needs?

**Operations**

- [ ] Is the migration self-contained (§9.4)?
- [ ] Is it forward-only, or does it have a documented destructive path?
- [ ] Does `db reset` from empty succeed?
- [ ] Do the policy tests pass, allow and deny?
- [ ] Is the change coordinated with the code release (§9.13)?
- [ ] Is there a rollback plan that does not lose data?

### 11.5 Advisors and automated checks

**[OPTIONAL]** Supabase's Security Advisor flags common problems with the built-in roles, RLS, and
function search paths. **[HIVORR]** Treat every finding as a finding: fix it or record why it is a
false positive. Do not dismiss in bulk.

**[HIVORR]** CI additionally checks:

- No table in a module schema has RLS disabled.
- No `security definer` function exists outside `private`.
- No function has `execute` granted to `PUBLIC`.
- No migration contains `grant all`.
- No migration contains a credential, a connection string, or a key.
- No `drop table` or `drop column` without a `-- destructive:` marker and a second reviewer.

### 11.6 Release gate

**[HIVORR]** A database change reaches production only when all of the following are true:

1. It is a reviewed, committed migration.
2. It applies cleanly to an empty database.
3. `db reset` succeeds.
4. Policy tests pass, allow and deny.
5. Access matrix tests pass.
6. The security checklist is complete.
7. Staging applied it and the application behaved correctly.
8. The rollback plan is written.
9. A second reviewer approved it.

Any missing item is a stop, not a note.

---

## 12. Hivorr database governance

### 12.1 One account, six activities

**[HIVORR]** The database supports **one unified identity** with **six activities**. It does not
support six databases, six auth systems, or six account tables.

| Activity | Capability namespace | Derived dashboard |
| --- | --- | --- |
| Buy — Local Market | `market.buy` | Buyer |
| Hire — Client | `services.hire` | Client |
| Errand — Requester | `errands.request` | Errand requester |
| Sell — Seller | `market.sell` | Seller |
| Offer services — Professional | `services.offer` | Professional |
| Provide logistics | `logistics.provide` | Logistics provider |

**Forbidden, permanently:**

- An `account_type` column.
- A `both` value anywhere.
- A per-activity user table, credential table, or wallet.
- A separate authentication system per activity.
- A role chosen at registration.

Activities are **rows** - an activation record per account per activity - not columns and not types.
`discover` is not an activity; it is the browse step inside Hire (permission matrix §4.2). It is not
modelled as an activation.

### 12.2 Schema ownership

**[HIVORR]** Each module owns one schema and no module reads another's tables.

| Schema | Owns |
| --- | --- |
| `identity` | accounts, users, credentials, sessions, devices, memberships, MFA |
| `profile` | profiles, activity activation, verification cases, documents, KYC tiers |
| `market` | stores, products, taxonomy bindings, carts, orders, fulfilments |
| `services` | jobs, applications, engagements, milestones, deliverables |
| `errands` | errand requests, offers, assignment, task status |
| `logistics` | dispatch pool, assignments, delivery legs, tracking events, proof of delivery |
| `finance` | ledger accounts, journal entries, escrow, payouts, limits, reconciliation |
| `messaging` | threads, messages, attachments, notifications, delivery attempts |
| `admin` | admin roles, review queues, moderation, configuration, audit access, disputes |
| `platform` | taxonomy registry, feature flags, media, search, audit log, reference numbers |

Rules:

- A foreign key across schemas is allowed only to an **identifier** owned by the other module, and
  only where the dependency is acyclic.
- A cross-module read uses a public interface call or an explicit read model, never a join into
  another schema's tables.
- A migration touches one schema. A migration that touches two is a design smell and needs a reason.

### 12.3 The identity spine

**[HIVORR]** Four tables carry identity, and they are the only place identity lives:

| Table | Holds | Shared by |
| --- | --- | --- |
| `identity.account` | the legal/billing entity, wallet owner | everything |
| `identity.user` | a credential holder that signs in | one account at MVP |
| `identity.membership` | user ↔ account with a role | future teams |
| `profile.account_profile` | display name, avatar, contact, locale, timezone | every activity |

Rules:

- **Identity is collected once.** A verified user is never asked to resubmit identity for another
  activity.
- **Identity approval never approves an activity lane** (matrix §7.2).
- Personal identity fields are never projected publicly. The legal name is not the display name.
- Government ID numbers, dates of birth, and document images never appear in a public projection or a
  public bucket.

### 12.4 Activity activation

**[HIVORR]**

```
profile.activity_activation
├── account_id        (fk identity.account)
├── activity          (enum: market.buy, services.hire, errands.request,
│                             market.sell, services.offer, logistics.provide)
├── state             (inactive | active | restricted | suspended)
├── activated_at
├── suspended_at
└── unique (account_id, activity)
```

Rules:

- Activation is a row. Adding an activity is an insert, not a schema change.
- A new activity adds a namespace, not a table per activity.
- Deactivating an activity hides its dashboard and revokes its capabilities. It does not delete
  history (`ARCHITECTURE.md` §7.3; matrix §15.3).
- Removing an activity from the product is `deactivate`, not `drop`.
- The unique constraint prevents duplicate activations.

### 12.5 Verification

**[HIVORR]** Six lanes, each a row, each with its own state machine. They never collapse into one
status.

```
profile.verification_case
├── account_id
├── lane              (identity | kyc | trade | seller | logistics | business)
├── state             (NOT_STARTED | DRAFT | SUBMITTED | UNDER_REVIEW |
│                      APPROVED | REJECTED | EXPIRED)
├── reason_code       (required when REJECTED)
├── decided_by        (admin user id)
├── decided_at
└── evidence_ref      (pointer to private storage; never the document itself)
```

Rules:

- At most one **active** submission per lane per account. Enforced by a partial unique index.
- Decisions are made only through admin review. No user action and no automated job sets `APPROVED`.
- KYC tier is account-level, in its own table, never a column on the account that varies by activity.
- Evidence lives in private storage. The database holds a reference, never the document.
- Identity fields are frozen while a case is `UNDER_REVIEW`.
- A `REJECTED` decision carries a machine-readable reason and a human explanation.
- Verification state is **read** by the service layer to compute capabilities. It is not encoded in
  a token the client can forge.

### 12.6 Capabilities

**[HIVORR]** Capabilities are **computed**, never stored as authority.

```
capabilities = f(account, activated activities, verification states, KYC tier, admin role)
```

Database consequences:

- There is no `capabilities` column on the account.
- There is no `role` column that the client can influence.
- Derived roles (Buyer, Seller, Client, Professional, Logistics provider) are computed, not stored.
- An admin role is a separate grant table, never an activity.
- The audit log records the computed decision for privileged actions.

### 12.7 Ownership and parties

**[HIVORR]** Every user-owned row carries `owner_account_id`. Every transaction row carries its
parties.

| Row type | Columns |
| --- | --- |
| User-owned (profile, listing, errand request) | `owner_account_id` |
| Market order | `buyer_account_id`, `seller_account_id` |
| Service engagement | `client_account_id`, `professional_account_id` |
| Errand | `requester_account_id`, `provider_account_id` (null until assigned) |
| Delivery | `provider_account_id`, `requester_account_id` |
| Ledger entry | `account_id`, plus the journal entry it belongs to |
| Message thread | participants table, not a column |

Rules:

- Every party column is indexed as a leading column.
- Access control never depends on identifier unguessability, even though identifiers are UUIDv7.
- "Not found" is preferred over "forbidden" for a record the caller does not own. It does not confirm
  existence.
- No endpoint returns "all" of anything outside a scoped admin read model.

### 12.8 Activity boundaries

**[HIVORR]** The permission matrix forbids cross-activity reuse of **eligibility**, while requiring
reuse of **identity**. The database enforces the data boundary:

| Data | Readable by | Never readable by |
| --- | --- | --- |
| Buyer's order history | buyer, seller of that order, scoped admin | another buyer, a professional, a logistics provider |
| Seller's store and products | public projection, seller, scoped admin | a buyer's private data, a professional |
| Professional's applications | professional, the client of that job, scoped admin | a seller, a logistics provider |
| Errand requester's address and phone | requester, the assigned provider, scoped admin | any other provider, any seller |
| Logistics proof of delivery | provider, requester, scoped admin | any other party |
| KYC evidence | the account, scoped verification admin | every other role, including other admins |
| Wallet and ledger | the account, scoped finance admin | every other account |
| Chat thread | its participants, scoped admin for dispute | any non-participant |

Rules:

- A policy or service check that returns another activity's rows is a defect, even if the accounts
  are the same person. Activities are capabilities, and each capability has its own data boundary.
- A single account holding all six activities does **not** merge their data. The buyer view does not
  show the seller's margin.
- Admin reads are scoped, logged, and never bulk.

### 12.9 Financial records

**[HIVORR]** From `ARCHITECTURE.md` §11:

- A **double-entry ledger** is the source of truth. There is no mutable `balance` column.
- Money is `numeric(20, 4)` plus an explicit currency code. Never floating point.
- Journal entries are append-only. Corrections are reversing entries, never updates.
- Every money mutation is idempotent, keyed by an `Idempotency-Key`.
- Escrow states are an explicit enum with legal transitions enforced in the domain layer and by a
  check constraint.
- Reconciliation compares the ledger against provider settlement; a mismatch is an incident.
- Financial and audit records are never deleted, and no migration may drop them.
- `tier_0` has zero financial limits. Tier gating is a service-layer decision, not a policy.
- Payout destinations are bound and pre-verified; bank details are private, encrypted at rest, and
  never projected.

### 12.10 Messaging and notifications

**[HIVORR]**

- One inbox, one thread table, participants in a join table.
- A thread is scoped to a context (order, job, errand, delivery). It does not float free.
- A non-participant cannot read a thread, not even an admin outside a dispute scope.
- Attachments are references to private storage, never inline blobs.
- Notifications are a separate feed, derived from events, with delivery attempts recorded.
- Message content is never included in an analytics read model.

### 12.11 Logistics and physical service data

**[HIVORR]**

- A delivery leg has a provider, a requester, a status enum, and tracking events.
- Tracking events are append-only and timestamped in UTC.
- Proof of delivery is a private object reference plus a captured timestamp and location accuracy, not
  a public URL.
- The requester's address and phone are visible to the assigned provider **only after assignment**,
  and the grant is revoked on completion or cancellation.
- Vehicle and logistics evidence is a verification lane, not a public profile field.
- A provider cannot see another provider's assignments, even in the same dispatch pool.

### 12.12 Administrative access

**[HIVORR]** From the permission matrix §14:

- Admin is a scoped grant table, never an activity, never an account type.
- Scopes: `verification.review`, `payment.review`, `dispute.resolve`, `account.manage`,
  `configuration.write`, `audit.read`.
- High-risk actions require dual control and an immutable audit record.
- An admin may hold no activities and still act within scope.
- An admin may hold all six activities and gain nothing extra inside them.
- Every admin read of a private document is logged individually.
- No admin may modify or suspend their own account.

### 12.13 Audit

**[HIVORR]** Append-only, written in the same transaction as the change:

```
actor_id, actor_type, action, target_type, target_id,
before_summary, after_summary, ip, user_agent, correlation_id, created_at
```

Audited without exception: verification decisions, activity suspension, account suspension, admin
role grants, financial mutations, business approval, and every admin read of a private document.

The audit table is never updated and never deleted from. It is not exposed to any client role.

### 12.14 Public vs private projections

**[HIVORR]** Public data is a **projection**, never a join onto private tables.

| Public | Private |
| --- | --- |
| display name, avatar, rating, completed count | legal name, date of birth, ID number |
| store name, description, categories | ID images, liveness captures |
| professional headline, skills, portfolio, rate | address, phone, email unless published |
| verification badge (a boolean) | the evidence behind the badge |
| service area, vehicle type | bank details, payout accounts |
| public listings | chat contents, dispute records |

Rules:

- A projection is a view or a dedicated read model. It is `security_invoker` or unreachable.
- A badge says *that* a lane is approved, never *what* was submitted.
- No private column is ever selected by a public query path, even if the response discards it.

### 12.15 Future expansion

**[HIVORR]** The schema must absorb growth without duplication:

| Change | Mechanism |
| --- | --- |
| New activity | Insert an activation row; add a capability namespace |
| New verification lane | Insert a lane row; no new column |
| New admin scope | Insert a grant row |
| New payment provider | New adapter + provider reference column, not a new ledger |
| New currency | New currency code + ledger account; no new table |
| New module | New schema + module boundary; no cross-schema join |
| Mobile client | Same API, bearer token; no second identity store |

**Forbidden as a growth strategy:** a database per activity, an auth system per activity, a wallet per
activity, a table per activity that duplicates an existing one, or a `type` column that turns into a
second schema.

### 12.16 What is forbidden

**[HIVORR]** These are defects, not style preferences:

1. `account_type`, `role_type`, or any column that encodes an account as a mode.
2. A `both` value.
3. A per-activity user, credential, session, or wallet table.
4. A second authentication system.
5. A table that duplicates an existing one because "this activity needs its own".
6. A cross-schema foreign key that creates a cycle.
7. A migration that drops a financial or audit record.
8. A public bucket holding identity or financial evidence.
9. A `security definer` function outside `private`.
10. A policy that returns another activity's rows.
11. A `grant all`.
12. A migration that relies on a platform default for security.
13. A capability stored as authority in a client-visible field.
14. A production schema change made outside a migration.

---

## 13. Open decisions

Nothing here may be implemented as though it were decided. Position A (§2.4) is **not** in this
list - it was decided on 3 November 2026. Eleven decisions remain open; rows 4 and 5 are marked
**DECIDED** and are kept in place so that cross-references to them stay valid.

This is not the consolidated register. `ARCHITECTURE.md` §16.4 is the single list that combines
this section, the matrix §18 and the engineering standards §16. Record a decision there first.

| # | Decision | Blocks | Owner |
| --- | --- | --- | --- |
| 1 | **Managed Postgres provider** — Neon, Supabase, or RDS | §4–§8 applicability; migration tooling | Founder + architect |
| 2 | **Role names and separation** — is `hivorr_worker` distinct from `hivorr_api`? (§6.9) | First migration | Architect |
| 3 | **RLS identity detail** — the setting name and whether it carries one account or a full actor context (§6.4) | Every tenant policy | Architect |
| 4 | **`discover`** - **DECIDED 3 November 2026:** a capability inside Hire, not an activity (permission matrix §4.2). | Nothing - settled | Founder |
| 5 | **Errand vs logistics** - **DECIDED 3 November 2026:** two separate activities on one shared request pool (`ARCHITECTURE.md` §16.5 #2). | Nothing - settled | Founder |
| 6 | **MVP activity scope** — all six at launch or Explore-first | Which schemas ship first | Founder |
| 7 | **KYC tier ladder and limits** | Financial gating; `finance` constraints | Founder |
| 8 | **Retention periods** — identity, KYC, chat, disputes | Deletion design; no purge may be built | Founder + counsel |
| 9 | **Currency model** — single currency or multi-currency ledger | `finance` schema; wallet presentation | Founder |
| 10 | **Data residency and primary region** | Provider and region choice; latency and compliance | Founder |
| 11 | **Verification vendor** — build review queue only, or integrate an identity provider | `profile` evidence model | Founder |
| 12 | **Business as account or profile** | `identity.account` cardinality; team features | Founder |
| 13 | **Backup plan tier** — PITR retention length and logical dump destination | Production readiness | Founder + architect |

---

## 14. Official references

All links checked **3 November 2026**. Supabase documentation is versioned continuously; a rule in
this document is only as current as this date.

| # | Title | Link | Checked | Relevant policy date |
| --- | --- | --- | --- | --- |
| 1 | Breaking Change: Tables not exposed to Data and GraphQL API automatically (changelog 45329) | https://supabase.com/changelog/45329-breaking-change-tables-not-exposed-to-data-and-graphql-api-automatically | 3 Nov 2026 | Published 28 Apr 2026; enforced on existing projects 30 Oct 2026 |
| 2 | Securing your API | https://supabase.com/docs/guides/api/securing-your-api | 3 Nov 2026 | Current |
| 3 | Row Level Security | https://supabase.com/docs/guides/database/postgres/row-level-security | 3 Nov 2026 | Current |
| 4 | Database functions | https://supabase.com/docs/guides/database/functions | 3 Nov 2026 | Current |
| 5 | API keys | https://supabase.com/docs/guides/getting-started/api-keys | 3 Nov 2026 | `anon` / `service_role` deprecated by end of 2026 |
| 6 | Deploy database migrations | https://supabase.com/docs/guides/deployment/database-migrations | 3 Nov 2026 | Current |
| 7 | Declarative database schemas | https://supabase.com/docs/guides/local-development/declarative-database-schemas | 3 Nov 2026 | `pg-delta` default; `migra` legacy |
| 8 | Using Custom Schemas | https://supabase.com/docs/guides/api/using-custom-schemas | 3 Nov 2026 | Current |
| 9 | Postgres Roles | https://supabase.com/docs/guides/database/postgres/roles | 3 Nov 2026 | Current |
| 10 | Storage Access Control | https://supabase.com/docs/guides/storage/security/access-control | 3 Nov 2026 | Current |
| 11 | Database Backups | https://supabase.com/docs/guides/platform/backups | 3 Nov 2026 | Current |
| 12 | Branching | https://supabase.com/docs/guides/deployment/branching | 3 Nov 2026 | Current |
| 13 | Data REST API | https://supabase.com/docs/guides/api | 3 Nov 2026 | Current |
| 14 | Database API 42501 errors | https://supabase.com/kb/troubleshooting/database-api-42501-errors | 3 Nov 2026 | Current |

Postgres semantics referenced above (grants, `security definer`, `force row level security`, `btree`
leading columns) are documented in the official PostgreSQL manual, which Supabase's own guides cite.
They are not restated here.

**Not used as sources:** tutorials, blog posts, forum answers, AI-generated summaries, or any
material that predates the 2026 exposure change without saying so.

---

## 15. Changelog

### 3 November 2026 — full revision

**Reframed**

- The document no longer assumes the Supabase Data API is Hivorr's data path. §2 states the conflict
  with `ARCHITECTURE.md` explicitly and records its resolution.
- Added a four-way classification for every rule (requirement / recommendation / optional / Hivorr)
  so a recommendation is never presented as mandatory.
- Added the provider question: Supabase-specific sections bind only if Supabase is chosen.

**Corrected**

- **The October 2026 change.** The previous version described it as future ("starting October 30,
  2026"). It is in force. Added the full timeline: opt-in 28 Apr 2026, GraphQL default off 18 May
  2026, new-project default 30 May 2026, all existing projects 30 Oct 2026.
- **Existing tables.** Clarified that grants are not retroactively removed, and that the change does
  not affect direct Postgres connections.
- **`service_role`.** Added that it has `BYPASSRLS`, that RLS never applies to it, and that a secret
  key bypasses RLS only when no user access token is present.
- **API keys.** Added the publishable/secret key model, the end-2026 deprecation of `anon` and
  `service_role`, and the `apikey` header rule (they are not JWTs).
- **Default privileges.** Added that tables also receive `truncate`, `references`, `trigger`, and
  `maintain`, and that functions receive `execute` through a **global** `PUBLIC` default.
- **Views.** Added that views bypass RLS by default and require `security_invoker = true`.
- **`auth.uid()`.** Added its `NULL` behaviour and the `is not null` requirement — and, for Hivorr,
  the fact that it is unavailable entirely.
- **Update policies.** Added that an `UPDATE` needs a matching `SELECT` policy.

**Added**

- §3 Data API posture: disabled by default, with conditions for any future surface.
- §4.7 pre-request checks and their limitation to the Data API.
- §5.7 views, §5.8 the direct-connection equivalent of grant + RLS.
- §6.4 the RLS identity mechanism for a direct connection (`set local`, not `set`).
- §6.5 `force row level security` and the owner-bypass problem.
- §6.6 index requirements for policy filter columns.
- §6.7 recursive policy failure (`42P17`) and the `security definer` break.
- §6.9 a proposed five-role privilege matrix.
- §7.2 `search_path = ''` hardening, §7.3 the `execute`-grant-versus-rows distinction.
- §9.5 expand/contract in full, §9.6 destructive-change gate, §9.7 backfill rules.
- §9.10 migration history, `migration repair`, and the repair discipline.
- §9.11 declarative schemas and `pg-delta`.
- §9.13 code/schema release coordination.
- §10.6 backups, including that Storage objects are **not** in a database backup and custom role
  passwords are not stored.
- §11.2 the allow/deny assertion table and the `lives_ok` trap.
- §11.3 access matrix tests, §11.4 the security review checklist, §11.6 the release gate.
- §12 the full Hivorr governance layer: one account/six activities, schema ownership, identity spine,
  activation, verification, capabilities, ownership, activity boundaries, finance, messaging,
  logistics, admin, audit, projections, expansion, and the forbidden list.
- §13 open decisions, now thirteen after Position A was removed from the list.

**Retired**

- The implicit assumption that `anon` and `authenticated` are Hivorr's primary database roles.
- RPC as a first-class API surface (§7.5 now limits functions to three narrow purposes).
- "Enable RLS" as a complete security answer. Grants, roles, keys, function privileges, and exposure
  are now reviewed together (§11.4).
- The unqualified instruction to copy the official custom-schema `GRANT ALL` setup snippet (§4.6).

**Defects in the previous version**

- The SQL block in §5 was never closed, so sections 6–24 rendered as code in most Markdown viewers.
- Section 6 was missing; numbering jumped from 5 to 7.
- Section 3's date was correct but its tense was not, and it omitted the effect on direct connections.
- The document had no classification of requirements versus recommendations.

**Decided**

- **Position A adopted — 3 November 2026.** Supabase, if chosen, is managed Postgres only: Data API
  and GraphQL disabled, Supabase Auth not used, no Supabase key in any client, direct connection
  with a least-privilege role, RLS as defence in depth via a transaction-scoped session variable,
  Storage on Cloudflare R2. Recorded in §2.4; consequences in §2.3, §3.2, §6.4.
- **Position B rejected.** The Data-API-first path would require rewriting `ARCHITECTURE.md` §5, §8,
  §9, §10 and the permission matrix §11. It is documented as a counterfactual, not as an option.

**Approved**

- Approved **3 November 2026**. Approval covers the rules in this document and the Position A
  decision above. It does **not** resolve the thirteen decisions in §13; those remain open and must
  be recorded separately before implementation.

---

## 16. Engineering principle

> **Secure by default. Explicit permissions. Reproducible migrations. Least privilege.
> RLS by design, authorisation in the service layer. Exposure must be intentional.
> No rule depends on an undocumented platform default.**

The database must remain secure, consistent, auditable, reproducible, scalable, maintainable, and
environment-consistent — and it must remain **one** database for **one** identity with **six**
activities, never six databases pretending to be one platform.

---

## Appendix A — Classification of the previous document

| Previous section | Verdict | Where it lives now |
| --- | --- | --- |
| 1 Purpose | **Retained, expanded** | §1 |
| 2 Migration-first rule | **Retained** | §9.1 |
| 3 Data API explicit grant rule | **Corrected** — wrong tense, incomplete scope | §4.1, §4.2 |
| 4 GRANT and RLS are separate | **Retained, strengthened** | §5.1 |
| 5 Least-privilege grant rule | **Retained** — fixed the broken code fence | §5.2 |
| 6 *(missing)* | **Gap** | §5.3, §5.4 |
| 7 Functions and RPCs | **Corrected** — RPC is not a Hivorr API surface | §7 |
| 8 Row Level Security | **Corrected** — `auth.uid()` unavailable; RLS is defence in depth | §6 |
| 9 Sensitive data | **Retained, expanded** | §12.8, §12.14 |
| 10 Storage security | **Retained, conditional** — Hivorr uses R2 | §8 |
| 11 Migration self-containment | **Retained, expanded** | §9.4 |
| 12 Local reset requirement | **Retained** | §10.1, §11.1 |
| 13 Local/staging/production consistency | **Retained** | §10.1 |
| 14 October 30 rule | **Corrected and merged** — already in force | §4.1, §4.2 |
| 15 Do not blindly grant `anon` | **Retained, strengthened** — no `anon` grants at all | §5.4 |
| 16 Do not use GRANT as a workaround | **Retained** | §5.3 |
| 17 Database permission review | **Retained, expanded into a checklist** | §11.4 |
| 18 Migration testing | **Retained, expanded** | §11.1–§11.3 |
| 19 Production deployment rule | **Retained, formalised as a gate** | §11.6 |
| 20 Existing tables | **Retained** | §4.5 |
| 21 Future migration standard | **Retained** | §9.4, §9.13 |
| 22 AI coding agent rule | **Retained in spirit** — inspect, reuse, extend, then create | §12.15, §12.16 |
| 23 Migration review checklist | **Retained, expanded** | §11.4 |
| 24 Engineering principle | **Retained, extended** | §16 |

---

*End of document.*
