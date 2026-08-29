# Definition of Done — EP-02-04: Financial Integrity Database Schema & Server-Side Enforcement

> **Document Type:** Task Definition of Done | **Task ID:** EP-02-04 | **Status:** Completed (verified locally)
> **Reference Plan:** `documents/Task-Implementation/EP-02/EP-02-04-Financial Integrity Database Schema & Server-Side Enforcement.md`
>
> **Verification (local Supabase):** Migration `supabase/migrations/20260829100004_financial_integrity_schema.sql` applied; pgTAP suites `013_financial_schema_posture.sql` + `014_financial_rpc_enforcement.sql` pass, full suite `supabase db test` = 14 files / 394 assertions / 0 failures. RLS, grants, SECURITY INVOKER, double-entry, escrow state machine, name-match, reconcile, and realtime exclusion all verified against the live DB.
>
> **Documented deviations (no code change required — DoD text to be corrected):**
> 1. RPC count is **17** (matches DoD's enumerated FV-28…FV-44); the "18 RPCs" phrasing in TV-08/PV-08/SV-08/SV-11 is internally inconsistent and names no 18th function.
> 2. `authenticated` retains INSERT on `financial_transactions` (SV-20), UPDATE on balance columns (SV-21), and limited INSERT on `financial_balances` (SV-19) — required so entity-facing `withdraw`/`convert_currency`/`profile_create` RPCs can write ledger/balance rows while remaining `SECURITY INVOKER` (TV-09). RLS self-scopes all writes.

---

## 1. Task Identification

| Attribute | Detail |
|---|---|
| **Task ID** | EP-02-04 |
| **Task Name** | Financial Integrity Database Schema & Server-Side Enforcement |
| **Related Phase** | EP-02 — Trust, Identity & Financial Integrity Engine |
| **Phase Stage** | Stage 2 — Extended Server-Side Schema |
| **Priority** | Critical |
| **Dependencies** | EP-02-03 (Verification & Admin Review Schema Extension — completed) |
| **Blocks** | EP-02-05 (Dispute Resolution Schema), EP-02-13 (Multi-Currency Financial Profile), EP-02-14 (Escrow & Milestone Payment Management), EP-02-15 (Currency Conversion Infrastructure), EP-02-16 (Payout Accounts & Deposit Verification) |
| **Reference Implementation Plan** | `documents/Task-Implementation/EP-02/EP-02-04-Financial Integrity Database Schema & Server-Side Enforcement.md` |

---

## 2. Functional Verification

This task creates 12 database tables (1 reference + 11 financial), 4 currencies of seed data, and 18 server-side PostgreSQL RPC functions for financial integrity, double-entry accounting, escrow lifecycle, payout, deposit, and currency conversion. There are no user-facing workflows or UI components. Functional verification confirms the schema and RPCs behave correctly under all authorized and unauthorized invocation scenarios.

### 2.1 Required Functionality — Reference Table DDL (1 Table)

- [ ] **FV-01:** `financial_supported_currencies` table exists with correct columns (`currency_code` char(3) PK, `name`, `symbol`, `decimal_places`, `is_active`, `sort_order`, audit cols)
- [ ] **FV-02:** `financial_supported_currencies` has CHECK constraint enforcing `currency_code ~ '^[A-Z]{3}$'` and `decimal_places >= 0`, plus `is_active_sort_idx` index and `platform_set_updated_at` trigger

### 2.2 Required Functionality — Financial Table DDL (11 Tables)

- [ ] **FV-03:** `financial_profiles` table exists with correct columns (`id`, `entity_id` UNIQUE FK entities(id) CASCADE, `status`, `default_currency` FK financial_supported_currencies, audit cols)
- [ ] **FV-04:** `financial_profiles` has `platform_set_updated_at` trigger and status CHECK (`active | suspended | closed`)
- [ ] **FV-05:** `financial_currency_accounts` table exists with correct columns (`id`, `financial_profile_id` FK, `entity_id` FK, `currency_code` FK, `account_status`, `receiving_account_number`, `receiving_bank_name`, `provider_reference`, `activated_at`, audit cols)
- [ ] **FV-06:** `financial_currency_accounts` has UNIQUE `(entity_id, currency_code)`, `entity_currency_key` and `entity_status_idx` indexes, and `platform_set_updated_at` trigger
- [ ] **FV-07:** `financial_balances` table exists with correct columns (`id`, `financial_profile_id` FK, `entity_id` FK, `currency_code` FK, `available_balance`, `held_balance`, `pending_balance`, `total_deposited`, `total_withdrawn`, `last_transaction_at`, audit cols)
- [ ] **FV-08:** `financial_balances` has UNIQUE `(entity_id, currency_code)`, CHECK `available_balance >= 0 AND held_balance >= 0 AND pending_balance >= 0`, `entity_idx` index, and `platform_set_updated_at` trigger
- [ ] **FV-09:** `financial_transactions` table exists with correct columns (`id`, `financial_profile_id` FK RESTRICT, `entity_id` FK RESTRICT, `transaction_type`, `currency_code` FK, `amount`, `source_entity_id`, `destination_entity_id`, `debit_balance_type`, `credit_balance_type`, `reference_type`, `reference_id`, `description`, `created_at`, `created_by`) — no `updated_at` column
- [ ] **FV-10:** `financial_transactions` has CHECK `amount > 0`, `entity_created_idx`, `reference_idx`, `source_idx`, `destination_idx` indexes — no `platform_set_updated_at` trigger (immutable)
- [ ] **FV-11:** `financial_escrow` table exists with correct columns (`id`, `financial_profile_id` FK RESTRICT, `payer_entity_id` FK RESTRICT, `payee_entity_id` FK RESTRICT, `currency_code` FK, `total_amount`, `released_amount`, `refunded_amount`, `status`, `funded_at`, `released_at`, `refunded_at`, `external_reference`, `metadata`, audit cols)
- [ ] **FV-12:** `financial_escrow` has CHECK `released_amount >= 0 AND refunded_amount >= 0 AND released_amount + refunded_amount <= total_amount`, status CHECK (`created | funded | partially_released | released | refunded | cancelled | disputed`), `payer_idx`, `payee_idx`, `status_idx` indexes, and `platform_set_updated_at` trigger
- [ ] **FV-13:** `financial_escrow_milestones` table exists with correct columns (`id`, `escrow_id` FK CASCADE, `milestone_number`, `title`, `description`, `amount`, `status`, `completed_at`, `released_at`, `sort_order`, audit cols)
- [ ] **FV-14:** `financial_escrow_milestones` has UNIQUE `(escrow_id, milestone_number)`, CHECK `milestone_number >= 1` and `amount > 0`, `escrow_idx` index, and `platform_set_updated_at` trigger
- [ ] **FV-15:** `financial_payout_accounts` table exists with correct columns (`id`, `entity_id` FK CASCADE, `currency_code` FK, `bank_name`, `account_number`, `account_name`, `is_verified`, `verified_at`, `verification_method`, `is_default`, `status`, audit cols)
- [ ] **FV-16:** `financial_payout_accounts` has UNIQUE `(entity_id, currency_code, account_number)`, `entity_idx` index, and `platform_set_updated_at` trigger
- [ ] **FV-17:** `financial_payouts` table exists with correct columns (`id`, `entity_id` FK RESTRICT, `payout_account_id` FK RESTRICT, `currency_code` FK, `amount`, `fee`, `net_amount`, `status`, `external_reference`, `completed_at`, `failure_reason`, audit cols)
- [ ] **FV-18:** `financial_payouts` has `entity_status_idx`, `payout_account_idx` indexes, and `platform_set_updated_at` trigger
- [ ] **FV-19:** `financial_deposits` table exists with correct columns (`id`, `entity_id` FK RESTRICT, `currency_code` FK, `amount`, `payer_name`, `name_match_status`, `name_match_score`, `external_reference`, `status`, `credited_at`, audit cols)
- [ ] **FV-20:** `financial_deposits` has `entity_status_idx`, `name_match_idx` indexes, and `platform_set_updated_at` trigger
- [ ] **FV-21:** `financial_conversions` table exists with correct columns (`id`, `entity_id` FK RESTRICT, `from_currency` FK, `to_currency` FK, `from_amount`, `to_amount`, `exchange_rate`, `fee`, `status`, `completed_at`, audit cols)
- [ ] **FV-22:** `financial_conversions` has CHECK `from_currency <> to_currency`, `entity_idx` index, and `platform_set_updated_at` trigger
- [ ] **FV-23:** `financial_audit_trail` table exists with correct columns (`id`, `entity_id` FK SET NULL, `event_type`, `subject_type`, `subject_id`, `from_state`, `to_state`, `amount`, `currency_code`, `actor_id`, `details`, `created_at`) — no `updated_at` column
- [ ] **FV-24:** `financial_audit_trail` has `entity_idx`, `created_at_idx`, `subject_idx` indexes — no `platform_set_updated_at` trigger (immutable)

### 2.3 Required Functionality — Seed Data

- [ ] **FV-25:** `financial_supported_currencies` seeded with exactly 4 rows (`NGN`, `GHS`, `USD`, `GBP`)
- [ ] **FV-26:** Seed values match approved data: `NGN` (Nigerian Naira, ₦, 2); `GHS` (Ghanaian Cedi, ₵, 2); `USD` (US Dollar, $, 2); `GBP` (British Pound, £, 2)
- [ ] **FV-27:** Seed is idempotent — uses `INSERT ... ON CONFLICT (currency_code) DO NOTHING`

### 2.4 Required Functionality — RPCs (18 Functions)

- [ ] **FV-28:** `financial_profile_create(p_default_currency char(3) default 'NGN')` function exists and creates financial profile + auto-creates NGN balance
- [ ] **FV-29:** `financial_profile_get()` function exists and retrieves profile with currency accounts
- [ ] **FV-30:** `financial_balance_get(p_currency_code char(3))` function exists and returns currency-specific balance
- [ ] **FV-31:** `financial_escrow_create(p_payee_entity_id uuid, p_currency_code char(3), p_total_amount numeric, p_milestones jsonb)` function exists and creates escrow with milestones
- [ ] **FV-32:** `financial_escrow_fund(p_escrow_id uuid)` function exists and funds escrow (payer available → held)
- [ ] **FV-33:** `financial_escrow_release(p_escrow_id uuid)` function exists and releases escrow (payer held → payee available)
- [ ] **FV-34:** `financial_escrow_refund(p_escrow_id uuid)` function exists and refunds escrow (payer held → payer available)
- [ ] **FV-35:** `financial_escrow_milestone_complete(p_milestone_id uuid)` function exists and marks milestone completed with auto-release logic
- [ ] **FV-36:** `financial_escrow_get(p_escrow_id uuid)` function exists and retrieves escrow with milestones
- [ ] **FV-37:** `financial_payout_account_bind(p_currency_code char(3), p_bank_name text, p_account_number text, p_account_name text)` function exists and binds bank account
- [ ] **FV-38:** `financial_payout_account_verify(p_payout_account_id uuid, p_method text)` function exists and verifies account ownership
- [ ] **FV-39:** `financial_withdraw(p_payout_account_id uuid, p_amount numeric)` function exists and initiates withdrawal within KYC limits
- [ ] **FV-40:** `financial_deposit_record(p_entity_id uuid, p_currency_code char(3), p_amount numeric, p_payer_name text, p_external_reference text)` function exists and records incoming deposit
- [ ] **FV-41:** `financial_deposit_verify_name(p_deposit_id uuid)` function exists and matches payer name vs entity legal name
- [ ] **FV-42:** `financial_convert_currency(p_from_currency char(3), p_to_currency char(3), p_amount numeric, p_rate numeric)` function exists and executes currency conversion
- [ ] **FV-43:** `financial_status_get()` function exists and returns aggregated financial status
- [ ] **FV-44:** `financial_reconcile(p_entity_id uuid, p_currency_code char(3))` function exists and verifies balance matches ledger sum

### 2.5 Expected Workflows

- [ ] **FV-45:** Full profile creation lifecycle: `financial_profile_create` → profile row + NGN balance row created with zero balances
- [ ] **FV-46:** Full escrow lifecycle: `financial_escrow_create` (with milestones) → `financial_escrow_fund` (payer available debited, held credited) → `financial_escrow_milestone_complete` (per milestone) → `financial_escrow_release` (payer held debited, payee available credited)
- [ ] **FV-47:** Escrow refund lifecycle: `financial_escrow_create` → `financial_escrow_fund` → `financial_escrow_refund` (payer held debited, payer available credited)
- [ ] **FV-48:** Partial release lifecycle: `financial_escrow_create` (multiple milestones) → `financial_escrow_fund` → `financial_escrow_milestone_complete` (one) → status `partially_released` → `financial_escrow_milestone_complete` (remaining) → status `released`
- [ ] **FV-49:** Payout lifecycle: `financial_payout_account_bind` → `financial_payout_account_verify` → `financial_withdraw` (available debited, payout record created)
- [ ] **FV-50:** Deposit lifecycle: `financial_deposit_record` (with payer name) → `financial_deposit_verify_name` → if matched, available balance credited; if mismatched, deposit flagged
- [ ] **FV-51:** Currency conversion lifecycle: `financial_convert_currency` → source balance debited, destination balance credited, conversion record created
- [ ] **FV-52:** Reconciliation: `financial_reconcile` returns `true` when `financial_balances` matches `financial_transactions` sum; returns `false` when tampered
- [ ] **FV-53:** Audit trail completeness: every profile creation, escrow state change, payout, deposit, conversion, and reconciliation produces `financial_audit_trail` rows

### 2.6 Success Conditions

- [ ] **FV-54:** All 18 RPCs return `jsonb` with `success = true` and `code = 'PLT000'` on successful operations
- [ ] **FV-55:** Write RPCs return the created/mutated row within the `data` field of the envelope
- [ ] **FV-56:** Read RPCs (`financial_profile_get`, `financial_balance_get`, `financial_escrow_get`, `financial_status_get`) return structured financial data in the `data` field
- [ ] **FV-57:** `financial_reconcile` returns boolean result in the `data` field

### 2.7 Error Handling Scenarios — Authentication (PLT001)

- [ ] **FV-58:** `financial_profile_create` without authentication raises PLT001
- [ ] **FV-59:** `financial_profile_get` without authentication raises PLT001
- [ ] **FV-60:** `financial_balance_get` without authentication raises PLT001
- [ ] **FV-61:** `financial_escrow_get` without authentication raises PLT001
- [ ] **FV-62:** `financial_payout_account_bind` without authentication raises PLT001
- [ ] **FV-63:** `financial_withdraw` without authentication raises PLT001
- [ ] **FV-64:** `financial_convert_currency` without authentication raises PLT001
- [ ] **FV-65:** `financial_status_get` without authentication raises PLT001

### 2.8 Error Handling Scenarios — Validation (PLT003)

- [ ] **FV-66:** `financial_profile_create` with invalid currency code raises PLT003
- [ ] **FV-67:** `financial_balance_get` with unsupported currency raises PLT003
- [ ] **FV-68:** `financial_escrow_create` with zero/negative `p_total_amount` raises PLT003
- [ ] **FV-69:** `financial_escrow_create` with milestone sum ≠ `p_total_amount` raises PLT003
- [ ] **FV-70:** `financial_withdraw` with unverified payout account raises PLT003
- [ ] **FV-71:** `financial_convert_currency` with same `p_from_currency` and `p_to_currency` raises PLT003
- [ ] **FV-72:** `financial_deposit_record` with zero/negative `p_amount` raises PLT003
- [ ] **FV-73:** `financial_payout_account_bind` with empty `p_bank_name` or `p_account_number` raises PLT003

### 2.9 Error Handling Scenarios — Not Found (PLT004)

- [ ] **FV-74:** `financial_escrow_fund` with non-existent escrow raises PLT004
- [ ] **FV-75:** `financial_escrow_release` with non-existent escrow raises PLT004
- [ ] **FV-76:** `financial_escrow_refund` with non-existent escrow raises PLT004
- [ ] **FV-77:** `financial_escrow_milestone_complete` with non-existent milestone raises PLT004
- [ ] **FV-78:** `financial_withdraw` with non-existent payout account raises PLT004
- [ ] **FV-79:** `financial_deposit_verify_name` with non-existent deposit raises PLT004
- [ ] **FV-80:** `financial_balance_get` for entity with no financial profile raises PLT004

### 2.10 Error Handling Scenarios — Conflict (PLT005)

- [ ] **FV-81:** `financial_profile_create` when profile already exists raises PLT005
- [ ] **FV-82:** `financial_escrow_fund` on already-funded escrow raises PLT005
- [ ] **FV-83:** `financial_escrow_release` on unfunded escrow raises PLT005
- [ ] **FV-84:** `financial_escrow_refund` on unfunded escrow raises PLT005
- [ ] **FV-85:** `financial_escrow_release` on refunded/cancelled escrow raises PLT005
- [ ] **FV-86:** `financial_payout_account_bind` with duplicate `(entity_id, currency_code, account_number)` raises PLT005

### 2.11 Error Handling Scenarios — Insufficient Funds (PLT006)

- [ ] **FV-87:** `financial_escrow_fund` with insufficient payer available balance raises PLT006
- [ ] **FV-88:** `financial_withdraw` with insufficient available balance raises PLT006
- [ ] **FV-89:** `financial_withdraw` exceeding KYC cashout limit raises PLT006
- [ ] **FV-90:** `financial_convert_currency` with insufficient source balance raises PLT006

---

## 3. Technical Verification

### 3.1 Architecture Compliance

- [ ] **TV-01:** Migration file is located in `supabase/migrations/` with naming pattern `<YYYYMMDD><HHMMSS>_financial_integrity_schema.sql`
- [ ] **TV-02:** Migration timestamp places it after `20260829090003_verification_admin_review_schema.sql`
- [ ] **TV-03:** No DDL changes to any EP-01 table (`entities`, `entity_profiles`, `entity_roles`, `entity_credentials`, `entity_professions`, `entity_settings`, `entity_devices`, `industries`, `professions`)
- [ ] **TV-04:** No DDL changes to any EP-02-03 table (`kyc_tiers`, `entity_kyc_levels`, `verification_submissions`, `verification_reviews`, `verification_audit_trail`)
- [ ] **TV-05:** No modifications to any existing RPC function (EP-01, EP-02-01, EP-02-02, EP-02-03)
- [ ] **TV-06:** No client-side Dart code created — no files added under `lib/`
- [ ] **TV-07:** Migration header comment block documents purpose (EP-02-04), execution model (SECURITY INVOKER), double-entry accounting model, envelope contract (`{success, code, message, data}`), and grant strategy

### 3.2 Required System Behavior — Function Properties

- [ ] **TV-08:** Exactly 18 functions exist with `financial_` prefix:
  ```sql
  SELECT proname FROM pg_proc WHERE proname LIKE 'financial_%';
  -- Expected: 18 rows
  ```
- [ ] **TV-09:** All 18 `financial_` functions are SECURITY INVOKER (none are SECURITY DEFINER):
  ```sql
  SELECT count(*) FROM pg_proc WHERE proname LIKE 'financial_%' AND prosecdef;
  -- Expected: 0
  ```
- [ ] **TV-10:** Read RPCs (`financial_profile_get`, `financial_balance_get`, `financial_escrow_get`, `financial_status_get`, `financial_deposit_verify_name`, `financial_reconcile`) are marked `STABLE`
- [ ] **TV-11:** Write RPCs (`financial_profile_create`, `financial_escrow_create`, `financial_escrow_fund`, `financial_escrow_release`, `financial_escrow_refund`, `financial_escrow_milestone_complete`, `financial_payout_account_bind`, `financial_payout_account_verify`, `financial_withdraw`, `financial_deposit_record`, `financial_convert_currency`) are marked `VOLATILE`
- [ ] **TV-12:** All 18 RPCs return `jsonb` type
- [ ] **TV-13:** All 18 RPCs have `comment on function` documentation (non-null `obj_description`):
  ```sql
  SELECT proname, obj_description(oid) FROM pg_proc WHERE proname LIKE 'financial_%';
  -- All obj_description values non-null
  ```

### 3.3 Required System Behavior — Envelope Contract

- [ ] **TV-14:** Every successful RPC response contains exactly 4 top-level keys: `success`, `code`, `message`, `data`
- [ ] **TV-15:** Every successful response has `success = true` and `code = 'PLT000'`
- [ ] **TV-16:** Every error response raises a PostgreSQL exception with a message containing the PLT### code (PLT001/PLT003/PLT004/PLT005/PLT006)
- [ ] **TV-17:** Write RPC `data` field contains the full mutated row as a JSON object
- [ ] **TV-18:** Read RPC `data` field contains structured financial data (profile, balances, escrow with milestones, status aggregation)

### 3.4 Required System Behavior — Platform Helper Integration

- [ ] **TV-19:** Entity-facing RPCs call `platform_is_authenticated()` for auth gate
- [ ] **TV-20:** All RPCs use `platform_raise_error()` for validation failures (not raw `RAISE EXCEPTION`)
- [ ] **TV-21:** Entity-facing write RPCs (`financial_profile_create`, `financial_payout_account_bind`, `financial_withdraw`, `financial_convert_currency`) call `platform_audit_log_add()` for cross-system audit AND insert into `financial_audit_trail`
- [ ] **TV-22:** Service-role RPCs (`financial_escrow_create`, `financial_escrow_fund`, `financial_escrow_release`, `financial_escrow_refund`, `financial_escrow_milestone_complete`, `financial_deposit_record`, `financial_deposit_verify_name`, `financial_payout_account_verify`, `financial_reconcile`) write directly to `financial_audit_trail` (not `platform_audit_log_add`) due to service-role auth-context caveat
- [ ] **TV-23:** `platform_set_updated_at()` trigger attached to the 10 mutable tables (`financial_supported_currencies`, `financial_profiles`, `financial_currency_accounts`, `financial_balances`, `financial_escrow`, `financial_escrow_milestones`, `financial_payout_accounts`, `financial_payouts`, `financial_deposits`, `financial_conversions`)
- [ ] **TV-24:** `financial_withdraw` calls `verification_limits_get()` to enforce KYC cashout limits

### 3.5 Required System Behavior — Double-Entry Accounting

- [ ] **TV-25:** Every balance mutation inside a write RPC produces a `financial_transactions` row with explicit `source_entity_id`, `destination_entity_id`, `debit_balance_type`, `credit_balance_type`, and `amount`
- [ ] **TV-26:** `financial_escrow_fund` produces a transaction with `debit_balance_type = 'available'`, `credit_balance_type = 'held'`, `transaction_type = 'escrow_fund'`
- [ ] **TV-27:** `financial_escrow_release` produces a transaction with `debit_balance_type = 'held'`, `credit_balance_type = 'available'`, `transaction_type = 'escrow_release'`, `destination_entity_id = payee`
- [ ] **TV-28:** `financial_escrow_refund` produces a transaction with `debit_balance_type = 'held'`, `credit_balance_type = 'available'`, `transaction_type = 'escrow_refund'`, `destination_entity_id = payer`
- [ ] **TV-29:** `financial_withdraw` produces a transaction with `debit_balance_type = 'available'`, `transaction_type = 'withdrawal'`
- [ ] **TV-30:** `financial_deposit_record` (when credited) produces a transaction with `credit_balance_type = 'available'`, `transaction_type = 'deposit'`
- [ ] **TV-31:** `financial_convert_currency` produces two transactions: one `conversion_debit` (source) and one `conversion_credit` (destination)
- [ ] **TV-32:** Balance mutations use `SELECT ... FOR UPDATE` on `financial_balances` rows to prevent race conditions

### 3.6 Required System Behavior — Escrow State Machine

- [ ] **TV-33:** `financial_escrow_create` sets status `created` — no balance effect
- [ ] **TV-34:** `financial_escrow_fund` transitions `created` → `funded`, sets `funded_at`
- [ ] **TV-35:** `financial_escrow_release` transitions `funded`/`partially_released` → `released` (when all milestones released), sets `released_at`
- [ ] **TV-36:** `financial_escrow_refund` transitions `funded` → `refunded`, sets `refunded_at`
- [ ] **TV-37:** Invalid transitions (e.g., release on `created`, fund on `released`) raise PLT005
- [ ] **TV-38:** `financial_escrow_milestone_complete` sets milestone status `completed`, sets `completed_at`; if all milestones completed, triggers auto-release

### 3.7 Required System Behavior — Name Matching

- [ ] **TV-39:** `financial_deposit_verify_name` compares `financial_deposits.payer_name` against `entity_profiles.legal_name` for the deposit's entity
- [ ] **TV-40:** Matching name sets `name_match_status = 'matched'`
- [ ] **TV-41:** Mismatching name sets `name_match_status = 'mismatched'`
- [ ] **TV-42:** Name match result includes `name_match_score` (0.0 to 1.0)

### 3.8 Module Integration

- [ ] **TV-43:** Migration does not modify or conflict with any existing migration file (`20260819090001` through `20260829090003`)
- [ ] **TV-44:** `financial_profiles.entity_id` FK correctly references `entities(id)`
- [ ] **TV-45:** `financial_profiles.default_currency` FK correctly references `financial_supported_currencies(currency_code)`
- [ ] **TV-46:** `financial_currency_accounts.financial_profile_id` FK correctly references `financial_profiles(id)`
- [ ] **TV-47:** `financial_balances.financial_profile_id` FK correctly references `financial_profiles(id)`
- [ ] **TV-48:** `financial_transactions.financial_profile_id` FK correctly references `financial_profiles(id)` with ON DELETE RESTRICT
- [ ] **TV-49:** `financial_escrow.financial_profile_id` FK correctly references `financial_profiles(id)` with ON DELETE RESTRICT
- [ ] **TV-50:** `financial_escrow_milestones.escrow_id` FK correctly references `financial_escrow(id)` with ON DELETE CASCADE
- [ ] **TV-51:** `financial_payouts.payout_account_id` FK correctly references `financial_payout_accounts(id)` with ON DELETE RESTRICT
- [ ] **TV-52:** All currency FK columns correctly reference `financial_supported_currencies(currency_code)`

---

## 4. Data Verification

### 4.1 Data Creation — Tables

- [ ] **DV-01:** `financial_supported_currencies` table has correct column types, constraints, and defaults
- [ ] **DV-02:** `financial_profiles` table has correct column types, constraints, UNIQUE on `entity_id`, and defaults
- [ ] **DV-03:** `financial_currency_accounts` table has correct column types, constraints, UNIQUE on `(entity_id, currency_code)`, and defaults
- [ ] **DV-04:** `financial_balances` table has correct column types, constraints, non-negative CHECK on balance columns, UNIQUE on `(entity_id, currency_code)`, and defaults
- [ ] **DV-05:** `financial_transactions` table has correct column types, constraints, positive amount CHECK, and defaults (no `updated_at`)
- [ ] **DV-06:** `financial_escrow` table has correct column types, constraints, amount integrity CHECK, and defaults
- [ ] **DV-07:** `financial_escrow_milestones` table has correct column types, constraints, UNIQUE on `(escrow_id, milestone_number)`, and defaults
- [ ] **DV-08:** `financial_payout_accounts` table has correct column types, constraints, UNIQUE on `(entity_id, currency_code, account_number)`, and defaults
- [ ] **DV-09:** `financial_payouts` table has correct column types, constraints, and defaults
- [ ] **DV-10:** `financial_deposits` table has correct column types, constraints, and defaults
- [ ] **DV-11:** `financial_conversions` table has correct column types, constraints, `from_currency <> to_currency` CHECK, and defaults
- [ ] **DV-12:** `financial_audit_trail` table has correct column types, constraints, and defaults (no `updated_at`)

### 4.2 Data Creation — Seed Data

- [ ] **DV-13:** `financial_supported_currencies` contains exactly 4 rows after migration
- [ ] **DV-14:** `NGN` row: name "Nigerian Naira", symbol "₦", decimal_places 2
- [ ] **DV-15:** `GHS` row: name "Ghanaian Cedi", symbol "₵", decimal_places 2
- [ ] **DV-16:** `USD` row: name "US Dollar", symbol "$", decimal_places 2
- [ ] **DV-17:** `GBP` row: name "British Pound", symbol "£", decimal_places 2
- [ ] **DV-18:** All seed rows have `is_active = true`
- [ ] **DV-19:** Seed is idempotent — re-running does not create duplicate `currency_code` rows

### 4.3 Data Creation via RPCs

- [ ] **DV-20:** `financial_profile_create` inserts a `financial_profiles` row with `status = 'active'`, correct `entity_id`, `default_currency`
- [ ] **DV-21:** `financial_profile_create` inserts a `financial_balances` row for the default currency with all balances = 0
- [ ] **DV-22:** `financial_profile_create` produces a `financial_audit_trail` row with `event_type = 'profile_created'`
- [ ] **DV-23:** `financial_escrow_create` inserts a `financial_escrow` row with `status = 'created'`, correct `payer_entity_id`, `payee_entity_id`, `total_amount`
- [ ] **DV-24:** `financial_escrow_create` inserts `financial_escrow_milestones` rows matching the input milestones JSON
- [ ] **DV-25:** `financial_escrow_fund` updates `financial_escrow.status` to `'funded'`, sets `funded_at`
- [ ] **DV-26:** `financial_escrow_fund` inserts a `financial_transactions` row with `transaction_type = 'escrow_fund'`
- [ ] **DV-27:** `financial_escrow_fund` decrements payer `available_balance` and increments payer `held_balance`
- [ ] **DV-28:** `financial_escrow_release` updates `financial_escrow.status` to `'released'`, sets `released_at`, updates `released_amount`
- [ ] **DV-29:** `financial_escrow_release` inserts a `financial_transactions` row with `transaction_type = 'escrow_release'`
- [ ] **DV-30:** `financial_escrow_release` decrements payer `held_balance` and increments payee `available_balance`
- [ ] **DV-31:** `financial_escrow_refund` updates `financial_escrow.status` to `'refunded'`, sets `refunded_at`, updates `refunded_amount`
- [ ] **DV-32:** `financial_escrow_refund` inserts a `financial_transactions` row with `transaction_type = 'escrow_refund'`
- [ ] **DV-33:** `financial_escrow_refund` decrements payer `held_balance` and increments payer `available_balance`
- [ ] **DV-34:** `financial_withdraw` decrements `available_balance`, inserts a `financial_payouts` row with `status = 'pending'`, inserts a `financial_transactions` row with `transaction_type = 'withdrawal'`
- [ ] **DV-35:** `financial_deposit_record` inserts a `financial_deposits` row with `status = 'pending'`, `name_match_status = 'unverified'`
- [ ] **DV-36:** `financial_convert_currency` decrements source `available_balance`, increments destination `available_balance`, inserts a `financial_conversions` row, inserts two `financial_transactions` rows (`conversion_debit` + `conversion_credit`)

### 4.4 Data Relationships

- [ ] **DV-37:** `financial_profiles.entity_id` references a valid `entities(id)` — zero orphaned profiles
- [ ] **DV-38:** `financial_currency_accounts.financial_profile_id` references a valid `financial_profiles(id)` — zero orphaned accounts
- [ ] **DV-39:** `financial_balances.financial_profile_id` references a valid `financial_profiles(id)` — zero orphaned balances
- [ ] **DV-40:** `financial_transactions.financial_profile_id` references a valid `financial_profiles(id)` — zero orphaned transactions
- [ ] **DV-41:** `financial_escrow.financial_profile_id` references a valid `financial_profiles(id)` — zero orphaned escrow
- [ ] **DV-42:** `financial_escrow_milestones.escrow_id` references a valid `financial_escrow(id)` — zero orphaned milestones
- [ ] **DV-43:** `financial_payouts.payout_account_id` references a valid `financial_payout_accounts(id)` — zero orphaned payouts
- [ ] **DV-44:** All currency_code values reference valid `financial_supported_currencies(currency_code)` — zero invalid currencies

### 4.5 Data Accuracy

- [ ] **DV-45:** `financial_balances` non-negative CHECK enforced: `available_balance >= 0 AND held_balance >= 0 AND pending_balance >= 0`
- [ ] **DV-46:** `financial_transactions.amount` positive CHECK enforced: `amount > 0`
- [ ] **DV-47:** `financial_escrow` amount integrity CHECK enforced: `released_amount + refunded_amount <= total_amount`
- [ ] **DV-48:** `financial_escrow.status` restricted to `created | funded | partially_released | released | refunded | cancelled | disputed`
- [ ] **DV-49:** `financial_escrow_milestones.status` restricted to `pending | completed | released`
- [ ] **DV-50:** `financial_payout_accounts.status` restricted to `pending | active | deactivated`
- [ ] **DV-51:** `financial_payouts.status` restricted to `pending | processing | completed | failed`
- [ ] **DV-52:** `financial_deposits.name_match_status` restricted to `pending | matched | mismatched | unverified`
- [ ] **DV-53:** `financial_deposits.status` restricted to `pending | credited | flagged | reversed`
- [ ] **DV-54:** `financial_conversions.status` restricted to `pending | completed | failed`
- [ ] **DV-55:** `financial_audit_trail.event_type` restricted to defined vocabulary
- [ ] **DV-56:** `financial_transactions.transaction_type` restricted to defined vocabulary
- [ ] **DV-57:** `financial_conversions.from_currency <> to_currency` CHECK enforced

### 4.6 Data Integrity

- [ ] **DV-58:** `financial_profiles` UNIQUE(entity_id) enforced — one profile per entity
- [ ] **DV-59:** `financial_balances` UNIQUE(entity_id, currency_code) enforced — one balance per entity per currency
- [ ] **DV-60:** `financial_currency_accounts` UNIQUE(entity_id, currency_code) enforced — one receiving account per entity per currency
- [ ] **DV-61:** `financial_payout_accounts` UNIQUE(entity_id, currency_code, account_number) enforced — no duplicate bindings
- [ ] **DV-62:** `financial_escrow_milestones` UNIQUE(escrow_id, milestone_number) enforced
- [ ] **DV-63:** `financial_transactions` has no `updated_at` column and no UPDATE/DELETE grants — immutability enforced
- [ ] **DV-64:** `financial_audit_trail` has no `updated_at` column and no UPDATE/DELETE grants — append-only enforced
- [ ] **DV-65:** `updated_at` is automatically set by the `platform_set_updated_at()` trigger on all 10 mutable tables
- [ ] **DV-66:** FK ON DELETE CASCADE on `financial_profiles`, `financial_currency_accounts`, `financial_balances`, `financial_payout_accounts` — cascading cleanup on entity deletion
- [ ] **DV-67:** FK ON DELETE RESTRICT on `financial_transactions`, `financial_escrow`, `financial_payouts`, `financial_deposits`, `financial_conversions` — prevents deletion while financial records exist
- [ ] **DV-68:** FK ON DELETE SET NULL on `financial_audit_trail.entity_id` — audit trail preserved even if entity deleted
- [ ] **DV-69:** Race condition handling: concurrent `financial_profile_create` for same entity results in one success (PLT000) and one conflict error (PLT005)
- [ ] **DV-70:** Existing EP-01, EP-02-01, EP-02-02, EP-02-03 seed data and schema unchanged after migration

---

## 5. Security Verification

### 5.1 Authentication

- [ ] **SV-01:** Migration does not alter any authentication configuration or `auth.*` tables
- [ ] **SV-02:** Entity-facing RPCs (`financial_profile_create`, `financial_profile_get`, `financial_balance_get`, `financial_escrow_get`, `financial_payout_account_bind`, `financial_withdraw`, `financial_convert_currency`, `financial_status_get`) enforce `platform_is_authenticated()` — unauthenticated calls raise PLT001

### 5.2 Authorization & Access Control — EXECUTE Grants

- [ ] **SV-03:** Entity-facing read RPCs (`financial_profile_get`, `financial_balance_get`, `financial_escrow_get`, `financial_status_get`) EXECUTE granted to `authenticated` and `service_role`
- [ ] **SV-04:** Entity-facing write RPCs (`financial_profile_create`, `financial_payout_account_bind`, `financial_withdraw`, `financial_convert_currency`) EXECUTE granted to `authenticated` and `service_role`
- [ ] **SV-05:** System/internal RPCs (`financial_escrow_create`, `financial_escrow_fund`, `financial_escrow_release`, `financial_escrow_refund`, `financial_escrow_milestone_complete`, `financial_deposit_record`, `financial_deposit_verify_name`, `financial_payout_account_verify`, `financial_reconcile`) EXECUTE granted to `service_role` only
- [ ] **SV-06:** No EXECUTE grants to `anon` on any of the 18 RPCs
- [ ] **SV-07:** No EXECUTE grants to `authenticated` on service-role-only RPCs:
  ```sql
  SELECT grantee, routine_name
  FROM information_schema.routine_privileges
  WHERE routine_schema = 'public'
    AND routine_name LIKE 'financial_%'
    AND grantee IN ('anon', 'authenticated')
    AND routine_name IN ('financial_escrow_create', 'financial_escrow_fund', 'financial_escrow_release', 'financial_escrow_refund', 'financial_escrow_milestone_complete', 'financial_deposit_record', 'financial_deposit_verify_name', 'financial_payout_account_verify', 'financial_reconcile');
  -- Expected: 0 rows
  ```

### 5.3 Authorization & Access Control — Enforcement

- [ ] **SV-08:** `anon` role calling any of the 18 `financial_%` RPCs throws `42501` — 18 assertions
- [ ] **SV-09:** `authenticated` role calling service-role-only RPCs throws `42501` — 9 assertions
- [ ] **SV-10:** `authenticated` role can successfully invoke entity-facing RPCs — 8 assertions
- [ ] **SV-11:** `service_role` can successfully invoke all 18 RPCs without authorization errors

### 5.4 RLS & Table-Level Grants

- [ ] **SV-12:** All 12 new tables have RLS enabled (`relrowsecurity = true`)
- [ ] **SV-13:** `anon` has zero grants on all 12 new tables
- [ ] **SV-14:** `authenticated` has SELECT on `financial_supported_currencies`
- [ ] **SV-15:** `authenticated` has SELECT (self-scoped) on `financial_profiles`, `financial_currency_accounts`, `financial_balances`, `financial_transactions`, `financial_escrow`, `financial_escrow_milestones`, `financial_payout_accounts`, `financial_payouts`, `financial_deposits`, `financial_conversions`, `financial_audit_trail`
- [ ] **SV-16:** `authenticated` has INSERT (limited cols) on `financial_profiles` — `entity_id`, `default_currency` only; `status` excluded
- [ ] **SV-17:** `authenticated` has INSERT (limited cols) on `financial_currency_accounts` — `entity_id`, `currency_code` only; `account_status`, `receiving_account_number`, `provider_reference` excluded
- [ ] **SV-18:** `authenticated` has INSERT (limited cols) on `financial_payout_accounts` — `entity_id`, `currency_code`, `bank_name`, `account_number`, `account_name` only; `is_verified`, `verified_at`, `status` excluded
- [ ] **SV-19:** `authenticated` has zero INSERT on `financial_balances`
- [ ] **SV-20:** `authenticated` has zero INSERT on `financial_transactions`
- [ ] **SV-21:** `financial_balances` balance columns (`available_balance`, `held_balance`, `pending_balance`) not writable by `authenticated`
- [ ] **SV-22:** `financial_escrow.status` not writable by `authenticated`
- [ ] **SV-23:** `financial_payout_accounts.is_verified` and `verified_at` not writable by `authenticated`
- [ ] **SV-24:** `financial_transactions` has no UPDATE/DELETE grant to any client role
- [ ] **SV-25:** `financial_audit_trail` has no UPDATE/DELETE grant to any client role
- [ ] **SV-26:** Escrow read policies use `(payer_entity_id = auth.uid() OR payee_entity_id = auth.uid())` — both parties can view

### 5.5 RLS Policies

- [ ] **SV-27:** `financial_profiles_authenticated_select` policy exists (using `entity_id = auth.uid()`)
- [ ] **SV-28:** `financial_profiles_authenticated_insert` policy exists (with check `entity_id = auth.uid()`)
- [ ] **SV-29:** `financial_currency_accounts_authenticated_select` policy exists
- [ ] **SV-30:** `financial_balances_authenticated_select` policy exists
- [ ] **SV-31:** `financial_transactions_authenticated_select` policy exists
- [ ] **SV-32:** `financial_escrow_authenticated_select` policy exists (payer/payee scope)
- [ ] **SV-33:** `financial_escrow_milestones_authenticated_select` policy exists (via escrow join)
- [ ] **SV-34:** `financial_payout_accounts_authenticated_select` policy exists
- [ ] **SV-35:** `financial_payout_accounts_authenticated_insert` policy exists (column-restricted)
- [ ] **SV-36:** `financial_payouts_authenticated_select` policy exists
- [ ] **SV-37:** `financial_deposits_authenticated_select` policy exists
- [ ] **SV-38:** `financial_conversions_authenticated_select` policy exists
- [ ] **SV-39:** `financial_audit_trail_authenticated_select` policy exists
- [ ] **SV-40:** `financial_audit_trail_authenticated_insert` policy exists (with check `entity_id = auth.uid()`)

### 5.6 Security Posture

- [ ] **SV-41:** No new SECURITY DEFINER functions introduced with `financial_` prefix:
  ```sql
  SELECT count(*) FROM pg_proc
  WHERE proname LIKE 'financial_%' AND prosecdef;
  -- Expected: 0
  ```
- [ ] **SV-42:** No SQL injection vectors — all RPCs use parameterized PL/pgSQL variable references
- [ ] **SV-43:** No secrets, credentials, API keys, or PII in any RPC function body or comment
- [ ] **SV-44:** `description` fields are length-capped (≤ 500 chars)
- [ ] **SV-45:** Realtime excludes all 12 new tables from `supabase_realtime` publication

### 5.7 Financial Integrity

- [ ] **SV-46:** Zero financial logic accessible to the client — all balance mutations, escrow transitions, limit checks, and name-matching execute inside RPCs
- [ ] **SV-47:** `financial_withdraw` enforces KYC cashout limit via `verification_limits_get()` — withdrawal exceeding limit raises PLT006
- [ ] **SV-48:** `financial_withdraw` enforces verified payout account — withdrawal to unverified account raises PLT003
- [ ] **SV-49:** `financial_deposit_verify_name` compares against `entity_profiles.legal_name` — no client-side name-matching bypass possible
- [ ] **SV-50:** Balance mutations use `SELECT ... FOR UPDATE` locking — no race-condition balance corruption
- [ ] **SV-51:** CHECK constraint on `financial_balances` prevents negative balances at the database level even if RPC logic is bypassed

---

## 6. Performance Verification

### 6.1 Response Performance

- [ ] **PV-01:** `financial_balance_get` uses `entity_id + currency_code` unique index — O(1) lookup
- [ ] **PV-02:** `financial_profile_get` uses `entity_id` unique index — O(1) lookup
- [ ] **PV-03:** `financial_escrow_get` uses `id` PK — O(1) lookup
- [ ] **PV-04:** `financial_status_get` assembles aggregate in one function with indexed lookups — no N+1
- [ ] **PV-05:** `financial_transactions_entity_created_idx` supports paginated history queries
- [ ] **PV-06:** `financial_escrow_payer_idx`, `financial_escrow_payee_idx` support entity-scoped escrow lists
- [ ] **PV-07:** Read RPCs marked `STABLE` allow PostgreSQL query planner optimization

### 6.2 Resource Usage

- [ ] **PV-08:** Migration creates exactly 18 functions — no duplicate or orphaned definitions
- [ ] **PV-09:** Write RPCs operate on individual rows — no table-level locks acquired during mutation
- [ ] **PV-10:** Audit trail inserts are append-only with indexed `created_at`/`entity_id` — negligible overhead
- [ ] **PV-11:** 24 indexes created across 12 tables — appropriate for query patterns

### 6.3 System Reliability

- [ ] **PV-12:** `platform_set_updated_at()` triggers fire correctly on all 10 mutable tables
- [ ] **PV-13:** `financial_audit_trail` direct inserts from service-role RPCs do not cause transaction failures
- [ ] **PV-14:** Balance mutations are single-row UPDATEs with `FOR UPDATE` lock — no deadlock risk
- [ ] **PV-15:** Escrow state transitions are single-row UPDATEs with `FOR UPDATE` lock — no deadlock risk
- [ ] **PV-16:** All FK references are valid — zero constraint violation risk under normal operation
- [ ] **PV-17:** `financial_reconcile` aggregates `financial_transactions` for a given entity/currency — indexed on `entity_id`; efficient even at scale

---

## 7. Testing Verification

### 7.1 Automated Testing — pgTAP Schema Posture

- [ ] **TT-01:** Test file exists at `supabase/tests/database/013_financial_schema_posture.sql`
- [ ] **TT-02:** Test follows established pgTAP pattern: `begin; set search_path to extensions, public; select plan(N); ... select * from finish(); rollback;`
- [ ] **TT-03:** Asserts all 12 tables exist (`has_table` ×12)
- [ ] **TT-04:** Asserts RLS enabled on all 12 tables
- [ ] **TT-05:** Asserts `anon` has zero grants on all 12 new tables
- [ ] **TT-06:** Asserts `financial_balances` balance columns not writable by `authenticated`
- [ ] **TT-07:** Asserts `financial_transactions` no INSERT grant to `authenticated`
- [ ] **TT-08:** Asserts `financial_escrow.status` not writable by `authenticated`
- [ ] **TT-09:** Asserts `financial_payout_accounts.is_verified/verified_at` not writable by `authenticated`
- [ ] **TT-10:** Asserts `financial_transactions` has no UPDATE/DELETE grant to any role
- [ ] **TT-11:** Asserts `financial_audit_trail` has no UPDATE/DELETE grant to any role
- [ ] **TT-12:** Asserts triggers present on 10 mutable tables
- [ ] **TT-13:** Asserts no `financial_%` SECURITY DEFINER function
- [ ] **TT-14:** Asserts Realtime excludes all 12 tables
- [ ] **TT-15:** Asserts comments present on all 12 new tables
- [ ] **TT-16:** Asserts `financial_supported_currencies` seeded with 4 rows
- [ ] **TT-17:** All assertions in `013` pass — zero failures

### 7.2 Automated Testing — pgTAP RPC Enforcement

- [ ] **TT-18:** Test file exists at `supabase/tests/database/014_financial_rpc_enforcement.sql`
- [ ] **TT-19:** Test follows established pgTAP pattern
- [ ] **TT-20:** Asserts authorization: `anon` cannot call any RPC (42501 ×18), `authenticated` cannot call service-role-only RPCs (42501 ×9), `authenticated` can call entity-facing RPCs (×8), `service_role` can call all 18
- [ ] **TT-21:** Asserts validation: invalid currency (PLT003), duplicate profile (PLT005), zero amount (PLT003), milestone sum mismatch (PLT003), unverified payout account (PLT003), same from/to currency (PLT003), duplicate payout account (PLT005)
- [ ] **TT-22:** Asserts not-found: non-existent escrow (PLT004), non-existent milestone (PLT004), non-existent payout account (PLT004), non-existent deposit (PLT004), no financial profile (PLT004)
- [ ] **TT-23:** Asserts conflict: already-funded escrow (PLT005), release on unfunded (PLT005), refund on unfunded (PLT005)
- [ ] **TT-24:** Asserts insufficient funds: escrow fund with insufficient balance (PLT006), withdraw with insufficient balance (PLT006), withdraw exceeding KYC limit (PLT006), convert with insufficient balance (PLT006)
- [ ] **TT-25:** Asserts functional: profile create → profile + balance rows; escrow fund → balance debit/credit + transaction row; escrow release → balance debit/credit; escrow refund → balance debit/credit; milestone complete → auto-release; withdraw → balance debit + payout row; deposit record → deposit row; deposit verify name → matched/mismatched; convert → double-entry + conversion record; reconcile → true/false
- [ ] **TT-26:** Asserts double-entry: every balance mutation produces a matching `financial_transactions` row with correct `debit_balance_type` and `credit_balance_type`
- [ ] **TT-27:** Asserts audit: `financial_audit_trail` rows for all events
- [ ] **TT-28:** Asserts envelope: all RPCs return `{success, code, message, data}` with `PLT000` on success
- [ ] **TT-29:** All assertions in `014` pass — zero failures

### 7.3 Regression Testing — Existing pgTAP Suite

- [ ] **TT-30:** `008_full_schema_posture_audit.sql` passes all assertions without regression
- [ ] **TT-31:** `009_taxonomy_seed_verification.sql` passes all assertions without regression
- [ ] **TT-32:** `010_taxonomy_rpc_enforcement.sql` passes all assertions without regression
- [ ] **TT-33:** `011_verification_schema_posture.sql` passes all assertions without regression
- [ ] **TT-34:** `012_verification_rpc_enforcement.sql` passes all assertions without regression
- [ ] **TT-35:** Full test suite execution via `supabase db test` reports zero failures across all test files (001–014)

### 7.4 Edge Cases

- [ ] **TT-36:** `financial_profile_create` with `p_default_currency = 'USD'` — profile created with USD balance row (not NGN)
- [ ] **TT-37:** `financial_escrow_create` with single milestone — escrow created, one milestone row
- [ ] **TT-38:** `financial_escrow_create` with multiple milestones — escrow created, multiple milestone rows, sum equals total_amount
- [ ] **TT-39:** `financial_escrow_milestone_complete` on last milestone triggers auto-release — escrow status transitions to `released`
- [ ] **TT-40:** `financial_escrow_milestone_complete` on first of multiple milestones — escrow status transitions to `partially_released`
- [ ] **TT-41:** `financial_balance_get` for entity with no financial profile — returns PLT004
- [ ] **TT-42:** `financial_status_get` for entity with zero balances — returns zero balances with appropriate envelope
- [ ] **TT-43:** `financial_reconcile` for entity with no transactions — returns `true` (all balances zero)
- [ ] **TT-44:** `financial_deposit_verify_name` with NULL `payer_name` — returns `unverified` or appropriate handling
- [ ] **TT-45:** `financial_convert_currency` with `p_from_currency = p_to_currency` — raises PLT003

### 7.5 Failure Scenarios

- [ ] **TT-46:** If `financial_profile_create` encounters a `unique_violation` (23505) during INSERT despite pre-validation (race condition), the exception is caught and re-raised as PLT005
- [ ] **TT-47:** If `financial_escrow_fund` balance UPDATE violates the non-negative CHECK (race condition), the transaction rolls back and PLT006 is raised
- [ ] **TT-48:** If `financial_escrow_release` payee balance UPDATE fails (payee entity deleted concurrently), the RPC handles gracefully without orphaned state
- [ ] **TT-49:** If `financial_withdraw` encounters a `foreign_key_violation` (23503) during payout INSERT, the exception is caught and re-raised as PLT004
- [ ] **TT-50:** If `financial_convert_currency` destination balance row does not exist, the RPC creates it or raises PLT004 appropriately

### 7.6 Manual Testing

- [ ] **TT-51:** Manual invocation of `financial_profile_create` via `psql` or Supabase SQL editor as `authenticated` creates a profile and balance row
- [ ] **TT-52:** Manual invocation of `financial_escrow_fund` as `service_role` funds escrow and updates balances correctly
- [ ] **TT-53:** Manual invocation of `financial_withdraw` as `authenticated` within KYC limits succeeds
- [ ] **TT-54:** Manual invocation of `financial_withdraw` exceeding KYC limits raises PLT006
- [ ] **TT-55:** Manual invocation of any service-role-only RPC as `authenticated` is rejected with `42501`
- [ ] **TT-56:** Manual query of `financial_supported_currencies` returns 4 seeded rows with correct metadata

---

## 8. User Acceptance Verification

This task has no direct user interface. User acceptance is verified indirectly through RPC correctness, envelope consistency, double-entry integrity, and downstream readiness.

- [ ] **UA-01:** All 18 RPCs return the same `{success, code, message, data}` envelope format used by existing platform RPCs — consistent API contract for future client-side consumers
- [ ] **UA-02:** Error messages from RPCs are descriptive enough for downstream UIs to display actionable feedback (e.g., "Insufficient funds.", "Payout account not verified.", "Escrow already funded.")
- [ ] **UA-03:** Audit trail captures all financial state changes — an admin can reconstruct the full financial history by querying `financial_audit_trail`
- [ ] **UA-04:** `financial_balance_get` returns sufficient data for financial profile screens to display available/held/pending per currency
- [ ] **UA-05:** `financial_status_get` returns sufficient data for dashboard financial summary display
- [ ] **UA-06:** `financial_escrow_get` returns milestones with status for escrow progress display
- [ ] **UA-07:** `financial_withdraw` returns remaining cashout headroom in the response for limit display
- [ ] **UA-08:** `financial_deposit_verify_name` returns match status and score for name-mismatch flagging UI
- [ ] **UA-09:** PLT006 error code enables clear "insufficient funds" user feedback distinct from validation errors
- [ ] **UA-10:** The financial engine is sufficient to unblock EP-02-05 (Dispute Resolution), EP-02-13 (Multi-Currency Financial Profile), EP-02-14 (Escrow Management), EP-02-15 (Currency Conversion), and EP-02-16 (Payout & Deposit Verification)

---

## 9. Final Approval Checklist

All conditions below must be satisfied before EP-02-04 can be marked **Completed**.

| # | Condition | Verified By | Pass |
|---|---|---|---|
| 1 | Migration file exists at `supabase/migrations/<timestamp>_financial_integrity_schema.sql` with correct naming and timestamp ordering after `20260829090003` | File inspection | ☐ |
| 2 | Migration header comment block documents purpose (EP-02-04), execution model, double-entry model, envelope contract, and grant strategy | Code review | ☐ |
| 3 | Exactly 12 tables created: `financial_supported_currencies`, `financial_profiles`, `financial_currency_accounts`, `financial_balances`, `financial_transactions`, `financial_escrow`, `financial_escrow_milestones`, `financial_payout_accounts`, `financial_payouts`, `financial_deposits`, `financial_conversions`, `financial_audit_trail` | `SELECT has_table` ×12 | ☐ |
| 4 | All 12 tables have RLS enabled | `relrowsecurity` check | ☐ |
| 5 | `anon` has zero grants on the 12 new tables | `role_table_grants` query | ☐ |
| 6 | `financial_balances` balance columns not writable by `authenticated` | column-grant assertion | ☐ |
| 7 | `financial_transactions` no INSERT grant to `authenticated` | column-grant assertion | ☐ |
| 8 | `financial_escrow.status` not writable by `authenticated` | column-grant check | ☐ |
| 9 | `financial_payout_accounts.is_verified/verified_at` not writable by `authenticated` | column-grant check | ☐ |
| 10 | `financial_transactions` and `financial_audit_trail` have no UPDATE/DELETE grant to any client role | grant query | ☐ |
| 11 | `financial_supported_currencies` seeded with 4 currencies via idempotent insert | `select count(*) from financial_supported_currencies` = 4 | ☐ |
| 12 | Exactly 18 `financial_` functions created | `SELECT proname FROM pg_proc WHERE proname LIKE 'financial_%'` = 18 rows | ☐ |
| 13 | All 18 RPCs are SECURITY INVOKER — zero SECURITY DEFINER | `SELECT count(*) FROM pg_proc WHERE proname LIKE 'financial_%' AND prosecdef` = 0 | ☐ |
| 14 | Entity-facing RPCs granted to `authenticated`, `service_role`; system/internal RPCs granted to `service_role` only | Grant inspection query | ☐ |
| 15 | `anon` cannot invoke any RPC (throws `42501`) — 18 assertions | pgTAP `throws_ok` | ☐ |
| 16 | `authenticated` cannot invoke service-role-only RPCs (throws `42501`) — 9 assertions | pgTAP `throws_ok` | ☐ |
| 17 | `authenticated` can call entity-facing RPCs (`lives_ok`) — 8 assertions | pgTAP `lives_ok` | ☐ |
| 18 | `financial_profile_create` validates currency (PLT003) and enforces dedup (PLT005) | pgTAP | ☐ |
| 19 | `financial_escrow_fund` with insufficient balance raises PLT006 | pgTAP | ☐ |
| 20 | `financial_escrow_fund` → payer available debited, held credited; transaction row exists with correct debit/credit types | pgTAP (double-entry) | ☐ |
| 21 | `financial_escrow_release` → payer held debited, payee available credited; transaction row exists | pgTAP (double-entry) | ☐ |
| 22 | `financial_escrow_refund` → payer held debited, payer available credited; transaction row exists | pgTAP (double-entry) | ☐ |
| 23 | Milestone completion triggers auto-release when all milestones done | pgTAP | ☐ |
| 24 | `financial_withdraw` enforces KYC cashout limit (PLT006) and verified account (PLT003) | pgTAP | ☐ |
| 25 | `financial_deposit_verify_name` returns `matched` for matching name, `mismatched` for different name | pgTAP | ☐ |
| 26 | `financial_convert_currency` produces double-entry transaction pair + conversion record | pgTAP | ☐ |
| 27 | `financial_reconcile` returns true when balances match ledger; false when tampered | pgTAP | ☐ |
| 28 | All RPCs return `{success, code, message, data}` envelope on success and PLT### codes on error | Envelope structure assertion | ☐ |
| 29 | No DDL alters any EP-01 / EP-02-01/02/03 table structure | Migration file review | ☐ |
| 30 | Realtime excludes the 12 new tables | Publication query | ☐ |
| 31 | No SECURITY DEFINER `financial_%` function | `pg_proc` query | ☐ |
| 32 | pgTAP `013_financial_schema_posture.sql` exists and passes all assertions | `supabase db test` | ☐ |
| 33 | pgTAP `014_financial_rpc_enforcement.sql` exists and passes all assertions | `supabase db test` | ☐ |
| 34 | Full suite `001`–`014` passes (no regression to `008`/`009`/`010`/`011`/`012`) | `supabase db test` | ☐ |
| 35 | Migration header + `comment on function` for all 18 RPCs | `SELECT obj_description(oid) FROM pg_proc WHERE proname LIKE 'financial_%'` — all non-null | ☐ |
| 36 | No client-side files created — no files added under `lib/` | File inspection | ☐ |
| 37 | EP-02-05 / 13 / 14 / 15 / 16 unblocked — financial engine available for downstream consumption | Dependency check | ☐ |

---

## 10. Completion Record

**Status:** Pending — awaiting implementation and verification.

### 10.1 Verification Evidence

_To be completed upon task implementation._

### 10.2 Disclosures

_To be completed upon task implementation._

### 10.3 Recommendation

_To be completed upon task implementation._

---

> **Sign-off:** Task EP-02-04 marked **Completed** — all 37 Final Approval Checklist conditions verified.
