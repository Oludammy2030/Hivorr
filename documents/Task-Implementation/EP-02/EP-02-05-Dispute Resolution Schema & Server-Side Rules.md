# Task Implementation Plan — EP-02-05: Dispute Resolution Schema & Server-Side Rules

---

## 1. Task Objective

Design and implement the complete server-side dispute resolution database schema and enforcement layer that provides the structured dispute resolution framework protecting both parties in marketplace transactions. Deliverables:

- **4 new tables**: `dispute_cases`, `dispute_evidence`, `dispute_resolutions`, `dispute_audit_trail`
- **2 internal helper functions** (`dispute_place_escrow_hold`, `dispute_release_escrow_hold`) — narrowly-scoped SECURITY DEFINER functions that atomically manage the escrow hold lifecycle
- **6 RPCs** covering dispute filing (with automatic escrow hold), evidence submission, resolution (with escrow release/refund integration), withdrawal, case retrieval, and case listing
- **Full RLS** (default-deny) on all 4 tables
- **Escrow-dispute integration** — filing a dispute transitions linked escrow to `disputed`; resolution transitions it back to `released` or `refunded` with atomic balance movements
- **2 pgTAP test files**: `015_dispute_schema_posture.sql`, `016_dispute_rpc_enforcement.sql`
- **Zero modifications** to any EP-01, EP-02-01, EP-02-02, EP-02-03, or EP-02-04 table or function
- **Zero dispute logic accessible to the client** — all state transitions, escrow holds, and financial adjustments execute via PostgreSQL RPC + RLS

---

## 2. Business Problem Being Solved

EP-02-04 established the financial engine (balances, escrow, payouts, deposits), but **no dispute resolution infrastructure exists** to protect parties when transactions go wrong:

- No dispute filing mechanism — entities have no structured way to raise a formal dispute against a transaction or escrow
- No evidence collection — there is no system for either party to submit documents, descriptions, or screenshots as evidence
- No resolution workflow — admins have no structured process for reviewing disputes and issuing binding decisions
- No escrow-dispute integration — the `financial_escrow` table already reserves the `disputed` status (EP-02-04 §5.4 state machine, line 207), but no mechanism exists to transition escrow into or out of that state
- No dispute audit trail — no immutable record of dispute state changes, evidence submissions, or resolution decisions
- No financial adjustment enforcement — when a dispute is resolved, there is no atomic mechanism to release funds to the payee, refund the payer, or split the amount
- No dispute hold protection — disputed escrow could theoretically be released through other paths before the dispute is resolved (the `financial_escrow_release` RPC already blocks `disputed` status at line 923, but no mechanism places the hold)

This task completes the **financial safety net** for the platform. Without it, marketplace transactions (EP-03+) have no recourse when services are unsatisfactory, goods are defective, or parties disagree on milestone completion.

---

## 3. Scope

| In Scope | Detail |
|---|---|
| `dispute_cases` table | Dispute case with type, status, parties, linked escrow, filing metadata |
| `dispute_evidence` table | Evidence submissions by either party (text, documents, screenshots) |
| `dispute_resolutions` table | Resolution decisions with outcome, reasoning, financial adjustments |
| `dispute_audit_trail` table | Immutable dispute case history log |
| Helper: `dispute_place_escrow_hold` | SECURITY DEFINER; transitions escrow `funded`/`partially_released` → `disputed` |
| Helper: `dispute_release_escrow_hold` | SECURITY DEFINER; transitions escrow `disputed` → `funded` |
| RPC: `dispute_file` | File a dispute linked to an escrow; places automatic escrow hold |
| RPC: `dispute_submit_evidence` | Submit evidence for an open/under-review dispute |
| RPC: `dispute_resolve` | Resolve a dispute with financial outcome (release/refund/split/dismiss) |
| RPC: `dispute_withdraw` | Withdraw a dispute before resolution; releases escrow hold |
| RPC: `dispute_get` | Retrieve a dispute case with evidence and resolution |
| RPC: `dispute_list` | List disputes for the authenticated entity (as filer or counterparty) |
| RLS + grants | Default-deny on all 4 tables; narrow grants per table |
| pgTAP posture test | `015_dispute_schema_posture.sql` |
| pgTAP enforcement test | `016_dispute_rpc_enforcement.sql` |

## 4. Out of Scope

| Out of Scope | Reason |
|---|---|
| Client-side dispute UI / data layer | EP-02-17 (Dispute Resolution Framework — client-side) |
| Admin dispute review interface | EP-02-17 or future admin tooling |
| Edge Function for dispute notifications | Future task |
| Modification of any EP-01 / EP-02-01/02/03/04 table or function | Finalized in prior tasks; this task references them, does not alter them |
| Modification of `financial_escrow_release` or `financial_escrow_refund` RPCs | Dispute resolution performs escrow transitions inline (service_role context) |
| Modification of `financial_transactions.transaction_type` CHECK constraint | Reuses existing `escrow_release` and `escrow_refund` types |
| Modification of `financial_audit_trail.subject_type` CHECK constraint | Uses separate `dispute_audit_trail` for dispute-specific events |
| Any client-side Dart/Flutter code | Server-side only task |
| Appeal or escalation workflow | Future task |
| Automated dispute resolution (AI-driven) | Future task |
| Dispute SLA timers or auto-escalation | Future task |

---

## 5. Recommended Technical Approach

### 5.1 Single SQL Migration

Create one migration file:
```
supabase/migrations/<YYYYMMDD><HHMMSS>_dispute_resolution_schema.sql
```

The migration contains, in order: (1) 4 dispute table DDLs with constraints, indexes, triggers, comments; (2) RLS enablement, revokes, and grants per table; (3) 2 SECURITY DEFINER helper function definitions; (4) 6 RPC function definitions; (5) EXECUTE grants; (6) `comment on function` documentation; (7) Realtime exclusion. **No changes to any prior table or function.**

### 5.2 Execution Model: SECURITY INVOKER (RPCs) + SECURITY DEFINER (Helpers)

**6 RPCs** are `SECURITY INVOKER` — RLS applies inside the function body. Consistent with all prior EP-02 tasks (EP-02-02, EP-02-03, EP-02-04 all use SECURITY INVOKER exclusively).

**2 helper functions** are `SECURITY DEFINER` — required because `authenticated` has no UPDATE grant on `financial_escrow` (EP-02-04 security posture, line 534-535: only SELECT for authenticated, SELECT+INSERT+UPDATE for service_role). The helpers are:
- Narrowly scoped (single-purpose: place or release escrow hold)
- Named with `dispute_` prefix (not `financial_` — does not conflict with `013` posture assertion which asserts `count(*) WHERE proname LIKE 'financial_%' AND prosecdef = 0`)
- Pinned `search_path = pg_catalog, public` (SECURITY DEFINER best practice)
- Validate caller is a party to the escrow before transitioning state
- Write to `dispute_audit_trail` for full traceability

**Authorization model:**
- **Entity-facing RPCs** (`dispute_file`, `dispute_submit_evidence`, `dispute_withdraw`, `dispute_get`, `dispute_list`): EXECUTE granted to `authenticated` + `service_role`. They enforce `platform_is_authenticated()` and self-scope to party membership.
- **Admin/system RPC** (`dispute_resolve`): EXECUTE granted to `service_role` only. Resolution is an admin decision executed server-side.

### 5.3 Dispute State Machine

```
open → under_review → resolved
  ↓                      ↓
withdrawn              closed
```

| State | Meaning | Escrow Effect |
|---|---|---|
| `open` | Dispute filed, escrow hold placed | Escrow → `disputed` |
| `under_review` | Admin has begun reviewing evidence | No change (escrow remains `disputed`) |
| `resolved` | Admin has issued a binding decision | Escrow → `released`/`refunded` per outcome |
| `closed` | Resolution finalized, no further action | Terminal state |
| `withdrawn` | Filer withdrew before resolution | Escrow → `funded` (hold released) |

State transitions are enforced server-side — invalid transitions raise PLT005.

### 5.4 Escrow-Dispute Integration Architecture

**Critical design decision:** The existing `financial_escrow_release` (line 923) only accepts `funded`/`partially_released` as valid source states — it does NOT accept `disputed`. The existing `financial_escrow_refund` (line 988) DOES accept `disputed`. Rather than modifying EP-02-04 code (out of scope), `dispute_resolve` performs escrow transitions and financial movements **inline** within its own function body, running as `service_role` which has full UPDATE on `financial_escrow`, INSERT on `financial_transactions`, and UPDATE on `financial_balances`.

**Filing a dispute (automatic hold):**
1. `dispute_file` (SECURITY INVOKER, authenticated) validates the caller is a party to the escrow
2. Creates the `dispute_cases` row with status `open`
3. Calls `dispute_place_escrow_hold(p_escrow_id)` (SECURITY DEFINER) which:
   - Validates the escrow exists and is in `funded` or `partially_released` state
   - `SELECT ... FOR UPDATE` on the escrow row
   - Transitions `financial_escrow.status` → `disputed`
   - Writes a `dispute_audit_trail` row for the hold placement
4. Writes a `dispute_audit_trail` row for the case creation
5. Returns the created dispute case in the envelope

**Resolving a dispute (financial outcome):**
1. `dispute_resolve` (SECURITY INVOKER, service_role) validates the dispute exists and is `open` or `under_review`
2. `SELECT ... FOR UPDATE` on `dispute_cases` and `financial_escrow`
3. Creates a `dispute_resolutions` row with the admin's decision
4. Based on `resolution_type`:
   - **`release_to_payee`**: Updates escrow `disputed` → `released`, sets `released_at`; debits payer `held_balance`, credits payee `available_balance`; inserts `financial_transactions` row (type `escrow_release`); inserts `financial_audit_trail` row
   - **`refund_to_payer`**: Updates escrow `disputed` → `refunded`, sets `refunded_at`; debits payer `held_balance`, credits payer `available_balance`; inserts `financial_transactions` row (type `escrow_refund`); inserts `financial_audit_trail` row
   - **`split`**: Updates escrow `disputed` → `released`; debits payer `held_balance` for full remaining amount; credits payer `available_balance` for refund portion; credits payee `available_balance` for release portion; inserts two `financial_transactions` rows; inserts `financial_audit_trail` rows
   - **`dismissed`**: Calls `dispute_release_escrow_hold` to transition escrow `disputed` → `funded` (hold released, no fund movement)
5. Updates `dispute_cases.status` → `resolved`, sets `resolved_at`
6. Writes `dispute_audit_trail` row for the resolution
7. Returns the resolution in the envelope

**Withdrawing a dispute (hold release):**
1. `dispute_withdraw` (SECURITY INVOKER, authenticated) validates the caller is the filer and the dispute is `open`
2. Calls `dispute_release_escrow_hold(p_escrow_id)` (SECURITY DEFINER) which transitions escrow `disputed` → `funded`
3. Updates `dispute_cases.status` → `withdrawn`, sets `withdrawn_at`
4. Writes `dispute_audit_trail` row
5. Returns the updated dispute case

### 5.5 Financial Movement Within Dispute Resolution

`dispute_resolve` performs financial movements inline (not by calling `financial_escrow_release`/`financial_escrow_refund`). This is necessary because:
- `financial_escrow_release` does NOT accept `disputed` as a valid source state
- `dispute_resolve` needs atomic control over the full resolution flow (dispute state + escrow state + balances + transactions + audit)
- `dispute_resolve` runs as `service_role` which has the required grants on all financial tables

**Balance mutation pattern** (inside `dispute_resolve`):
1. `SELECT ... FOR UPDATE` on `financial_escrow` row
2. `SELECT ... FOR UPDATE` on payer's `financial_balances` row
3. INSERT into `financial_transactions` (immutable ledger entry)
4. UPDATE `financial_balances` for payer: decrement `held_balance`
5. UPDATE/INSERT `financial_balances` for payee (or payer for refund): increment `available_balance`
6. UPDATE `financial_escrow`: set `status`, `released_amount`/`refunded_amount`, timestamps
7. INSERT into `financial_audit_trail` for the financial event
8. All within one function = one transaction = atomic

### 5.6 Audit Logging Strategy

Follows the EP-02-03/04 pattern:
- **Entity-facing RPCs** (`dispute_file`, `dispute_submit_evidence`, `dispute_withdraw`): call `platform_audit_log_add()` for cross-system audit consistency AND insert into `dispute_audit_trail`.
- **Service-role RPC** (`dispute_resolve`): writes directly to `dispute_audit_trail` (not `platform_audit_log_add`) because `auth.uid()` is NULL in service_role context. Also writes to `financial_audit_trail` for financial movements.
- **SECURITY DEFINER helpers** (`dispute_place_escrow_hold`, `dispute_release_escrow_hold`): write to `dispute_audit_trail` using the calling entity's `auth.uid()` (preserved through SECURITY DEFINER context).

`dispute_audit_trail` is the authoritative dispute audit log — append-only, no UPDATE/DELETE grants.

### 5.7 Response Envelope Contract

All RPCs return the standard `{success, code, message, data}` envelope (PLT000 success; PLT001 auth; PLT003 validation; PLT004 not found; PLT005 conflict; PLT999 internal). No new error codes are required.

### 5.8 Reuse of Platform Helpers

| Helper | Source | Usage |
|---|---|---|
| `platform_is_authenticated()` | `20260819090001` | Auth gate on entity-facing RPCs |
| `platform_raise_error(code, message)` | `20260819090001` | Standardized error raising |
| `platform_set_updated_at()` | `20260819090001` | `updated_at` trigger on `dispute_cases` |
| `platform_audit_log_add(...)` | `20260819090003` | General audit from authenticated RPCs |

### 5.9 Cross-Table References (Read-Only, No Modification)

| Reference | Target Table | Usage |
|---|---|---|
| `dispute_cases.escrow_id` | `financial_escrow(id)` | FK — links dispute to escrow |
| `dispute_cases.filer_entity_id` | `entities(id)` | FK — who filed the dispute |
| `dispute_cases.counterparty_entity_id` | `entities(id)` | FK — the other party |
| `dispute_evidence.case_id` | `dispute_cases(id)` | FK — evidence belongs to case |
| `dispute_evidence.submitted_by` | `entities(id)` | FK — who submitted evidence |
| `dispute_resolutions.case_id` | `dispute_cases(id)` | FK — resolution belongs to case |
| `dispute_resolutions.resolved_by` | `entities(id)` | FK — admin who resolved (nullable) |
| `dispute_audit_trail.case_id` | `dispute_cases(id)` | FK — audit belongs to case |
| Escrow state read/write | `financial_escrow` | Read: validate state. Write (service_role): status transitions |
| Balance mutation | `financial_balances` | Service-role context: debit held, credit available |
| Transaction recording | `financial_transactions` | Service-role context: immutable ledger entry |
| Financial audit | `financial_audit_trail` | Service-role context: financial event audit |

---

## 6. Required Systems, Modules, and Components

| Component | Location | Action |
|---|---|---|
| Dispute schema + RPCs migration | `supabase/migrations/<timestamp>_dispute_resolution_schema.sql` | **Create** — new SQL migration |
| pgTAP schema posture test | `supabase/tests/database/015_dispute_schema_posture.sql` | **Create** — new test file |
| pgTAP RPC enforcement test | `supabase/tests/database/016_dispute_rpc_enforcement.sql` | **Create** — new test file |

**No client-side modules, Dart files, or Flutter components are created in this task.**

---

## 7. Data Requirements

### 7.1 New Tables (4)

**`dispute_cases`** — dispute case records:

| Column | Type | Notes |
|---|---|---|
| `id` | `uuid` PK | `gen_random_uuid()` |
| `escrow_id` | `uuid` FK `financial_escrow(id)` ON DELETE RESTRICT | linked escrow |
| `filer_entity_id` | `uuid` FK `entities(id)` ON DELETE RESTRICT | entity who filed |
| `counterparty_entity_id` | `uuid` FK `entities(id)` ON DELETE RESTRICT | the other party |
| `dispute_type` | `text` | `service_quality \| non_delivery \| milestone_disagreement \| fraud \| other` |
| `status` | `text` | `open \| under_review \| resolved \| closed \| withdrawn`, default `open` |
| `reason` | `text` | 10–2000 chars — filer's description |
| `desired_outcome` | `text` | `release_to_payee \| refund_to_payer \| split \| other` |
| `priority` | `text` | `low \| medium \| high \| critical`, default `medium` |
| `filed_at` | `timestamptz` | default now() |
| `resolved_at` | `timestamptz` | nullable |
| `closed_at` | `timestamptz` | nullable |
| `withdrawn_at` | `timestamptz` | nullable |
| `metadata` | `jsonb` | default `'{}'::jsonb` |
| `created_at` | `timestamptz` | default now() |
| `updated_at` | `timestamptz` | default now() |
| `created_by` | `uuid` | default auth.uid() |

**`dispute_evidence`** — evidence submissions (immutable):

| Column | Type | Notes |
|---|---|---|
| `id` | `uuid` PK | `gen_random_uuid()` |
| `case_id` | `uuid` FK `dispute_cases(id)` ON DELETE CASCADE | |
| `submitted_by` | `uuid` FK `entities(id)` ON DELETE RESTRICT | |
| `evidence_type` | `text` | `document \| screenshot \| description \| photo` |
| `title` | `text` | 1–255 chars |
| `description` | `text` | nullable, ≤ 2000 chars |
| `file_url` | `text` | nullable — Supabase Storage URL |
| `file_metadata` | `jsonb` | default `'{}'::jsonb` |
| `created_at` | `timestamptz` | default now() |
| `created_by` | `uuid` | default auth.uid() |

No `updated_at` — evidence is immutable (no UPDATE/DELETE grants).

**`dispute_resolutions`** — resolution decisions (immutable):

| Column | Type | Notes |
|---|---|---|
| `id` | `uuid` PK | `gen_random_uuid()` |
| `case_id` | `uuid` FK `dispute_cases(id)` ON DELETE RESTRICT | `unique (case_id)` |
| `resolved_by` | `uuid` FK `entities(id)` ON DELETE SET NULL | nullable (admin or system) |
| `resolution_type` | `text` | `release_to_payee \| refund_to_payer \| split \| dismissed` |
| `reasoning` | `text` | 10–5000 chars |
| `payer_refund_amount` | `numeric` | ≥ 0, default 0 |
| `payee_release_amount` | `numeric` | ≥ 0, default 0 |
| `notes` | `text` | nullable — internal admin notes |
| `resolved_at` | `timestamptz` | default now() |
| `created_at` | `timestamptz` | default now() |
| `created_by` | `uuid` | default auth.uid() |

No `updated_at` — resolutions are immutable (no UPDATE/DELETE grants).

**`dispute_audit_trail`** — immutable dispute history:

| Column | Type | Notes |
|---|---|---|
| `id` | `uuid` PK | `gen_random_uuid()` |
| `case_id` | `uuid` FK `dispute_cases(id)` ON DELETE CASCADE | |
| `entity_id` | `uuid` FK `entities(id)` ON DELETE SET NULL | nullable |
| `event_type` | `text` | see vocabulary below |
| `subject_type` | `text` | `dispute_case \| dispute_evidence \| dispute_resolution \| escrow_hold` |
| `subject_id` | `uuid` | nullable |
| `from_state` | `text` | nullable |
| `to_state` | `text` | nullable |
| `actor_id` | `uuid` | nullable |
| `details` | `jsonb` | default `'{}'::jsonb` |
| `created_at` | `timestamptz` | default now() |

No `updated_at` — append-only (no UPDATE/DELETE grants).

Event type vocabulary: `case_filed`, `escrow_hold_placed`, `evidence_submitted`, `status_under_review`, `case_resolved`, `case_withdrawn`, `escrow_hold_released`, `case_closed`, `financial_release`, `financial_refund`, `financial_split`.

### 7.2 Indexes

- `dispute_cases_escrow_idx (escrow_id)`
- `dispute_cases_filer_idx (filer_entity_id, status)`
- `dispute_cases_counterparty_idx (counterparty_entity_id, status)`
- `dispute_cases_status_idx (status)`
- `dispute_cases_filed_at_idx (filed_at desc)`
- `dispute_cases_one_open_per_escrow_idx` — partial unique: `(escrow_id) WHERE status IN ('open', 'under_review')`
- `dispute_evidence_case_idx (case_id, created_at)`
- `dispute_evidence_submitted_by_idx (submitted_by)`
- `dispute_resolutions_case_key` — unique (case_id)
- `dispute_audit_trail_case_idx (case_id, created_at)`
- `dispute_audit_trail_created_at_idx (created_at desc)`
- `dispute_audit_trail_subject_idx (subject_type, subject_id)`

---

## 8. Database Considerations

### 8.1 Existing Schema (References Only, No Modification)

- `entities(id)` — FK target. Not altered.
- `financial_escrow(id, payer_entity_id, payee_entity_id, status, total_amount, released_amount, refunded_amount, currency_code, financial_profile_id)` — read and mutated by service_role RPCs (status transitions). The `disputed` status is already in the CHECK constraint (line 207). Not structurally altered.
- `financial_balances` — mutated by `dispute_resolve` (service_role has full UPDATE). Not altered.
- `financial_transactions` — inserted by `dispute_resolve` (service_role has INSERT). Reuses existing `escrow_release` and `escrow_refund` types. Not altered.
- `financial_audit_trail` — inserted by `dispute_resolve` (service_role has INSERT, line 565). Not altered.

### 8.2 RLS & Grants (Default-Deny)

| Table | `anon` | `authenticated` | `service_role` |
|---|---|---|---|
| `dispute_cases` | — | SELECT (party), INSERT (limited cols) | SELECT, INSERT, UPDATE |
| `dispute_evidence` | — | SELECT (via case party), INSERT (limited cols) | SELECT, INSERT |
| `dispute_resolutions` | — | SELECT (via case party) | SELECT, INSERT |
| `dispute_audit_trail` | — | SELECT (via case party), INSERT (self) | SELECT, INSERT |

**Critical column exclusions:**
- `dispute_cases.status`, `resolved_at`, `closed_at`, `withdrawn_at`: NOT writable by `authenticated`
- `dispute_evidence`: no UPDATE/DELETE grant to any role — immutable
- `dispute_resolutions`: no UPDATE/DELETE grant to any role — immutable; INSERT only by `service_role`
- `dispute_audit_trail`: no UPDATE/DELETE grant to any role — append-only

### 8.3 Trigger Compatibility

`platform_set_updated_at()` attached to `dispute_cases` only (1 mutable table). Immutable tables (`dispute_evidence`, `dispute_resolutions`, `dispute_audit_trail`) have no `updated_at` column and no trigger.

### 8.4 Realtime Exclusion

All 4 new tables excluded from `supabase_realtime` (guarded `DO $$` block, consistent with prior patterns).

### 8.5 Concurrency & Locking

- **Dispute filing**: Partial unique index `dispute_cases_one_open_per_escrow_idx` prevents concurrent duplicate filings. Exception block maps `unique_violation` → PLT005.
- **Escrow hold**: `dispute_place_escrow_hold` uses `SELECT ... FOR UPDATE` on `financial_escrow`.
- **Resolution**: `dispute_resolve` uses `SELECT ... FOR UPDATE` on both `dispute_cases` and `financial_escrow`.
- **Evidence**: Immutable inserts — no locking concerns.

### 8.6 SECURITY DEFINER Helper Design

Both helpers follow strict SECURITY DEFINER best practices:

| Property | Enforcement |
|---|---|
| Pinned search_path | `SET search_path = pg_catalog, public` |
| Caller validation | Checks `auth.uid()` is a party to the escrow |
| State validation | Checks escrow is in valid source state before transitioning |
| Narrow scope | Single purpose: one state transition + audit write |
| FOR UPDATE locking | Prevents concurrent state changes |
| No data leakage | Returns void; error messages are static |
| Posture test visibility | `015` explicitly asserts exactly 2 SECURITY DEFINER functions with known names |

---

## 9. API Requirements

### 9.1 RPC API Surface (PostgREST `/rpc/`)

| RPC | Access | Volatility | Purpose |
|---|---|---|---|
| `dispute_file(p_escrow_id uuid, p_dispute_type text, p_reason text, p_desired_outcome text, p_priority text default 'medium')` | authenticated, service_role | VOLATILE | File dispute + place escrow hold |
| `dispute_submit_evidence(p_case_id uuid, p_evidence_type text, p_title text, p_description text default null, p_file_url text default null, p_file_metadata jsonb default '{}')` | authenticated, service_role | VOLATILE | Submit evidence |
| `dispute_resolve(p_case_id uuid, p_resolution_type text, p_reasoning text, p_payer_refund_amount numeric default 0, p_payee_release_amount numeric default 0, p_notes text default null)` | service_role only | VOLATILE | Resolve dispute with financial outcome |
| `dispute_withdraw(p_case_id uuid)` | authenticated, service_role | VOLATILE | Withdraw dispute; release escrow hold |
| `dispute_get(p_case_id uuid)` | authenticated (party), service_role | STABLE | Retrieve dispute with evidence + resolution |
| `dispute_list(p_status text default null)` | authenticated (self), service_role | STABLE | List disputes for authenticated entity |

### 9.2 Internal Helper Functions

| Helper | Access | Security | Purpose |
|---|---|---|---|
| `dispute_place_escrow_hold(p_escrow_id uuid)` | Called internally by `dispute_file` | SECURITY DEFINER | Transition escrow → `disputed` |
| `dispute_release_escrow_hold(p_escrow_id uuid)` | Called internally by `dispute_withdraw`, `dispute_resolve` (dismissed) | SECURITY DEFINER | Transition escrow `disputed` → `funded` |

EXECUTE on helpers: granted to `authenticated` and `service_role`. The helpers validate caller authorization internally.

### 9.3 No REST Endpoints / No Edge Functions

All access via RPC. No custom REST routes or Edge Functions created.

---

## 10. User Interface Requirements

**None.** This task produces no UI. The dispute UIs are EP-02-17.

---

## 11. User Experience Considerations

While server-side only, this schema directly shapes UX downstream:
- **Transparent case tracking**: `dispute_get` returns the full case with evidence list and resolution
- **Evidence submission**: `dispute_submit_evidence` supports multiple evidence types for rich evidence upload UX
- **Consistent envelope**: all RPCs return `{success, code, message, data}`
- **Dispute listing**: `dispute_list` supports status filtering
- **Resolution visibility**: `dispute_get` includes resolution with reasoning and financial outcome
- **Immediate hold confirmation**: `dispute_file` returns dispute case with escrow hold confirmed
- **Withdrawal option**: `dispute_withdraw` enables informal resolution retraction

---

## 12. Security Considerations

| Consideration | Approach |
|---|---|
| Zero client-side dispute logic | All state transitions, escrow holds, financial adjustments execute inside RPCs |
| Escrow hold integrity | `dispute_place_escrow_hold` (SECURITY DEFINER) is the only authorized path to `disputed`; validates caller is a party |
| Escrow hold release | `dispute_release_escrow_hold` (SECURITY DEFINER) is the only authorized path from `disputed` → `funded` |
| Resolution authorization | `dispute_resolve` is service_role only |
| Financial movement integrity | `dispute_resolve` performs inline balance mutations with `SELECT ... FOR UPDATE`; double-entry pattern |
| Evidence immutability | No UPDATE/DELETE grants to any role |
| Resolution immutability | No UPDATE/DELETE grants to any role |
| Audit immutability | `dispute_audit_trail` append-only |
| One active dispute per escrow | Partial unique index |
| Default-deny | All 4 tables revoked except narrow grants |
| Party-scoping | RLS + explicit checks enforce filer/counterparty membership |
| SECURITY DEFINER hardening | Pinned search_path, caller validation, narrow scope, void return, FOR UPDATE |
| No `financial_%` SECURITY DEFINER | Helpers are `dispute_%` prefix — no `013` conflict |
| SQL injection | All DML parameterized; no string-built SQL |
| Negative balance prevention | Validates amounts against escrow held amount; CHECK on `financial_balances` backstop |

---

## 13. Performance Considerations

| Consideration | Approach |
|---|---|
| Dispute retrieval | `dispute_get` uses PK lookup + indexed evidence join |
| Dispute listing | Filer/counterparty indexes support entity-scoped listing |
| Admin queue | Status index supports filtering |
| Escrow hold | Single-row FOR UPDATE — no table locks |
| Resolution | FOR UPDATE on escrow + balances — single-row operations |
| Evidence/audit inserts | Append-only, indexed; negligible overhead |
| Volatility | Read RPCs STABLE; write RPCs VOLATILE |
| No N+1 | `dispute_get` assembles all data in one function |
| Duplicate prevention | Partial unique index prevents concurrent filings without scans |

---

## 14. Testing Strategy

### 14.1 `015_dispute_schema_posture.sql`

| Test | Assertion |
|---|---|
| All 4 tables exist | `has_table` ×4 |
| RLS enabled on all 4 | count = 4 |
| anon zero grants on all 4 | count = 0 |
| `dispute_cases.status/resolved_at/closed_at/withdrawn_at` not writable by `authenticated` | column-grant check |
| `dispute_evidence` no UPDATE/DELETE grant | 0 |
| `dispute_resolutions` no UPDATE/DELETE grant | 0 |
| `dispute_audit_trail` no UPDATE/DELETE grant | 0 |
| Trigger on `dispute_cases` (1 mutable table) | count = 1 |
| Exactly 2 `dispute_%` SECURITY DEFINER functions | count = 2 |
| No `financial_%` SECURITY DEFINER (regression) | count = 0 |
| Realtime excludes all 4 tables | 0 |
| Comments on all 4 tables | non-null |
| Partial unique index exists | index check |

### 14.2 `016_dispute_rpc_enforcement.sql`

**Authorization:** anon 42501 ×8; authenticated 42501 on `dispute_resolve`; authenticated success ×5 + helpers ×2; service_role success ×8.

**Validation:** NULL escrow_id (PLT003), non-existent escrow (PLT004), invalid escrow state (PLT005), non-party caller (PLT003), short reason (PLT003), duplicate active dispute (PLT005), non-existent case (PLT004), closed case evidence (PLT005), invalid resolution_type (PLT003), split amounts exceeding escrow (PLT003), dismissed with non-zero amounts (PLT003), withdraw non-open (PLT005), non-filer withdraw (PLT003), get non-party (PLT004).

**Functional / Escrow Integration:**
- `dispute_file` → case `open` + escrow `disputed` + audit rows
- `dispute_submit_evidence` → evidence row + audit
- `dispute_resolve` (release_to_payee) → resolution + escrow `released` + payer held→payee available + transaction + financial audit
- `dispute_resolve` (refund_to_payer) → resolution + escrow `refunded` + payer held→payer available + transaction + financial audit
- `dispute_resolve` (split) → resolution + escrow `released` + proportional credits + two transactions
- `dispute_resolve` (dismissed) → resolution + escrow `funded` (hold released) + no balance movement
- `dispute_withdraw` → dispute `withdrawn` + escrow `funded` + audit
- `dispute_get` → case + evidence + resolution
- `dispute_list` → party-scoped listing

**Envelope contract:** all RPCs return `{success, code, message, data}`; PLT000 on success.

### 14.3 Regression

Full suite `001`–`016`. Confirm `008`/`009`/`010`/`011`/`012`/`013`/`014` still pass.

---

## 15. Recommended Implementation Sequence

| Step | Action | Output |
|---|---|---|
| 1 | Create migration file | Scaffold |
| 2 | Header comment block (EP-02-05, execution model, state machine, escrow integration, grant strategy, SECURITY DEFINER justification) | Docs |
| 3 | DDL: `dispute_cases` (FK, constraints, indexes, trigger, comment) | Table |
| 4 | DDL: `dispute_evidence` (FK, constraints, indexes, comment — immutable) | Table |
| 5 | DDL: `dispute_resolutions` (FK, constraints, indexes, comment — immutable) | Table |
| 6 | DDL: `dispute_audit_trail` (FK, indexes, comment — immutable) | Table |
| 7 | RLS enable + revoke + per-table grants + party-scoped policies | Security |
| 8 | Implement `dispute_place_escrow_hold` (SECURITY DEFINER, pinned search_path, FOR UPDATE, audit) | Helper |
| 9 | Implement `dispute_release_escrow_hold` (SECURITY DEFINER, pinned search_path, FOR UPDATE, audit) | Helper |
| 10 | Implement `dispute_file` (auth, party validation, call helper, audit) | RPC |
| 11 | Implement `dispute_submit_evidence` (auth, case state validation, immutable insert, audit) | RPC |
| 12 | Implement `dispute_resolve` (service-role, inline financial movement, double-entry, escrow transition, dual audit) | RPC |
| 13 | Implement `dispute_withdraw` (auth, filer validation, call helper, audit) | RPC |
| 14 | Implement `dispute_get` (auth, party scope, join evidence + resolution) | RPC |
| 15 | Implement `dispute_list` (auth, self-scope, optional status filter) | RPC |
| 16 | Revoke + specific EXECUTE grants | Authz |
| 17 | `comment on function` for all 8 functions | Docs |
| 18 | Realtime exclusion `DO $$` block | Security |
| 19 | Create `015_dispute_schema_posture.sql` | Test |
| 20 | Create `016_dispute_rpc_enforcement.sql` | Test |
| 21 | `supabase db push` (or `supabase db reset`) | Migrate |
| 22 | `supabase db test` — all new + existing pass | Verify |

---

## 16. Expected Outcome

- 4 dispute tables with full RLS (default-deny), triggers, indexes, comments, Realtime exclusion
- 2 SECURITY DEFINER helper functions for escrow hold management
- 6 RPCs: entity-facing party-scoped + service-role resolution
- Dispute filing places automatic escrow hold (atomic via SECURITY DEFINER helper)
- Resolution triggers escrow release/refund/split with atomic double-entry balance movements
- Dispute withdrawal releases escrow hold
- Evidence and resolutions are immutable; audit trail is append-only
- Financial movements produce `financial_transactions` + `financial_audit_trail` entries
- No `financial_%` SECURITY DEFINER introduced; no prior table altered
- pgTAP `015` + `016` pass; full suite `001`–`016` green
- EP-02-17 unblocked

---

## 17. Definition of Done (DoD)

| # | Criterion | Verification |
|---|---|---|
| 1 | Migration file exists, ordered after `20260829100004` | File inspection |
| 2 | 4 tables created | `has_table` ×4 |
| 3 | All 4 tables have RLS enabled | `relrowsecurity` check |
| 4 | `anon` zero grants on all 4 tables | `role_table_grants` query |
| 5 | `dispute_cases.status/resolved_at/closed_at/withdrawn_at` not writable by `authenticated` | column-grant |
| 6 | `dispute_evidence` no UPDATE/DELETE to any client role | grant query |
| 7 | `dispute_resolutions` no UPDATE/DELETE to any client role | grant query |
| 8 | `dispute_audit_trail` no UPDATE/DELETE to any client role | grant query |
| 9 | Exactly 8 `dispute_` functions (6 RPCs + 2 helpers) | `pg_proc` query |
| 10 | 6 RPCs SECURITY INVOKER | `prosecdef = 0` |
| 11 | 2 helpers SECURITY DEFINER with pinned search_path | `pg_proc` + `proconfig` |
| 12 | `dispute_resolve` EXECUTE to `service_role` only | grant inspection |
| 13 | `anon` cannot call any function (42501) | pgTAP |
| 14 | `authenticated` cannot call `dispute_resolve` (42501) | pgTAP |
| 15 | `dispute_file` → case + escrow `disputed` | pgTAP |
| 16 | Duplicate active dispute prevention (PLT005) | pgTAP |
| 17 | `dispute_resolve` (release) → escrow released, payee credited | pgTAP |
| 18 | `dispute_resolve` (refund) → escrow refunded, payer credited | pgTAP |
| 19 | `dispute_resolve` (split) → proportional credits, two transactions | pgTAP |
| 20 | `dispute_resolve` (dismissed) → escrow hold released, no movement | pgTAP |
| 21 | `dispute_withdraw` → withdrawn + escrow `funded` | pgTAP |
| 22 | `dispute_submit_evidence` → immutable evidence row | pgTAP |
| 23 | `dispute_get` → case + evidence + resolution | pgTAP |
| 24 | `dispute_list` → party-scoped | pgTAP |
| 25 | `dispute_audit_trail` rows for all state changes | pgTAP |
| 26 | Financial movements → `financial_transactions` + `financial_audit_trail` | pgTAP |
| 27 | Envelope contract `{success, code, message, data}` | pgTAP |
| 28 | No DDL alters prior tables/functions | Migration review |
| 29 | No `financial_%` SECURITY DEFINER (013 regression) | `pg_proc` |
| 30 | Realtime excludes 4 tables | Publication query |
| 31 | `015` passes | `supabase db test` |
| 32 | `016` passes | `supabase db test` |
| 33 | Full suite `001`–`016` passes | `supabase db test` |
| 34 | No client-side files created | File inspection |
| 35 | EP-02-17 unblocked | Dependency check |

---

## 18. Implementation AI Execution Profile

### Recommended Coding Reasoning Level: **Extremely High**

### Reasoning Level Justification

| Factor | Assessment |
|---|---|
| **Technical complexity** | Extremely High — 4 tables, 8 functions (including 2 SECURITY DEFINER helpers with pinned search_path), cross-table escrow state transitions, inline double-entry financial movements, partial unique indexes, complex RLS party-scoping |
| **Business impact** | Extremely High — dispute resolution is the trust backstop for all marketplace transactions (EP-03 through EP-08); incorrect design means parties have no recourse, undermining platform trust |
| **Security risk** | Extremely High — SECURITY DEFINER functions require meticulous hardening; escrow hold/release must be atomic to prevent fund leakage; resolution must prevent unauthorized financial movements |
| **Performance sensitivity** | High — FOR UPDATE locking on escrow rows; incorrect locking order could deadlock with concurrent financial operations |
| **Data complexity** | Extremely High — inline double-entry accounting across three financial tables; split resolutions require two balanced transaction rows |
| **Integration complexity** | Extremely High — integrates with `financial_escrow`, `financial_balances`, `financial_transactions`, `financial_audit_trail`, and `platform_audit_log_add` — all without modifying EP-02-04 code |
