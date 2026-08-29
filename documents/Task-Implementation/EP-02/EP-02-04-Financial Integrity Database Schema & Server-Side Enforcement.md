# Task Implementation Plan — EP-02-04: Financial Integrity Database Schema & Server-Side Enforcement

---

## 1. Task Objective

Design and implement the complete server-side financial database schema and enforcement layer that serves as the **financial bedrock** for all marketplace transactions (EP-03+). Deliverables:

- **11 new tables**: `financial_profiles`, `financial_currency_accounts`, `financial_balances`, `financial_transactions`, `financial_escrow`, `financial_escrow_milestones`, `financial_payout_accounts`, `financial_payouts`, `financial_deposits`, `financial_conversions`, `financial_audit_trail`
- **18 RPCs** covering profile creation, balance queries, escrow lifecycle (create/fund/release/refund), payout account binding, withdrawal, deposit recording with name-matching, currency conversion, and financial status aggregation
- **Full RLS** (default-deny) on all 11 tables
- **Double-entry accounting integrity** enforced server-side — every balance mutation is atomic, balanced, and audited
- **2 pgTAP test files**: `013_financial_schema_posture.sql`, `014_financial_rpc_enforcement.sql`
- **Zero modifications** to any EP-01, EP-02-01, EP-02-02, or EP-02-03 table or function
- **Zero financial logic accessible to the client** — all calculations, splits, limit checks, and state transitions execute via PostgreSQL RPC + RLS

---

## 2. Business Problem Being Solved

EP-02-03 established the verification engine (KYC tiers, admin review, trade gate), but **no financial infrastructure exists** to hold, move, or protect money:

- No financial profile — entities have identity and verification but no unified financial identity linking currency accounts, balances, and transaction history
- No balance model — there is no way to track how much an entity has available, held in escrow, or pending withdrawal
- No escrow system — marketplace transactions (EP-03 professional services, EP-04 commerce) cannot be protected by fund-holding
- No payout channel — entities cannot receive money because no bound bank account system exists
- No deposit verification — AGENT.md Rule 3 (payer name = entity legal name) has no enforcement mechanism
- No transaction ledger — no immutable, auditable record of financial movements
- No currency conversion infrastructure — multi-currency support (NGN, GHS, USD, GBP) has no foundation
- No double-entry accounting — without it, balance inconsistencies are undetectable and financial integrity is unverifiable

This task is the **most architecturally significant item in EP-02**. Incorrect design here creates catastrophic financial risk propagating to every marketplace phase (EP-03 through EP-08). Every escrow hold, every payout, every balance check, every name-match runs through these tables and their RPCs.

---

## 3. Scope

| In Scope | Detail |
|---|---|
| `financial_profiles` table | Unified per-entity financial identity (one per entity) |
| `financial_currency_accounts` table | Currency-specific receiving accounts (NGN, GHS, USD, GBP) |
| `financial_balances` table | Currency-specific available/held/pending balances per profile |
| `financial_transactions` table | Immutable double-entry transaction ledger |
| `financial_escrow` table | Escrow records with lifecycle state machine |
| `financial_escrow_milestones` table | Milestone-based release conditions per escrow |
| `financial_payout_accounts` table | Bound bank accounts with ownership verification |
| `financial_payouts` table | Withdrawal records |
| `financial_deposits` table | Incoming payment records with payer name |
| `financial_conversions` table | Currency conversion records |
| `financial_audit_trail` table | Immutable financial audit log |
| RPC: `financial_profile_create` | Create unified financial profile for authenticated entity |
| RPC: `financial_profile_get` | Retrieve financial profile with currency accounts |
| RPC: `financial_balance_get` | Currency-specific balance query |
| RPC: `financial_escrow_create` | Create escrow with milestones |
| RPC: `financial_escrow_fund` | Fund escrow (payer balance → held) |
| RPC: `financial_escrow_release` | Release escrow to payee (held → payee available) |
| RPC: `financial_escrow_refund` | Refund escrow to payer (held → payer available) |
| RPC: `financial_escrow_milestone_complete` | Mark milestone completed for release eligibility |
| RPC: `financial_escrow_get` | Retrieve escrow with milestones and status |
| RPC: `financial_payout_account_bind` | Bind bank account with name verification |
| RPC: `financial_payout_account_verify` | Confirm account ownership via name match |
| RPC: `financial_withdraw` | Initiate withdrawal to bound account (within KYC limits) |
| RPC: `financial_deposit_record` | Record incoming deposit with payer name |
| RPC: `financial_deposit_verify_name` | Match payer name against entity legal name |
| RPC: `financial_convert_currency` | Execute currency conversion between balances |
| RPC: `financial_status_get` | Aggregated financial status (balances, active escrow, limits) |
| RPC: `financial_reconcile` | Verify balance table matches transaction ledger sum |
| RLS + grants | Default-deny on all 11 tables; narrow grants per table |
| pgTAP posture test | `013_financial_schema_posture.sql` |
| pgTAP enforcement test | `014_financial_rpc_enforcement.sql` |
| Supported currency seed | Idempotent insert of NGN, GHS, USD, GBP into a `financial_supported_currencies` reference table |

## 4. Out of Scope

| Out of Scope | Reason |
|---|---|
| Client-side financial UI / data layer | EP-02-13, EP-02-14, EP-02-15, EP-02-16 |
| Payment gateway abstraction (Paystack/Flutterwave adapters) | EP-02-09 |
| Dispute resolution schema | EP-02-05 |
| KYC provider integration adapters | EP-02-12 (integration seam only) |
| Currency-specific KYC limit overrides | EP-02-16 extends per-currency limits |
| Actual payment provider webhook handling | EP-02-09 + Edge Functions |
| Live currency exchange rate feeds | Rate is server-side config; live feeds deferred |
| Admin financial dashboard / reporting | Future task |
| Modification of any EP-01 / EP-02-01/02/03 table or function | Finalized in prior tasks; this task references them, does not alter them |
| Any client-side Dart/Flutter code | Server-side only task |
| Escrow dispute-hold integration | EP-02-05/17 adds dispute-hold state transitions |
| Multi-party split payments (platform fee deduction) | EP-03+ extends escrow release to include platform fees |

---

## 5. Recommended Technical Approach

### 5.1 Single SQL Migration

Create one migration file:
```
supabase/migrations/<YYYYMMDD><HHMMSS>_financial_integrity_schema.sql
```

The migration contains, in order: (1) `financial_supported_currencies` reference table + seed; (2) 11 financial table DDLs with constraints, indexes, triggers, comments; (3) RLS enablement, revokes, and grants per table; (4) 18 RPC function definitions; (5) EXECUTE grants; (6) `comment on function` documentation; (7) Realtime exclusion. **No changes to any prior table or function.**

### 5.2 Execution Model: SECURITY INVOKER

All 18 RPCs are `SECURITY INVOKER` — RLS applies inside the function body. Consistent with:
- `008_full_schema_posture_audit.sql` (asserts no entity/verification SECURITY DEFINER)
- EP-02-02 RPC pattern (all 7 taxonomy RPCs are SECURITY INVOKER)
- EP-02-03 RPC pattern (all 6 verification RPCs are SECURITY INVOKER)
- EP-01-06 entity RPC pattern (all 5 entity RPCs are SECURITY INVOKER)

**Authorization model:**
- **Entity-facing read RPCs** (`financial_profile_get`, `financial_balance_get`, `financial_escrow_get`, `financial_status_get`): EXECUTE granted to `authenticated` + `service_role`. They enforce `platform_is_authenticated()` and self-scope to `auth.uid()`.
- **Entity-facing write RPCs** (`financial_profile_create`, `financial_payout_account_bind`, `financial_withdraw`, `financial_convert_currency`): EXECUTE granted to `authenticated` + `service_role`. Auth-gated and self-scoped.
- **System/internal RPCs** (`financial_escrow_create`, `financial_escrow_fund`, `financial_escrow_release`, `financial_escrow_refund`, `financial_escrow_milestone_complete`, `financial_deposit_record`, `financial_deposit_verify_name`, `financial_payout_account_verify`, `financial_reconcile`): EXECUTE granted to `service_role` only. These are called by Edge Functions, admin tooling, or other server-side processes — never directly by the client.

### 5.3 Double-Entry Accounting Model

Every financial mutation produces a `financial_transactions` row that explicitly records both sides of the movement:

| Column | Purpose |
|---|---|
| `source_entity_id` | Entity whose balance is debited (nullable for system-originated credits) |
| `destination_entity_id` | Entity whose balance is credited (nullable for system-originated debits) |
| `debit_balance_type` | Which balance bucket is debited: `available`, `held`, `pending` |
| `credit_balance_type` | Which balance bucket is credited: `available`, `held`, `pending` |
| `amount` | Positive numeric; debit and credit are always equal |
| `currency_code` | Transaction currency |

**Balance mutation pattern** (inside every write RPC):
1. INSERT into `financial_transactions` (the immutable ledger entry)
2. UPDATE `financial_balances` for the source: decrement `debit_balance_type` column
3. UPDATE `financial_balances` for the destination: increment `credit_balance_type` column
4. All three operations within a single PL/pgSQL function = single transaction = atomic

**Balance invariant** (enforced by `financial_reconcile`):
```
SUM(all transactions for entity/currency/balance_type) = financial_balances row value
```

**Balance protection**: CHECK constraint on `financial_balances` ensures `available_balance >= 0 AND held_balance >= 0 AND pending_balance >= 0` — no negative balances are possible at the database level.

### 5.4 Escrow State Machine

```
created → funded → [milestones_completed] → released
                  → disputed (EP-02-05/17 adds this transition)
                  → refunded
```

| State | Meaning | Balance Effect |
|---|---|---|
| `created` | Escrow record exists, no funds yet | None |
| `funded` | Payer's available → payer's held | Debit payer available, credit payer held |
| `released` | Held funds → payee's available | Debit payer held, credit payee available |
| `refunded` | Held funds → payer's available | Debit payer held, credit payer available |
| `cancelled` | Cancelled before funding | None |
| `disputed` | Hold placed by dispute (EP-02-05) | No balance change; blocks release/refund |

State transitions are enforced server-side — invalid transitions raise PLT005.

### 5.5 Audit Logging Strategy

Follows the EP-02-03 pattern (§5.3):
- **Entity-facing write RPCs** (authenticated context): call `platform_audit_log_add()` for cross-system audit consistency AND insert into `financial_audit_trail`.
- **Service-role RPCs** (service_role context, `auth.uid()` is NULL): write directly to `financial_audit_trail` only.

`financial_audit_trail` is the authoritative financial audit log — append-only, no UPDATE/DELETE grants.

### 5.6 Response Envelope Contract

All RPCs return the standard `{success, code, message, data}` envelope (PLT000 success; PLT001 auth, PLT003 validation, PLT004 not found, PLT005 conflict, PLT006 insufficient funds [new], PLT999 internal). Error messages are static (no data values).

**New error code**: `PLT006` — Insufficient funds. Raised when a balance operation would result in a negative balance. This extends the existing PLT000–PLT999 vocabulary without conflicting with existing codes.

### 5.7 Reuse of Platform Helpers

| Helper | Source | Usage |
|---|---|---|
| `platform_is_authenticated()` | `20260819090001` | Auth gate on entity-facing RPCs |
| `platform_raise_error(code, message)` | `20260819090001` | Standardized error raising |
| `platform_set_updated_at()` | `20260819090001` | `updated_at` trigger on mutable tables |
| `platform_audit_log_add(...)` | `20260819090003` | General audit from authenticated RPCs |
| `verification_limits_get()` | `20260829090003` | KYC limit retrieval for withdrawal enforcement |
| `financial_audit_trail` direct insert | New table | Authoritative financial audit from service-role RPCs |

### 5.8 Supported Currencies Reference Table

A small reference table `financial_supported_currencies` holds the supported currency codes with metadata:

| Column | Type | Notes |
|---|---|---|
| `currency_code` | `char(3)` PK | ISO 4217 uppercase |
| `name` | `text` | e.g., "Nigerian Naira" |
| `symbol` | `text` | e.g., "₦" |
| `decimal_places` | `integer` | e.g., 2 |
| `is_active` | `boolean` | default true |
| `sort_order` | `integer` | default 0 |
| audit cols | per convention | |

Seeded idempotently: NGN, GHS, USD, GBP.

---

## 6. Required Systems, Modules, and Components

| Component | Location | Action |
|---|---|---|
| Financial schema + RPCs migration | `supabase/migrations/<timestamp>_financial_integrity_schema.sql` | **Create** — new SQL migration |
| pgTAP schema posture test | `supabase/tests/database/013_financial_schema_posture.sql` | **Create** — new test file |
| pgTAP RPC enforcement test | `supabase/tests/database/014_financial_rpc_enforcement.sql` | **Create** — new test file |

**No client-side modules, Dart files, or Flutter components are created in this task.**

---

## 7. Data Requirements

### 7.1 New Tables (12 including reference)

**`financial_supported_currencies`** — currency reference registry:

| Column | Type | Notes |
|---|---|---|
| `currency_code` | `char(3)` PK | ISO 4217, uppercase |
| `name` | `text` not null | 1–255 chars |
| `symbol` | `text` | nullable |
| `decimal_places` | `integer` not null | default 2, CHECK ≥ 0 |
| `is_active` | `boolean` not null | default true |
| `sort_order` | `integer` not null | default 0 |
| audit cols | per convention | `created_at`, `updated_at`, `created_by` |

Seeded idempotently via `INSERT ... ON CONFLICT (currency_code) DO NOTHING`:

| currency_code | name | symbol | decimal_places |
|---|---|---|---|
| `NGN` | Nigerian Naira | ₦ | 2 |
| `GHS` | Ghanaian Cedi | ₵ | 2 |
| `USD` | US Dollar | $ | 2 |
| `GBP` | British Pound | £ | 2 |

**`financial_profiles`** — unified per-entity financial identity:

| Column | Type | Notes |
|---|---|---|
| `id` | `uuid` PK | `gen_random_uuid()` |
| `entity_id` | `uuid` FK `entities(id)` ON DELETE CASCADE | `unique (entity_id)` — one profile per entity |
| `status` | `text` | `active \| suspended \| closed`, default `active` |
| `default_currency` | `char(3)` FK `financial_supported_currencies(currency_code)` | default `NGN` |
| `created_at` | `timestamptz` | default now() |
| `updated_at` | `timestamptz` | default now() |
| `created_by` | `uuid` | default auth.uid() |

**`financial_currency_accounts`** — currency-specific receiving accounts:

| Column | Type | Notes |
|---|---|---|
| `id` | `uuid` PK | `gen_random_uuid()` |
| `financial_profile_id` | `uuid` FK `financial_profiles(id)` ON DELETE CASCADE | |
| `entity_id` | `uuid` FK `entities(id)` ON DELETE CASCADE | denormalized for RLS self-scoping |
| `currency_code` | `char(3)` FK `financial_supported_currencies(currency_code)` | |
| `account_status` | `text` | `pending \| active \| suspended \| closed`, default `pending` |
| `receiving_account_number` | `text` | nullable — assigned by payment provider |
| `receiving_bank_name` | `text` | nullable |
| `provider_reference` | `text` | nullable — provider-side account ID |
| `activated_at` | `timestamptz` | nullable |
| audit cols | per convention | |

Constraint: `unique (entity_id, currency_code)` — one receiving account per entity per currency.

**`financial_balances`** — currency-specific balance records:

| Column | Type | Notes |
|---|---|---|
| `id` | `uuid` PK | `gen_random_uuid()` |
| `financial_profile_id` | `uuid` FK `financial_profiles(id)` ON DELETE CASCADE | |
| `entity_id` | `uuid` FK `entities(id)` ON DELETE CASCADE | denormalized for RLS |
| `currency_code` | `char(3)` FK `financial_supported_currencies(currency_code)` | |
| `available_balance` | `numeric` | ≥ 0, default 0 |
| `held_balance` | `numeric` | ≥ 0, default 0 |
| `pending_balance` | `numeric` | ≥ 0, default 0 |
| `total_deposited` | `numeric` | ≥ 0, default 0 (lifetime total in) |
| `total_withdrawn` | `numeric` | ≥ 0, default 0 (lifetime total out) |
| `last_transaction_at` | `timestamptz` | nullable |
| audit cols | per convention | |

Constraint: `unique (entity_id, currency_code)`. CHECK: all balance columns ≥ 0.

**`financial_transactions`** — immutable double-entry ledger:

| Column | Type | Notes |
|---|---|---|
| `id` | `uuid` PK | `gen_random_uuid()` |
| `financial_profile_id` | `uuid` FK `financial_profiles(id)` ON DELETE RESTRICT | |
| `entity_id` | `uuid` FK `entities(id)` ON DELETE RESTRICT | denormalized for RLS |
| `transaction_type` | `text` | see vocabulary below |
| `currency_code` | `char(3)` FK `financial_supported_currencies(currency_code)` | |
| `amount` | `numeric` | > 0, CHECK positive |
| `source_entity_id` | `uuid` FK `entities(id)` | nullable — who is debited |
| `destination_entity_id` | `uuid` FK `entities(id)` | nullable — who is credited |
| `debit_balance_type` | `text` | `available \| held \| pending` |
| `credit_balance_type` | `text` | `available \| held \| pending` |
| `reference_type` | `text` | `escrow \| payout \| deposit \| conversion \| system` |
| `reference_id` | `uuid` | nullable — FK to originating record |
| `description` | `text` | nullable, ≤ 500 chars |
| `created_at` | `timestamptz` | default now() |
| `created_by` | `uuid` | default auth.uid() |

No `updated_at` — transactions are immutable. No UPDATE/DELETE grants.

Transaction type vocabulary: `escrow_fund`, `escrow_release`, `escrow_refund`, `deposit`, `withdrawal`, `conversion_debit`, `conversion_credit`, `fee`, `adjustment`.

**`financial_escrow`** — escrow records with lifecycle state machine:

| Column | Type | Notes |
|---|---|---|
| `id` | `uuid` PK | `gen_random_uuid()` |
| `financial_profile_id` | `uuid` FK `financial_profiles(id)` ON DELETE RESTRICT | payer's profile |
| `payer_entity_id` | `uuid` FK `entities(id)` ON DELETE RESTRICT | |
| `payee_entity_id` | `uuid` FK `entities(id)` ON DELETE RESTRICT | |
| `currency_code` | `char(3)` FK `financial_supported_currencies(currency_code)` | |
| `total_amount` | `numeric` | > 0 |
| `released_amount` | `numeric` | ≥ 0, default 0 |
| `refunded_amount` | `numeric` | ≥ 0, default 0 |
| `status` | `text` | lifecycle state (see §5.4) |
| `funded_at` | `timestamptz` | nullable |
| `released_at` | `timestamptz` | nullable |
| `refunded_at` | `timestamptz` | nullable |
| `external_reference` | `text` | nullable — payment provider reference |
| `metadata` | `jsonb` | default `{}` |
| audit cols | per convention | |

Constraints: `released_amount + refunded_amount <= total_amount`. Status vocabulary: `created | funded | partially_released | released | refunded | cancelled | disputed`.

**`financial_escrow_milestones`** — milestone-based release conditions:

| Column | Type | Notes |
|---|---|---|
| `id` | `uuid` PK | `gen_random_uuid()` |
| `escrow_id` | `uuid` FK `financial_escrow(id)` ON DELETE CASCADE | |
| `milestone_number` | `integer` | ≥ 1 |
| `title` | `text` | 1–255 chars |
| `description` | `text` | nullable |
| `amount` | `numeric` | > 0 |
| `status` | `text` | `pending \| completed \| released`, default `pending` |
| `completed_at` | `timestamptz` | nullable |
| `released_at` | `timestamptz` | nullable |
| `sort_order` | `integer` | default 0 |
| audit cols | per convention | |

Constraint: `unique (escrow_id, milestone_number)`. Sum of milestone amounts must equal `financial_escrow.total_amount` (enforced by RPC, not CHECK — because milestones are inserted after escrow creation).

**`financial_payout_accounts`** — bound bank accounts:

| Column | Type | Notes |
|---|---|---|
| `id` | `uuid` PK | `gen_random_uuid()` |
| `entity_id` | `uuid` FK `entities(id)` ON DELETE CASCADE | |
| `currency_code` | `char(3)` FK `financial_supported_currencies(currency_code)` | |
| `bank_name` | `text` | 1–255 chars |
| `account_number` | `text` | 1–50 chars |
| `account_name` | `text` | 1–255 chars — verified name on the account |
| `is_verified` | `boolean` | default false |
| `verified_at` | `timestamptz` | nullable |
| `verification_method` | `text` | nullable — `name_enquiry | manual | micro_deposit` |
| `is_default` | `boolean` | default false |
| `status` | `text` | `pending \| active \| deactivated`, default `pending` |
| audit cols | per convention | |

Constraint: `unique (entity_id, currency_code, account_number)` — prevent duplicate bindings.

**`financial_payouts`** — withdrawal records:

| Column | Type | Notes |
|---|---|---|
| `id` | `uuid` PK | `gen_random_uuid()` |
| `entity_id` | `uuid` FK `entities(id)` ON DELETE RESTRICT | |
| `payout_account_id` | `uuid` FK `financial_payout_accounts(id)` ON DELETE RESTRICT | |
| `currency_code` | `char(3)` FK `financial_supported_currencies(currency_code)` | |
| `amount` | `numeric` | > 0 |
| `fee` | `numeric` | ≥ 0, default 0 |
| `net_amount` | `numeric` | = amount - fee |
| `status` | `text` | `pending \| processing \| completed \| failed`, default `pending` |
| `external_reference` | `text` | nullable — provider transfer reference |
| `completed_at` | `timestamptz` | nullable |
| `failure_reason` | `text` | nullable |
| audit cols | per convention | |

**`financial_deposits`** — incoming payment records:

| Column | Type | Notes |
|---|---|---|
| `id` | `uuid` PK | `gen_random_uuid()` |
| `entity_id` | `uuid` FK `entities(id)` ON DELETE RESTRICT | |
| `currency_code` | `char(3)` FK `financial_supported_currencies(currency_code)` | |
| `amount` | `numeric` | > 0 |
| `payer_name` | `text` | nullable — captured from payment provider |
| `name_match_status` | `text` | `pending \| matched \| mismatched \| unverified`, default `unverified` |
| `name_match_score` | `numeric` | nullable — 0.0 to 1.0 |
| `external_reference` | `text` | nullable — provider reference |
| `status` | `text` | `pending \| credited \| flagged \| reversed`, default `pending` |
| `credited_at` | `timestamptz` | nullable |
| audit cols | per convention | |

**`financial_conversions`** — currency conversion records:

| Column | Type | Notes |
|---|---|---|
| `id` | `uuid` PK | `gen_random_uuid()` |
| `entity_id` | `uuid` FK `entities(id)` ON DELETE RESTRICT | |
| `from_currency` | `char(3)` FK `financial_supported_currencies(currency_code)` | |
| `to_currency` | `char(3)` FK `financial_supported_currencies(currency_code)` | |
| `from_amount` | `numeric` | > 0 |
| `to_amount` | `numeric` | > 0 |
| `exchange_rate` | `numeric` | > 0 |
| `fee` | `numeric` | ≥ 0, default 0 |
| `status` | `text` | `pending \| completed \| failed`, default `pending` |
| `completed_at` | `timestamptz` | nullable |
| audit cols | per convention | |

Constraint: `from_currency <> to_currency`.

**`financial_audit_trail`** — append-only financial audit log:

| Column | Type | Notes |
|---|---|---|
| `id` | `uuid` PK | `gen_random_uuid()` |
| `entity_id` | `uuid` FK `entities(id)` ON DELETE SET NULL | nullable |
| `event_type` | `text` | see vocabulary below |
| `subject_type` | `text` | `profile \| currency_account \| balance \| escrow \| milestone \| payout_account \| payout \| deposit \| conversion` |
| `subject_id` | `uuid` | nullable |
| `from_state` | `text` | nullable |
| `to_state` | `text` | nullable |
| `amount` | `numeric` | nullable |
| `currency_code` | `char(3)` | nullable |
| `actor_id` | `uuid` | nullable |
| `details` | `jsonb` | default `{}` |
| `created_at` | `timestamptz` | default now() |

No `updated_at`; append-only (no UPDATE/DELETE grants).

Event type vocabulary: `profile_created`, `currency_account_created`, `currency_account_activated`, `balance_adjusted`, `escrow_created`, `escrow_funded`, `escrow_released`, `escrow_partially_released`, `escrow_refunded`, `escrow_cancelled`, `milestone_completed`, `milestone_released`, `payout_account_bound`, `payout_account_verified`, `payout_initiated`, `payout_completed`, `payout_failed`, `deposit_recorded`, `deposit_credited`, `deposit_flagged`, `conversion_executed`, `reconciliation_run`.

### 7.2 Indexes

- `financial_supported_currencies_active_sort_idx (is_active, sort_order)`
- `financial_profiles_entity_id_key` (unique, explicit)
- `financial_currency_accounts_entity_currency_key` (unique: entity_id, currency_code)
- `financial_currency_accounts_entity_status_idx (entity_id, account_status)`
- `financial_balances_entity_currency_key` (unique: entity_id, currency_code)
- `financial_balances_entity_idx (entity_id)`
- `financial_transactions_entity_created_idx (entity_id, created_at desc)`
- `financial_transactions_reference_idx (reference_type, reference_id)`
- `financial_transactions_source_idx (source_entity_id)`
- `financial_transactions_destination_idx (destination_entity_id)`
- `financial_escrow_payer_idx (payer_entity_id, status)`
- `financial_escrow_payee_idx (payee_entity_id, status)`
- `financial_escrow_status_idx (status)`
- `financial_escrow_milestones_escrow_idx (escrow_id, sort_order)`
- `financial_escrow_milestones_escrow_number_key` (unique: escrow_id, milestone_number)
- `financial_payout_accounts_entity_idx (entity_id, status)`
- `financial_payout_accounts_entity_currency_account_key` (unique: entity_id, currency_code, account_number)
- `financial_payouts_entity_status_idx (entity_id, status)`
- `financial_payouts_payout_account_idx (payout_account_id)`
- `financial_deposits_entity_status_idx (entity_id, status)`
- `financial_deposits_name_match_idx (name_match_status)`
- `financial_conversions_entity_idx (entity_id, created_at desc)`
- `financial_audit_trail_entity_idx (entity_id)`
- `financial_audit_trail_created_at_idx (created_at desc)`
- `financial_audit_trail_subject_idx (subject_type, subject_id)`

---

## 8. Database Considerations

### 8.1 Existing Schema (References Only, No Modification)

- `entities(id)` — FK target for entity_id columns. Not altered.
- `entity_profiles(entity_id, legal_name)` — referenced by name-matching RPC (`financial_deposit_verify_name`). Not altered.
- `entity_kyc_levels(entity_id, tier_code, status)` — joined by `financial_withdraw` to enforce KYC cashout limits via `verification_limits_get()`. Not altered.
- `kyc_tiers(tier_code, cashout_limit)` — referenced for limit enforcement. Not altered.
- `financial_supported_currencies(currency_code)` — new reference table created in this migration; FK target for all currency columns.

### 8.2 Constraint Compliance

| Constraint | Enforced By |
|---|---|
| `financial_supported_currencies.currency_code` format | CHECK `currency_code ~ '^[A-Z]{3}$'` + PK |
| Non-negative balances | CHECK on `financial_balances`: `available_balance >= 0 AND held_balance >= 0 AND pending_balance >= 0` |
| Positive transaction amounts | CHECK on `financial_transactions`: `amount > 0` |
| Escrow amount integrity | CHECK on `financial_escrow`: `released_amount >= 0 AND refunded_amount >= 0 AND released_amount + refunded_amount <= total_amount` |
| One financial profile per entity | UNIQUE `(entity_id)` on `financial_profiles` |
| One balance per entity per currency | UNIQUE `(entity_id, currency_code)` on `financial_balances` |
| One currency account per entity per currency | UNIQUE `(entity_id, currency_code)` on `financial_currency_accounts` |
| One payout account per entity per currency per account number | UNIQUE `(entity_id, currency_code, account_number)` on `financial_payout_accounts` |
| Conversion currency difference | CHECK `from_currency <> to_currency` on `financial_conversions` |
| FK integrity | All references `ON DELETE CASCADE/RESTRICT` as noted |
| Status vocabularies | CHECK `in (...)` (text, not ENUM — forward-extensible per EP-01 D2 pattern) |
| Milestone uniqueness | UNIQUE `(escrow_id, milestone_number)` |

### 8.3 RLS & Grants (Default-Deny)

Revoke blanket privileges first. Then per table:

| Table | `anon` | `authenticated` | `service_role` |
|---|---|---|---|
| `financial_supported_currencies` | SELECT | SELECT | SELECT, INSERT, UPDATE |
| `financial_profiles` | — | SELECT (self), INSERT (limited cols) | SELECT, INSERT, UPDATE |
| `financial_currency_accounts` | — | SELECT (self), INSERT (limited cols) | SELECT, INSERT, UPDATE |
| `financial_balances` | — | SELECT (self) | SELECT, INSERT, UPDATE |
| `financial_transactions` | — | SELECT (self) | SELECT, INSERT |
| `financial_escrow` | — | SELECT (self as payer/payee) | SELECT, INSERT, UPDATE |
| `financial_escrow_milestones` | — | SELECT (via escrow) | SELECT, INSERT, UPDATE |
| `financial_payout_accounts` | — | SELECT (self), INSERT (limited cols) | SELECT, INSERT, UPDATE |
| `financial_payouts` | — | SELECT (self) | SELECT, INSERT, UPDATE |
| `financial_deposits` | — | SELECT (self) | SELECT, INSERT, UPDATE |
| `financial_conversions` | — | SELECT (self) | SELECT, INSERT, UPDATE |
| `financial_audit_trail` | — | SELECT (self), INSERT (self) | SELECT, INSERT |

**Critical column exclusions** (mirrors EP-01 D5 pattern):
- `financial_balances`: `available_balance`, `held_balance`, `pending_balance` are NOT writable by `authenticated` — only service_role or RPCs can mutate balances
- `financial_transactions`: zero INSERT grant to `authenticated` — transactions are created only by RPCs
- `financial_escrow.status`: NOT writable by `authenticated` — state transitions are server-side only
- `financial_payout_accounts.is_verified`, `verified_at`: NOT writable by `authenticated`

RLS policies (self-scoped via `entity_id = auth.uid()`) mirror the EP-01 pattern. Escrow read policies use `(payer_entity_id = auth.uid() OR payee_entity_id = auth.uid())` so both parties can view their escrow.

### 8.4 Trigger Compatibility

`platform_set_updated_at()` attached to mutable tables: `financial_supported_currencies`, `financial_profiles`, `financial_currency_accounts`, `financial_balances`, `financial_escrow`, `financial_escrow_milestones`, `financial_payout_accounts`, `financial_payouts`, `financial_deposits`, `financial_conversions`. Immutable tables (`financial_transactions`, `financial_audit_trail`) have no `updated_at` column and no trigger.

### 8.5 Realtime Exclusion

All 12 new tables excluded from `supabase_realtime` (guarded `DO $$` block, consistent with EP-01-05/06 and EP-02-03 pattern).

### 8.6 Idempotency

- `financial_supported_currencies` seed uses `ON CONFLICT (currency_code) DO NOTHING`.
- DDL is non-destructive (new tables only); re-running the migration is safe in dev.

### 8.7 Posture Audit Compatibility

The existing `008_full_schema_posture_audit.sql` asserts only the original nine tables and no entity/verification SECURITY DEFINER functions. New `financial_%` tables and functions do not affect those assertions. A new `013_financial_schema_posture.sql` adds equivalent assertions for the 12 new tables.

### 8.8 Concurrency & Locking

- **Balance mutations**: Write RPCs use `SELECT ... FOR UPDATE` on the `financial_balances` row before modifying, preventing race conditions on concurrent transactions.
- **Escrow state transitions**: Write RPCs use `SELECT ... FOR UPDATE` on the `financial_escrow` row before transitioning state.
- **Unique constraint race hardening**: Partial unique indexes + exception blocks (matching EP-02-03 `verification_submit` pattern) for `financial_profiles` (one per entity) and `financial_balances` (one per entity/currency).

---

## 9. API Requirements

### 9.1 RPC API Surface (PostgREST `/rpc/`)

| RPC | Access | Volatility | Purpose |
|---|---|---|---|
| `financial_profile_create(p_default_currency char(3) default 'NGN')` | authenticated, service_role | VOLATILE | Create financial profile + auto-create NGN balance |
| `financial_profile_get()` | authenticated (self), service_role | STABLE | Retrieve profile with currency accounts |
| `financial_balance_get(p_currency_code char(3))` | authenticated (self), service_role | STABLE | Currency-specific balance |
| `financial_escrow_create(p_payee_entity_id uuid, p_currency_code char(3), p_total_amount numeric, p_milestones jsonb)` | service_role only | VOLATILE | Create escrow with milestones |
| `financial_escrow_fund(p_escrow_id uuid)` | service_role only | VOLATILE | Fund escrow (payer available → held) |
| `financial_escrow_release(p_escrow_id uuid)` | service_role only | VOLATILE | Full release (payer held → payee available) |
| `financial_escrow_refund(p_escrow_id uuid)` | service_role only | VOLATILE | Refund (payer held → payer available) |
| `financial_escrow_milestone_complete(p_milestone_id uuid)` | service_role only | VOLATILE | Mark milestone completed; auto-release if all done |
| `financial_escrow_get(p_escrow_id uuid)` | authenticated (payer/payee), service_role | STABLE | Escrow with milestones |
| `financial_payout_account_bind(p_currency_code char(3), p_bank_name text, p_account_number text, p_account_name text)` | authenticated, service_role | VOLATILE | Bind bank account |
| `financial_payout_account_verify(p_payout_account_id uuid, p_method text)` | service_role only | VOLATILE | Verify account ownership |
| `financial_withdraw(p_payout_account_id uuid, p_amount numeric)` | authenticated, service_role | VOLATILE | Withdraw to bound account (within KYC limits) |
| `financial_deposit_record(p_entity_id uuid, p_currency_code char(3), p_amount numeric, p_payer_name text, p_external_reference text)` | service_role only | VOLATILE | Record incoming deposit |
| `financial_deposit_verify_name(p_deposit_id uuid)` | service_role only | STABLE | Match payer name vs entity legal name |
| `financial_convert_currency(p_from_currency char(3), p_to_currency char(3), p_amount numeric, p_rate numeric)` | authenticated, service_role | VOLATILE | Convert between balances |
| `financial_status_get()` | authenticated (self), service_role | STABLE | Aggregated financial status |
| `financial_reconcile(p_entity_id uuid, p_currency_code char(3))` | service_role only | STABLE | Verify balance matches ledger |

### 9.2 No REST Endpoints / No Edge Functions

All access via RPC. No custom REST routes or Edge Functions are created in this task. Edge Functions for payment webhooks are EP-02-09 scope.

---

## 10. User Interface Requirements

**None.** This task produces no UI. The financial UIs are EP-02-13/14/15/16.

---

## 11. User Experience Considerations

While server-side only, this schema directly shapes UX downstream:
- **Transparent balances**: `financial_balance_get` and `financial_status_get` let the financial profile screen show available/held/pending per currency without exposing ledger internals
- **Consistent envelope**: all RPCs return `{success, code, message, data}`, simplifying client error handling — PLT006 (insufficient funds) enables clear user feedback
- **Escrow visibility**: `financial_escrow_get` provides both payer and payee with milestone status and release progress
- **Limit awareness**: `financial_withdraw` returns remaining cashout headroom in the response, enabling the UI to show limits proactively
- **Name-match feedback**: `financial_deposit_verify_name` returns match status and score, enabling the UI to flag mismatches before funds are credited

---

## 12. Security Considerations

| Consideration | Approach |
|---|---|
| Zero client-side financial logic | All balance mutations, escrow transitions, limit checks, and name-matching execute inside RPCs — client is purely presentation |
| Balance integrity | `financial_balances` columns are not writable by `authenticated`; mutations occur only inside RPCs with `SELECT ... FOR UPDATE` locking |
| Transaction immutability | `financial_transactions` has zero UPDATE/DELETE grants to any role; no `updated_at` column |
| Audit immutability | `financial_audit_trail` has zero UPDATE/DELETE grants to any role; append-only |
| Escrow state enforcement | `financial_escrow.status` is not writable by `authenticated`; state transitions are validated inside RPCs |
| KYC limit enforcement | `financial_withdraw` calls `verification_limits_get()` to check cashout limit before allowing withdrawal |
| Payout account binding | Withdrawals only to `is_verified = true` payout accounts — unverified accounts are rejected |
| Name-matching enforcement | `financial_deposit_verify_name` compares payer name against `entity_profiles.legal_name` — mismatches are flagged, not silently accepted |
| Default-deny | All 12 tables revoked from `anon`/`authenticated` except the narrow grants above |
| Self-scoping | Entity-facing RPCs enforce `entity_id = auth.uid()` in RLS + explicit check |
| Escrow party scoping | Escrow read policies allow both payer and payee to view; write operations are service-role only |
| No new SECURITY DEFINER | All `financial_%` RPCs are SECURITY INVOKER (posture audit compatible) |
| service-role audit caveat | Service-role RPCs write `financial_audit_trail` directly (not `platform_audit_log_add`) because `auth.uid()` is NULL in service_role context |
| SQL injection | All DML parameterized via PL/pgSQL variable references; no string-built SQL |
| Double-entry integrity | Every transaction has matching debit and credit; `financial_reconcile` verifies balance table matches ledger sum |
| Negative balance prevention | CHECK constraint on `financial_balances` (all ≥ 0) + explicit balance sufficiency check before debit in every write RPC (PLT006) |
| Secrets | No credentials, API keys, or PII in any RPC function body or comment |

---

## 13. Performance Considerations

| Consideration | Approach |
|---|---|
| Balance reads | `financial_balance_get` uses `entity_id + currency_code` unique index — O(1) lookup |
| Transaction history | `financial_transactions_entity_created_idx` supports paginated history queries |
| Escrow queries | `financial_escrow_payer_idx`, `financial_escrow_payee_idx` support entity-scoped escrow lists |
| Balance mutation | Single-row UPDATE on `financial_balances` with `FOR UPDATE` lock — no table locks |
| Escrow state transitions | Single-row UPDATE on `financial_escrow` with `FOR UPDATE` lock |
| Reconciliation | `financial_reconcile` aggregates `financial_transactions` for a given entity/currency — indexed on `entity_id`; efficient even at scale |
| Volatility | Read RPCs `STABLE`; write RPCs `VOLATILE` |
| No N+1 | `financial_status_get` assembles the aggregate in one function with indexed lookups |
| Audit inserts | Append-only, indexed on `created_at`/`entity_id`; negligible overhead per operation |
| Milestone release | `financial_escrow_milestone_complete` checks all milestones in one query; release is a single atomic operation |

---

## 14. Testing Strategy

### 14.1 `013_financial_schema_posture.sql`

| Test | Assertion |
|---|---|
| All 12 tables exist | `has_table` ×12 |
| RLS enabled on all 12 | `relrowsecurity = true` count = 12 |
| anon zero grants on new tables | `role_table_grants` grantee `anon` = 0 |
| `financial_balances` balance columns not writable by `authenticated` | column-grant count = 0 |
| `financial_transactions` no INSERT grant to `authenticated` | column-grant count = 0 |
| `financial_escrow.status` not writable by `authenticated` | column-grant check |
| `financial_payout_accounts.is_verified/verified_at` not writable by `authenticated` | column-grant check |
| `financial_transactions` no UPDATE/DELETE grant to any role | 0 |
| `financial_audit_trail` no UPDATE/DELETE grant to any role | 0 |
| Triggers present on mutable tables (10) | `_set_updated_at` count = 10 |
| No `financial_%` SECURITY DEFINER function | count = 0 |
| Realtime excludes all 12 tables | 0 |
| Comments present on new tables | `obj_description` non-null |
| `financial_supported_currencies` seeded (4 rows) | count = 4 |
| Posture regression | existing `008` assertions unaffected (run full suite) |

### 14.2 `014_financial_rpc_enforcement.sql`

**Authorization:**

| Test | Assertion |
|---|---|
| `anon` cannot call any `financial_%` RPC | `throws_ok` 42501 ×18 |
| `authenticated` cannot call service-role-only RPCs (escrow_create, escrow_fund, escrow_release, escrow_refund, escrow_milestone_complete, payout_account_verify, deposit_record, deposit_verify_name, reconcile) | `throws_ok` 42501 ×9 |
| `authenticated` can call entity-facing RPCs (profile_create, profile_get, balance_get, escrow_get, payout_account_bind, withdraw, convert_currency, status_get) | `lives_ok` ×8 |
| `service_role` can call all 18 RPCs | `lives_ok` ×18 |

**Validation (authenticated / service_role):**

| Test | Assertion |
|---|---|
| `financial_profile_create` with invalid currency code | PLT003 |
| `financial_profile_create` when profile already exists | PLT005 |
| `financial_balance_get` with unsupported currency | PLT004 |
| `financial_escrow_create` with zero/negative amount | PLT003 |
| `financial_escrow_create` with milestone sum ≠ total_amount | PLT003 |
| `financial_escrow_fund` with non-existent escrow | PLT004 |
| `financial_escrow_fund` with already-funded escrow | PLT005 |
| `financial_escrow_fund` with insufficient payer balance | PLT006 |
| `financial_escrow_release` with unfunded escrow | PLT005 |
| `financial_escrow_refund` with unfunded escrow | PLT005 |
| `financial_withdraw` with unverified payout account | PLT003 |
| `financial_withdraw` exceeding KYC cashout limit | PLT006 |
| `financial_withdraw` with insufficient available balance | PLT006 |
| `financial_convert_currency` with same from/to currency | PLT003 |
| `financial_convert_currency` with insufficient source balance | PLT006 |
| `financial_payout_account_bind` with duplicate account | PLT005 |
| `financial_deposit_record` with zero/negative amount | PLT003 |

**Functional / Double-Entry:**

| Test | Assertion |
|---|---|
| `financial_profile_create` → profile + NGN balance row created | envelope `success`; both rows exist |
| `financial_escrow_create` → escrow + milestones created | milestones count matches input |
| `financial_escrow_fund` → payer available debited, payer held credited; transaction row exists with correct debit/credit types | balance change verified; transaction row verified |
| `financial_escrow_release` → payer held debited, payee available credited; released_amount updated | balance change verified |
| `financial_escrow_refund` → payer held debited, payer available credited; refunded_amount updated | balance change verified |
| `financial_escrow_milestone_complete` → milestone status `completed`; if all milestones done, auto-release | milestone status verified; escrow status verified |
| Partial release: release one milestone → `partially_released` status; release remaining → `released` | state transitions verified |
| `financial_withdraw` → available balance debited; payout record created | balance change + payout row |
| `financial_deposit_record` → deposit record created; if name matches, credited to available balance | balance change + deposit row |
| `financial_deposit_verify_name` → matching name returns `matched`; mismatching returns `mismatched` | name match status verified |
| `financial_convert_currency` → source balance debited, destination balance credited; conversion record created | double-entry verified |
| `financial_reconcile` → returns `true` when balances match ledger sum | reconciliation verified |
| `financial_reconcile` → returns `false` when manually tampered balance doesn't match ledger | tamper detection verified |
| `financial_status_get` → returns aggregated balances, active escrow count, KYC limits | data completeness verified |

**Envelope contract:** all RPCs return `{success, code, message, data}`; success code `PLT000`.

### 14.3 Regression

Run full suite `001`–`014`. Confirm `008` (entity-model posture), `009`/`010` (taxonomy), `011`/`012` (verification) still pass — no prior table altered.

---

## 15. Recommended Implementation Sequence

| Step | Action | Output |
|---|---|---|
| 1 | Create migration file `<timestamp>_financial_integrity_schema.sql` | Scaffold |
| 2 | Header comment block (EP-02-04, execution model, envelope, double-entry model, grant strategy) | Docs |
| 3 | DDL: `financial_supported_currencies` (constraints, indexes, trigger, comment) | Reference table |
| 4 | Idempotent currency seed (NGN, GHS, USD, GBP) | Seed |
| 5 | DDL: `financial_profiles` (FK, unique, trigger, comment) | Table |
| 6 | DDL: `financial_currency_accounts` (FK, unique, indexes, trigger, comment) | Table |
| 7 | DDL: `financial_balances` (FK, unique, CHECK non-negative, indexes, trigger, comment) | Table |
| 8 | DDL: `financial_transactions` (FK, CHECK positive, indexes, comment — immutable) | Table |
| 9 | DDL: `financial_escrow` (FK, CHECK amount integrity, indexes, trigger, comment) | Table |
| 10 | DDL: `financial_escrow_milestones` (FK, unique, indexes, trigger, comment) | Table |
| 11 | DDL: `financial_payout_accounts` (FK, unique, indexes, trigger, comment) | Table |
| 12 | DDL: `financial_payouts` (FK, indexes, trigger, comment) | Table |
| 13 | DDL: `financial_deposits` (FK, indexes, trigger, comment) | Table |
| 14 | DDL: `financial_conversions` (FK, CHECK from≠to, indexes, trigger, comment) | Table |
| 15 | DDL: `financial_audit_trail` (FK, indexes, comment — immutable) | Table |
| 16 | RLS enable + revoke + per-table grants + self-scoped policies | Security |
| 17 | Implement `financial_profile_create` (auth, dedup, auto-create NGN balance, audit) | RPC |
| 18 | Implement `financial_profile_get`, `financial_balance_get` (auth, self-scope) | RPCs |
| 19 | Implement `financial_escrow_create` (service-role, validate milestones, audit) | RPC |
| 20 | Implement `financial_escrow_fund` (service-role, balance check, double-entry, FOR UPDATE, audit) | RPC |
| 21 | Implement `financial_escrow_release` (service-role, state check, double-entry, FOR UPDATE, audit) | RPC |
| 22 | Implement `financial_escrow_refund` (service-role, state check, double-entry, FOR UPDATE, audit) | RPC |
| 23 | Implement `financial_escrow_milestone_complete` (service-role, auto-release logic, audit) | RPC |
| 24 | Implement `financial_escrow_get` (auth, payer/payee scope) | RPC |
| 25 | Implement `financial_payout_account_bind` (auth, dedup, audit) | RPC |
| 26 | Implement `financial_payout_account_verify` (service-role, audit) | RPC |
| 27 | Implement `financial_withdraw` (auth, KYC limit check, verified account check, double-entry, audit) | RPC |
| 28 | Implement `financial_deposit_record` (service-role, auto name-match trigger, double-entry, audit) | RPC |
| 29 | Implement `financial_deposit_verify_name` (service-role, compare against `entity_profiles.legal_name`) | RPC |
| 30 | Implement `financial_convert_currency` (auth, balance check, double-entry, conversion record, audit) | RPC |
| 31 | Implement `financial_status_get` (auth, self-scope, aggregated data) | RPC |
| 32 | Implement `financial_reconcile` (service-role, sum transactions vs balance) | RPC |
| 33 | `revoke execute on all functions in schema public from public` + specific EXECUTE grants | Authz |
| 34 | `comment on function` for all 18 RPCs | Docs |
| 35 | Realtime exclusion `DO $$` block for 12 tables | Security |
| 36 | Create `013_financial_schema_posture.sql` | Test |
| 37 | Create `014_financial_rpc_enforcement.sql` | Test |
| 38 | `supabase db push` (or `supabase db reset`) | Migrate |
| 39 | `supabase db test` — all new + existing pass | Verify |

---

## 16. Expected Outcome

- 12 financial tables deployed with full RLS (default-deny), triggers, indexes, comments, Realtime exclusion
- `financial_supported_currencies` seeded with 4 currencies (NGN, GHS, USD, GBP)
- 18 RPCs deployed; entity-facing RPCs self-scoped and authenticated; system/internal RPCs service-role-only
- Double-entry accounting enforced: every balance mutation produces a matching transaction row with explicit debit/credit types
- Escrow lifecycle fully operational: create → fund → milestone complete → release/refund with atomic balance updates
- Payout accounts bindable with name verification; withdrawals restricted to verified accounts within KYC limits
- Deposit recording with payer name capture and name-matching against `entity_profiles.legal_name`
- Currency conversion between supported balances with audit trail
- `financial_reconcile` verifies balance table matches transaction ledger sum — tamper detection
- No `financial_%` SECURITY DEFINER function; no prior table altered
- pgTAP `013` + `014` pass; full suite (`001`–`014`) green
- EP-02-05, EP-02-13, EP-02-14, EP-02-15, EP-02-16 unblocked with a real financial engine

---

## 17. Definition of Done (DoD)

| # | Criterion | Verification Method |
|---|---|---|
| 1 | Migration file exists with correct naming/ordering after `20260829090003` | File inspection |
| 2 | 12 tables created: `financial_supported_currencies`, `financial_profiles`, `financial_currency_accounts`, `financial_balances`, `financial_transactions`, `financial_escrow`, `financial_escrow_milestones`, `financial_payout_accounts`, `financial_payouts`, `financial_deposits`, `financial_conversions`, `financial_audit_trail` | `has_table` ×12 |
| 3 | All 12 tables have RLS enabled | `relrowsecurity` check |
| 4 | `anon` has zero grants on the 12 new tables | `role_table_grants` query |
| 5 | `financial_balances` balance columns not writable by `authenticated` | column-grant assertion |
| 6 | `financial_transactions` no INSERT grant to `authenticated` | column-grant assertion |
| 7 | `financial_escrow.status` not writable by `authenticated` | column-grant check |
| 8 | `financial_payout_accounts.is_verified/verified_at` not writable by `authenticated` | column-grant check |
| 9 | `financial_transactions` and `financial_audit_trail` have no UPDATE/DELETE grant to any role | grant query |
| 10 | `financial_supported_currencies` seeded with 4 currencies via idempotent insert | `select count(*) from financial_supported_currencies` = 4 |
| 11 | 18 RPC functions exist, all SECURITY INVOKER | `pg_proc` query (prosecdef = 0) |
| 12 | Service-role-only RPCs EXECUTE-granted to `service_role` only | grant inspection |
| 13 | `anon` cannot call any RPC (42501) | pgTAP `throws_ok` |
| 14 | `authenticated` cannot call service-role-only RPCs (42501) | pgTAP `throws_ok` |
| 15 | `financial_profile_create` enforces dedup (PLT005) and valid currency (PLT003) | pgTAP |
| 16 | `financial_escrow_fund` with insufficient balance raises PLT006 | pgTAP |
| 17 | `financial_escrow_fund` → payer available debited, held credited; transaction row exists | pgTAP (double-entry) |
| 18 | `financial_escrow_release` → payer held debited, payee available credited | pgTAP (double-entry) |
| 19 | `financial_escrow_refund` → payer held debited, payer available credited | pgTAP (double-entry) |
| 20 | Milestone completion triggers auto-release when all milestones done | pgTAP |
| 21 | `financial_withdraw` enforces KYC cashout limit (PLT006) and verified account (PLT003) | pgTAP |
| 22 | `financial_deposit_verify_name` returns `matched` for matching name, `mismatched` for different name | pgTAP |
| 23 | `financial_convert_currency` produces double-entry transaction pair + conversion record | pgTAP |
| 24 | `financial_reconcile` returns true when balances match ledger; false when tampered | pgTAP |
| 25 | All RPCs return `{success, code, message, data}` envelope | envelope assertion |
| 26 | No DDL alters any EP-01 / EP-02-01/02/03 table | migration review |
| 27 | Realtime excludes the 12 new tables | publication query |
| 28 | No SECURITY DEFINER `financial_%` function | `pg_proc` query |
| 29 | pgTAP `013` + `014` exist and pass | `supabase db test` |
| 30 | Full suite `001`–`014` passes (no regression to `008`/`009`/`010`/`011`/`012`) | `supabase db test` |
| 31 | Migration header + `comment on function` for all 18 RPCs | code review |
| 32 | No client-side files created under `lib/` | file inspection |
| 33 | EP-02-05/13/14/15/16 unblocked | dependency check |

---

## 18. Implementation AI Execution Profile

| Attribute | Recommendation |
|---|---|
| **Recommended Coding Reasoning Level** | **Extremely High** |
| **Reasoning Level Justification** | This task requires Extremely High reasoning, matching the EP-02 Phase Plan assignment, due to converging catastrophic-risk factors: **(1) Financial impact** — this is the most architecturally significant item in EP-02; incorrect schema design propagates financial risk to every marketplace phase (EP-03 through EP-08); the phase plan explicitly labels incorrect design as "catastrophic." **(2) Data complexity** — 12 interrelated tables with a double-entry accounting model requiring careful debit/credit type design, balance invariant enforcement (CHECK ≥ 0 + reconciliation), escrow state machine with 7 states and valid/invalid transitions, milestone-based partial release logic, and multi-currency support across all tables. **(3) Security risk** — all balance mutations must be server-side only; `financial_balances` columns must be excluded from `authenticated` grants; escrow state transitions must be service-role-only; payout accounts must enforce verified-only withdrawals; 18 RPCs across 3 authorization tiers (anon/authenticated/service_role) with precise EXECUTE grants. **(4) Integration complexity** — the schema must correctly reference `entity_profiles.legal_name` for name-matching, `entity_kyc_levels`/`kyc_tiers` for limit enforcement, and `entities(id)` for FK integrity; the service-role `auth.uid()` audit caveat must be handled consistently with EP-02-03; the new PLT006 error code must extend the existing error vocabulary without conflict. **(5) Concurrency** — balance mutations require `SELECT ... FOR UPDATE` locking; escrow state transitions require atomic state checks; race-condition hardening (unique constraint + exception mapping) must match the EP-02-03 pattern. **(6) Test complexity** — the pgTAP suite must prove double-entry integrity across escrow fund/release/refund, balance consistency, milestone auto-release, KYC limit enforcement, name-matching accuracy, reconciliation tamper detection, and three authorization roles × 18 RPCs. The combination of financial-critical server-side enforcement, double-entry accounting, multi-table state machines, and downstream dependency from 5+ tasks places this squarely at Extremely High. |
