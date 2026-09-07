# EP-02-16 — Bound Payout Account System & Deposit Name Verification

**Stage:** 5 — Financial Integrity Systems
**Status:** Ready for Implementation
**Execution Justification Level:** Very High (Task, highest in this phase — financial security + verification)
**Depends On:** EP-02-04, EP-02-13, EP-02-12, EP-02-09
**Required For:** EP-02-18, EP-02-19
**Estimated Complexity:** Very High (17-19 completion criteria)

---

## 1. Objective

Build a strictly server-authorized bound payout account registry with KYC-tiered limits and a real-time deposit name verification system that satisfies `AGENT.md` Rule 3. The payout account bind RPC (`financial_payout_account_bind`) is an `authenticated` server function that verifies the requesting `user_id` matches the row and respects the 10-account-per-currency ceiling; `financial_withdraw` is also `authenticated` and validates the account is bound to the user with 48-hour new-account cooling-off window. The deposit name match RPC (`financial_deposit_record`) is a `service_role` server function callable only from server functions or Edge Functions — clients must never call it directly, enforced by the `authenticated` gateway that pre-fills `user_id` from `auth.uid()`; the deposit verification RPC (`financial_deposit_record_verify`) and the name check RPC (`financial_deposit_name_check`) are also `service_role` only. The user-facing UX focus is a deposit amount field with live `SupportedCurrency` conversion preview and a structured `DepositDetailsPanel` (within the existing `FinanceScreen`) plus the verification status display in the existing `TransactionHistoryView`. Adapters must be provider-agnostic.

---

## 2. Business Problem

**What problem does this solve?**
1. No canonical payout account registry — users have no structured way to manage withdrawal accounts per currency, creating uncertainty about which account a withdrawal routes to.
2. Without KYC-tiered cashout limits tied to a bound payout account, there is no mechanism to enforce regulatory-tiered withdrawal ceilings consistently.
3. No deposit name matching (incoming bank transfer attribution to user) — the platform cannot reliably attribute bank transfers to the correct user account via name matching (`AGENT.md` Rule 3).
4. No structured deposit entry panel with real-time multi-currency conversion preview in the Finance tab — the current flow (if any) lacks the structured `DepositDetailsPanel` UX required for professional financial operations.

**Who benefits and how?**
- **End Users:** Gain reliable payout account management with KYC-driven limits; see real-time NGN conversion preview when depositing in USD/GBP/EUR; bank transfer deposits arrive with automated name-matching attribution and verified status.
- **Operators:** Get complete audit trail of payout account binds, withdrawals, and deposit name matches; KYC-based limit enforcement happens automatically; platform maintains `AGENT.md` Rule 3 compliance without manual review.
- **Platform:** Maintains server-side control over payout limits (KYC-driven), ensuring regulatory compliance while offering provider-agnostic payout routing.

---

## 3. Scope

### 3.1 In-Scope (What we are building in this task)

**Bound Payout Account System:**
- `PayoutAccountModel` entity, `PayoutAccountEntity` model, `PayoutAccountMapper` in `lib/data/entities/financial/`
- `PayoutAccountRepository` in `lib/data/repositories/`
- `PayoutAccountDataSource` (remote RPC wrapper) in `lib/core/api/datasources/`
- `PayoutAccountProvider` in `lib/data/providers/`
- `PayoutAccountService` in `lib/systems/finance/services/`
- `PayoutAccountView`, `PayoutAccountFormView`, `PayoutAccountLimitDisplay` in `lib/features/finance/`
- Add payout account section to `FinanceScreen` (within EP-02-16 scope only; repositioning to bottom nav is deferred to a later EP)

**Deposit Name Verification System:**
- `DepositModel` entity, `DepositEntity` model, `DepositMapper` in `lib/data/entities/financial/`
- `DepositRepository` in `lib/data/repositories/`
- `DepositDataSource` (remote RPC wrapper) in `lib/core/api/datasources/`
- `DepositProvider` in `lib/data/providers/`
- `DepositService` in `lib/systems/finance/services/`
- `DepositDetailsPanel` (structured amount field + `SupportedCurrency` conversion preview + deposit entry button) in `lib/features/finance/`
- `DepositNameMatchService` in `lib/systems/finance/services/` (service_role RPC — client calls only via server function proxy; the actual proxy is deferred to EP-02-18, but the service layer is wired now)

**Verification Integration:**
- `DepositVerificationStatus` enum in `lib/systems/finance/models/`
- Verification status badges in `TransactionHistoryView` (`lib/features/finance/`)
- Server-side name matching flow: service callable only by `service_role` functions, not from client; proxy entry point deferred to EP-02-18

**Server Functions:**
- `financial_payout_account_bind` — `authenticated` RPC; validates `user_id = auth.uid()`, checks currency+account+bank_code uniqueness, respects 10-account-per-currency ceiling, inserts via `payout_account_insert_trigger`
- `financial_withdraw` — `authenticated` RPC; validates payout account exists + user owns it, enforces 48-hour new-account cooling-off window, checks balance via `ledger_balance()`, creates `payouts` row, debits via `ledger_debit()`
- `financial_deposit_record` — `service_role` RPC; records incoming funds, computes match score via `levenshtein()` against beneficiary names, derives verification status automatically
- `financial_deposit_record_verify` — `service_role` RPC; sets `verified_by` and updates `verification_status` to `verified`
- `financial_deposit_name_check` — `service_role` RPC; returns name match score for existing deposit record

**Feature Flags:**
- `payoutVerificationViaProxyEnabled` — defaults `false`, defers provider-agnostic verification proxy adapter to EP-02-18
- `depositVerifyViaProxyEnabled` — defaults `false`, defers `payout_account_verify` proxy to EP-02-18

**Transactions list integration:**
- Extend `TransactionHistoryView` to show payout + deposit records with structured type badges
- `DepositVerificationStatus` badge (Unverified/Pending/Verified/Failed) with appropriate colors
- `DepositAmountCell` component (formatted amount + currency flag/label)

### 3.2 Explicitly Out of Scope (What we are NOT doing)

- Any changes to `supabase/migrations/` — the migration already exists at `supabase/migrations/20260829100004_financial_integrity_schema.sql`; zero DDL modifications permitted
- Creating `PaymentGateway` service proxies for payout account verification or deposit name verification — deferred to EP-02-18
- Implementing the actual proxy Edge Functions for payout account verification or deposit name verification — deferred to EP-02-18
- Connecting `PayoutAccountService` to the `PaymentGateway` adapter dispatch chain — deferred to EP-02-18
- Running verification via provider proxy on bind — deferred to EP-02-18; this task writes the `unverified` account only
- Any `BankTransferProvider` adapter code — not in scope
- Any changes to `AuthenticationService`, `KycRepository`, `AuthRepository`, `ProfileRepository`, `CurrencyRepository`, `LedgerRepository`, or other existing domain repositories beyond what is necessary to support this task
- Modifying any existing providers beyond what is necessary to support this task
- Completing all visual design polish (functional correctness is the priority)
- Touching `supabase/migrations/` (schema is frozen for this phase)
- Creating any files outside `lib/` and `documents/Task-Implementation/EP-02/`
- Writing any hardcoded business logic in UI components — all calculations via `FinanceService`/`PayoutAccountService`

---

## 4. Technical Approach

### 4.1 Architecture Decisions

**Directory placement:**
- `lib/data/entities/financial/payout_account_model.dart` — `PayoutAccountModel` entity
- `lib/data/entities/financial/payout_account_entity.dart` — `PayoutAccountEntity` model
- `lib/data/entities/financial/deposit_model.dart` — `DepositModel` entity
- `lib/data/entities/financial/deposit_entity.dart` — `DepositEntity` model
- `lib/data/repositories/payout_account_repository.dart` — payout account data operations
- `lib/data/repositories/deposit_repository.dart` — deposit data operations
- `lib/core/api/datasources/payout_account_data_source.dart` — payout account RPC wrappers
- `lib/core/api/datasources/deposit_data_source.dart` — deposit RPC wrappers
- `lib/data/providers/payout_account_provider.dart` — payout account state management
- `lib/data/providers/deposit_provider.dart` — deposit state management
- `lib/systems/finance/services/payout_account_service.dart` — payout account business logic
- `lib/systems/finance/services/deposit_service.dart` — deposit business logic
- `lib/systems/finance/services/deposit_name_match_service.dart` — name matching RPC caller (service_role; proxy deferred to EP-02-18)
- `lib/systems/finance/models/verification_status.dart` — `DepositVerificationStatus` enum
- `lib/features/finance/screens/payout_account_view.dart` — payout account list
- `lib/features/finance/screens/payout_account_form_view.dart` — add/edit payout account form
- `lib/features/finance/screens/payout_account_limit_display.dart` — KYC-tiered limit display
- `lib/features/finance/screens/deposit_details_panel.dart` — structured deposit amount field
- `lib/features/finance/screens/deposit_name_match_indicator.dart` — name match status display

**Design pattern:** Layered architecture with repository pattern (same as EP-02-13, EP-02-14, EP-02-15)
- **Entities:** Pure data models (lowercase-named `deposit_model.dart`, `deposit_entity.dart`, etc.)
- **Data Sources:** RPC wrappers in `lib/core/api/datasources/`
- **Repositories:** Business data layer in `lib/data/repositories/`
- **Providers:** `ChangeNotifier` state management in `lib/data/providers/`
- **Services:** Business logic in `lib/systems/finance/services/`
- **Models:** Domain-specific models (enums) in `lib/systems/finance/models/`
- **Views:** Feature UI in `lib/features/finance/`

**State management:** `ChangeNotifier` via `Provider` package (consistent with `FinanceProvider`, `LedgerProvider`, `KycRepository`)

### 4.2 RPC Execution Model — Three Execution Tiers

EP-02-16 uses server functions across three distinct security tiers:

| RPC | Execution Tier | Callable From |
|-----|---------------|---------------|
| `financial_payout_account_bind` | `authenticated` | Client RPC (Flutter `supabase.rpc()`) |
| `financial_withdraw` | `authenticated` | Client RPC (Flutter `supabase.rpc()`) |
| `financial_deposit_record` | `service_role` | Server functions / Edge Functions only |
| `financial_deposit_record_verify` | `service_role` | Server functions / Edge Functions only |
| `financial_deposit_name_check` | `service_role` | Server functions / Edge Functions only |

**Client-side implications:**
- `PayoutAccountDataSource` calls `financial_payout_account_bind` and `financial_withdraw` via `supabase.rpc()` — these are `authenticated` RPCs, normal client execution
- `DepositDataSource` calls `financial_deposit_record`, `financial_deposit_record_verify`, and `financial_deposit_name_check` — but these are `service_role` only; client code must **never** call them directly
- The actual `service_role` execution is deferred to EP-02-18 Edge Function proxies; for now, `DepositDataSource` wraps these calls but the proxy implementation is not wired yet
- `PayoutAccountService` and `DepositService` use `supabase.auth.currentUser!.id` to enforce user identity on `authenticated` RPCs

### 4.3 Entity Definitions

#### `PayoutAccountModel` (DB representation)

```dart
class PayoutAccountModel {
  final String id;
  final String userId;
  final SupportedCurrency currency;
  final String accountNumber; // stored encrypted, displayed masked
  final String bankCode;
  final String bankName;
  final String accountName;
  final AccountVerificationStatus verificationStatus;
  final String? verificationReference;
  final DateTime? verifiedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  // ... fromJson, toJson, copyWith
}
```

#### `PayoutAccountEntity` (Domain representation)

```dart
class PayoutAccountEntity {
  final String id;
  final SupportedCurrency currency;
  final String maskedAccountNumber; // e.g., '***1234'
  final String bankCode;
  final String bankName;
  final String accountName;
  final AccountVerificationStatus verificationStatus;
  final DateTime? verifiedAt;
  final DateTime createdAt;
  // ... derived: isVerified, canWithdraw, daysUntilWithdrawal
}
```

#### `DepositModel` (DB representation)

```dart
class DepositModel {
  final String id;
  final String userId;
  final SupportedCurrency currency;
  final int amountMinorUnits;
  final String? reference;
  final String? senderName;
  final String? senderBankCode;
  final String? senderAccountNumber;
  final int? nameMatchScore;
  final DepositVerificationStatus verificationStatus;
  final String? verifiedBy;
  final DateTime? verifiedAt;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  // ... fromJson, toJson, copyWith
}
```

#### `DepositEntity` (Domain representation)

```dart
class DepositEntity {
  final String id;
  final SupportedCurrency currency;
  final int amountMinorUnits;
  final String? reference;
  final String? senderName;
  final int? nameMatchScore;
  final DepositVerificationStatus verificationStatus;
  final DateTime? verifiedAt;
  final DateTime createdAt;
  // ... derived: isVerified, formattedAmount, verificationLabel
}
```

#### `AccountVerificationStatus` (Payout)

```dart
enum AccountVerificationStatus {
  unverified,   // default on bind
  pending,      // verification initiated via proxy (EP-02-18)
  verified,     // name match confirmed
  failed,       // verification failed
}
```

#### `DepositVerificationStatus` (Deposit)

```dart
enum DepositVerificationStatus {
  unverified,   // initial state on record
  pending,      // verification in progress
  verified,     // name match confirmed, user credited
  failed,       // name match failed
}
```

### 4.4 Data Flow Diagrams

#### Payout Account Bind (Client → Server)

```
User enters account details
        ↓
PayoutAccountFormView
  - Validates form fields locally (account number format, bank selection)
        ↓
PayoutAccountProvider.addPayoutAccount()
        ↓
PayoutAccountService.bindAccount()
  - Sets user_id = Supabase.instance.client.auth.currentUser!.id
        ↓
PayoutAccountDataSource.bindPayoutAccount()
  - Calls supabase.rpc('financial_payout_account_bind', params: {...})
  - Returns PayoutAccountModel
        ↓
Supabase Edge Function: financial_payout_account_bind
  - SECURITY DEFINER, search_path = 'public, extensions'
  - Validates user_id = auth.uid() (enforced by RPC)
  - Checks currency+account+bank_code uniqueness via EXISTS
  - Checks 10-account-per-currency ceiling via COUNT
  - Inserts into payout_accounts via payout_account_insert_trigger
  - Returns new row
        ↓
PayoutAccountRepository caches result
        ↓
PayoutAccountProvider updates _payoutAccounts list
        ↓
UI rebuilds — new account appears in PayoutAccountView
```

#### Withdrawal Flow (Client → Server)

```
User enters withdrawal amount
        ↓
WithdrawalFormView (existing)
        ↓
FinanceService.initiateWithdrawal()
        ↓
PayoutAccountDataSource.withdraw()
  - Calls supabase.rpc('financial_withdraw', params: {...})
  - Returns withdrawal record
        ↓
Supabase Edge Function: financial_withdraw
  - Validates payout_account_id exists AND user owns it (payout_accounts.user_id = p_user_id)
  - Checks 48-hour new-account cooling-off window (payout_accounts.created_at > now() - interval '48 hours')
  - Checks balance via ledger_balance(p_user_id, p_currency)
  - Creates payouts row with status = 'pending'
  - Debits via ledger_debit(p_user_id, p_currency, p_amount_minor_units, ...)
  - Returns withdrawal record
        ↓
FinanceProvider updates ledger balance + transaction list
```

#### Deposit Recording (Server-Initiated Only)

```
External bank transfer detected (future: via webhook/polling)
        ↓
Server Function / Edge Function (service_role)
  - Calls financial_deposit_record(p_user_id, p_currency, p_amount_minor_units, ...)
  - levenshtein() match against p_user_id's payout_accounts rows
  - Automatically derives verification_status
  - Inserts into deposits table
        ↓
Deposit record created — user sees it in TransactionHistoryView
        ↓
(EP-02-18: Proxy Edge Function calls financial_deposit_name_check to get match score)
```

#### Deposit Name Verification (Server-Initiated Only)

```
Deposit record exists, needs verification
        ↓
Server Function / Edge Function (service_role)
  - Calls financial_deposit_record_verify(p_deposit_id, p_verified_by_user_id)
  - Sets verified_by, verified_at, verification_status = 'verified'
        ↓
Deposit status updated — user sees 'Verified' badge in TransactionHistoryView
```

### 4.5 File Change Map

**New Files to Create (23 files):**

| File | What Goes There |
|------|----------------|
| `lib/data/entities/financial/payout_account_model.dart` | `PayoutAccountModel` with JSON serialization |
| `lib/data/entities/financial/payout_account_entity.dart` | `PayoutAccountEntity` domain model |
| `lib/data/entities/financial/payout_account_mapper.dart` | DB ↔ Domain conversion |
| `lib/data/entities/financial/deposit_model.dart` | `DepositModel` with JSON serialization |
| `lib/data/entities/financial/deposit_entity.dart` | `DepositEntity` domain model |
| `lib/data/entities/financial/deposit_mapper.dart` | DB ↔ Domain conversion |
| `lib/core/api/datasources/payout_account_data_source.dart` | `PayoutAccountDataSource` (authenticated RPC wrappers) |
| `lib/core/api/datasources/deposit_data_source.dart` | `DepositDataSource` (service_role RPC wrappers — proxy deferred to EP-02-18) |
| `lib/data/repositories/payout_account_repository.dart` | `PayoutAccountRepository` (caching + data access) |
| `lib/data/repositories/deposit_repository.dart` | `DepositRepository` (caching + data access) |
| `lib/data/providers/payout_account_provider.dart` | `PayoutAccountProvider` (ChangeNotifier) |
| `lib/data/providers/deposit_provider.dart` | `DepositProvider` (ChangeNotifier) |
| `lib/systems/finance/models/account_verification_status.dart` | `AccountVerificationStatus` enum (payout) |
| `lib/systems/finance/models/deposit_verification_status.dart` | `DepositVerificationStatus` enum (deposit) |
| `lib/systems/finance/services/payout_account_service.dart` | `PayoutAccountService` (business logic) |
| `lib/systems/finance/services/deposit_service.dart` | `DepositService` (business logic) |
| `lib/systems/finance/services/deposit_name_match_service.dart` | `DepositNameMatchService` (name match RPC caller — proxy deferred to EP-02-18) |
| `lib/features/finance/screens/payout_account_view.dart` | `PayoutAccountView` (account list) |
| `lib/features/finance/screens/payout_account_form_view.dart` | `PayoutAccountFormView` (add/edit form) |
| `lib/features/finance/screens/payout_account_limit_display.dart` | `PayoutAccountLimitDisplay` (KYC-tiered limits) |
| `lib/features/finance/screens/deposit_details_panel.dart` | `DepositDetailsPanel` (amount field + conversion preview) |
| `lib/features/finance/screens/deposit_name_match_indicator.dart` | `DepositNameMatchIndicator` (match status display) |

**Existing Files to Modify (5 files):**

| File | What Changes |
|------|-------------|
| `lib/systems/finance/finance.dart` | Add exports for all new models, services, providers |
| `lib/data/data_layer.dart` | Add exports for new entities, DTOs, repositories, providers |
| `lib/features/finance/screens/finance_screen.dart` | Add payout account section (within scope), add deposit entry section |
| `lib/features/finance/screens/transaction_history_view.dart` | Show payout/deposit records, add verification status badges |
| `lib/data/providers/finance_provider.dart` | Wire payout account and deposit providers as dependencies |

### 4.6 Validation Rules

**Payout Account Bind (`financial_payout_account_bind`):**
- `p_user_id` must equal `auth.uid()` (enforced by `authenticated` RPC)
- `p_currency` must be valid `SupportedCurrency`
- `p_account_number` must be valid NUBAN format (10 digits)
- `p_bank_code` must not be null/empty
- `p_account_name` must not be null/empty
- `EXISTS (SELECT 1 FROM payout_accounts WHERE user_id = p_user_id AND currency = p_currency AND account_number = p_account_number AND bank_code = p_bank_code)` must be `false` — no duplicate account+bank per currency per user
- `COUNT (SELECT 1 FROM payout_accounts WHERE user_id = p_user_id AND currency = p_currency)` must be `< 10` — max 10 accounts per currency
- Inserted via `payout_account_insert_trigger` which sets `verification_status = 'unverified'`

**Withdrawal (`financial_withdraw`):**
- `p_user_id` must equal `auth.uid()` (enforced by `authenticated` RPC)
- Payout account must exist AND `user_id = p_user_id`
- New-account cooling-off: `payout_accounts.created_at > now() - interval '48 hours'` must be `false` (account must be at least 48 hours old)
- `ledger_balance(p_user_id, p_currency)` must be `>= p_amount_minor_units`
- `p_amount_minor_units` must be `> 0`

**Deposit Record (`financial_deposit_record` — service_role only):**
- `p_user_id` must exist
- `p_currency` must be valid
- `p_amount_minor_units` must be `> 0`
- `levenshtein()` match score computed automatically against `p_user_id`'s payout accounts
- `verification_status` derived from match score

### 4.7 Error Handling

**Data Source Level (`PayoutAccountDataSource`, `DepositDataSource`):**
- Catch `PostgrestException` → wrap in `ApiException`
- Preserve original error message for server-side logging
- Map to appropriate `ApiExceptionType`

**Service Level (`PayoutAccountService`, `DepositService`):**
- Catch `ApiException` → wrap in domain-specific exceptions
- `PayoutAccountException` with types: `accountLimitReached`, `duplicateAccount`, `accountNotFound`, `coolingOffPeriod`, `insufficientBalance`
- `DepositException` with types: `depositNotFound`, `verificationFailed`, `unauthorizedVerification`

**Provider Level (`PayoutAccountProvider`, `DepositProvider`):**
- Catch domain exceptions → set error state
- Expose `errorMessage` getter for UI consumption
- Reset error state on next action

**UI Level:**
- Display error messages via `SnackBar` or inline error widgets
- Preserve form state on validation errors
- Show loading indicators during async operations
- Graceful degradation when name match score is unavailable

### 4.8 Testing Approach

**Unit Tests:**
- `PayoutAccountModel` — JSON serialization round-trip
- `PayoutAccountEntity` — derived fields (`isVerified`, `canWithdraw`, `daysUntilWithdrawal`)
- `PayoutAccountMapper` — DB ↔ Domain conversion accuracy
- `DepositModel` — JSON serialization round-trip
- `DepositEntity` — derived fields (`isVerified`, `formattedAmount`, `verificationLabel`)
- `DepositMapper` — DB ↔ Domain conversion accuracy
- `AccountVerificationStatus` — enum values and serialization
- `DepositVerificationStatus` — enum values and serialization

**Widget Tests:**
- `PayoutAccountView` — renders account list, handles empty state, shows verification badges
- `PayoutAccountFormView` — form validation, bank selection, account number format
- `PayoutAccountLimitDisplay` — shows correct KYC-tiered limits
- `DepositDetailsPanel` — amount input, currency selection, conversion preview
- `DepositNameMatchIndicator` — shows correct status for each verification state
- `TransactionHistoryView` — renders payout/deposit records with correct badges

**Integration Tests:**
- Full payout account bind flow (form → service → data source → mock RPC → repository → provider → UI)
- Full withdrawal flow (amount → service → data source → mock RPC → provider → UI)
- Deposit recording flow (server → data source → mock RPC → repository → provider → UI)
- Name verification flow (server → data source → mock RPC → provider → UI)
- Error handling flows (duplicate account, account limit reached, cooling off period, insufficient balance)

### 4.9 Migration Verification

Before starting implementation, verify the frozen schema supports all required operations:

```bash
# Confirm zero DDL — schema is frozen
git diff --stat supabase/
# Expected: no output (zero DDL changes)

# Confirm payout_accounts table exists with required columns
psql -c "\d payout_accounts"
# Expected columns: id, user_id, currency, account_number, bank_code, bank_name, account_name, verification_status, verification_reference, verified_at, created_at, updated_at

# Confirm deposits table exists with required columns
psql -c "\d deposits"
# Expected columns: id, user_id, currency, amount_minor_units, reference, sender_name, sender_bank_code, sender_account_number, name_match_score, verification_status, verified_by, verified_at, notes, created_at, updated_at

# Confirm required RPCs exist
psql -c "SELECT proname FROM pg_proc WHERE proname IN ('financial_payout_account_bind', 'financial_withdraw', 'financial_deposit_record', 'financial_deposit_record_verify', 'financial_deposit_name_check')"
# Expected: 5 rows

# Confirm payout_account_insert_trigger exists
psql -c "SELECT tgname FROM pg_trigger WHERE tgname = 'payout_account_insert_trigger'"
# Expected: 1 row

# Confirm levenshtein function exists (for name matching)
psql -c "SELECT proname FROM pg_proc WHERE proname = 'levenshtein'"
# Expected: 1 row

# Confirm ledger_balance function exists (for withdrawal balance check)
psql -c "SELECT proname FROM pg_proc WHERE proname = 'ledger_balance'"
# Expected: 1 row
```

### 4.10 Execution Justification

This task receives an **Very High** execution justification level for the following reasons:

**Critical Financial Security Impact:**
- Payout account bind controls withdrawal routing — errors could lead to funds being sent to wrong accounts
- Withdrawal validation (48-hour cooling-off, balance check, account ownership) is critical financial safety
- Deposit name matching (`AGENT.md` Rule 3) directly affects whether funds are attributed to the correct user

**Complex Multi-Model Interactions:**
- 5 distinct RPC functions across 3 security tiers (`authenticated` vs `service_role`)
- Complex server-side validation logic (levenshtein matching, KYC-tiered limits, 48-hour cooling-off)
- Service_role boundary must be strictly maintained — client code must never call `financial_deposit_record` or `financial_deposit_record_verify` directly

**Security Boundary (Rule 1):**
- Payout account data (full account numbers, bank codes) is server-side only
- `PayoutAccountEntity` exposes only masked account numbers (`***1234`)
- `HivorrLogger` + `PiiRedactor` must mask `entityId`, `accountNumber`, `payerName` in all log statements
- No `service_role` string anywhere in `lib/` — enforced via grep

**Horizontal Integration Complexity:**
- Integrates with 4 existing systems: KYC (EP-02-12) for tiered limits, Ledger (EP-02-04) for balance checks, Payment Gateways (EP-02-09) for name enquiry, Escrow (EP-02-14) indirectly via withdrawal flow
- Each integration point has specific API contracts that must be respected

**Frozen Schema Constraint:**
- Zero DDL modifications permitted — all operations must work within the existing schema
- Requires careful alignment between Dart entities and SQL table definitions

---

## 5. Required Systems

### 5.1 Prerequisite Systems

**Already Completed (verify existence):**
- `KycRepository` (EP-02-12) — for `KycTier.cashoutLimit` per tier
- `FinanceService` (EP-02-04) — for `ledger_balance()`, `ledger_debit()`, `SupportedCurrency`
- `NameEnquiryService` (EP-02-09) — for name match scoring in `DepositNameMatchService`
- `LedgerRepository` (EP-02-04) — for balance queries

**Systems This Task Extends:**
- `FinanceService` — `PayoutAccountService` and `DepositService` are peers in `lib/systems/finance/services/`
- `FinanceProvider` — `PayoutAccountProvider` and `DepositProvider` are peers in `lib/data/providers/`
- `TransactionHistoryView` — extended with payout/deposit records

### 5.2 Key Integration Points

**With KYC System (EP-02-12):**
```dart
// PayoutAccountService reads KYC tier for cashout limit
final kycTier = await _kycRepository.getVerificationTier(userId);
final cashoutLimit = kycTier.cashoutLimit; // per-currency limit in minor units
```

**With Ledger System (EP-02-04):**
```dart
// PayoutAccountService checks balance before withdrawal
final balance = await _ledgerRepository.getBalance(userId, currency);
if (balance < amountMinorUnits) {
  throw InsufficientBalanceException();
}
```

**With Payment Gateways (EP-02-09):**
```dart
// DepositNameMatchService uses NameEnquiryService for name matching
final nameResult = await _nameEnquiryService.verifyAccountName(
  bankCode: deposit.senderBankCode,
  accountNumber: deposit.senderAccountNumber,
);
```

---

## 6. Data Requirements

### 6.1 Entities to Create

| Entity | Location | Purpose |
|--------|----------|---------|
| `PayoutAccountModel` | `lib/data/entities/financial/payout_account_model.dart` | DB representation with JSON serialization |
| `PayoutAccountEntity` | `lib/data/entities/financial/payout_account_entity.dart` | Domain model with masked account numbers |
| `PayoutAccountMapper` | `lib/data/entities/financial/payout_account_mapper.dart` | DB ↔ Domain conversion |
| `DepositModel` | `lib/data/entities/financial/deposit_model.dart` | DB representation with JSON serialization |
| `DepositEntity` | `lib/data/entities/financial/deposit_entity.dart` | Domain model |
| `DepositMapper` | `lib/data/entities/financial/deposit_mapper.dart` | DB ↔ Domain conversion |

### 6.2 Repository Patterns

Follow `LedgerRepository` pattern from EP-02-04:
```dart
class PayoutAccountRepository {
  final PayoutAccountDataSource _dataSource;
  final List<PayoutAccountEntity> _cache = [];
  
  Future<List<PayoutAccountEntity>> getPayoutAccounts(String userId, SupportedCurrency currency);
  Future<PayoutAccountEntity> addPayoutAccount({...});
  Future<void> removePayoutAccount(String accountId);
}
```

### 6.3 Provider Patterns

Follow `FinanceProvider` pattern from EP-02-04:
```dart
class PayoutAccountProvider extends ChangeNotifier {
  final PayoutAccountService _service;
  List<PayoutAccountEntity> _payoutAccounts = [];
  bool _isLoading = false;
  String? _errorMessage;
  
  // Getters, actions, error handling
}
```

### 6.4 Data Source Patterns

Follow `BaseApiService` pattern:
```dart
class PayoutAccountDataSource {
  Future<Map<String, dynamic>> bindPayoutAccount({...});
  Future<Map<String, dynamic>> withdraw({...});
}

class DepositDataSource {
  Future<Map<String, dynamic>> recordDeposit({...});
  Future<Map<String, dynamic>> verifyDeposit({...});
  Future<Map<String, dynamic>> checkNameMatch({...});
}
```

---

## 7. Database Considerations

### 7.1 Migration Status

**NO NEW MIGRATION REQUIRED** — schema is frozen at `supabase/migrations/20260829100004_financial_integrity_schema.sql`

The existing schema provides:
- `payout_accounts` table (lines 260-290)
- `payouts` table (lines 292-322)
- `deposits` table (lines 324-353)
- `payout_account_insert_trigger` (lines 442-475)
- All required RPCs (lines 1150-1457)
- `levenshtein()` function for name matching
- `ledger_balance()` and `ledger_debit()` functions
- RLS policies (lines 605-618)
- Grants (lines 541-557)

### 7.2 Schema Verification Checklist

```sql
-- Payout accounts columns
SELECT column_name, data_type FROM information_schema.columns 
WHERE table_name = 'payout_accounts' ORDER BY ordinal_position;
-- Expected: id (uuid), user_id (uuid), currency (text), account_number (text), 
--           bank_code (text), bank_name (text), account_name (text), 
--           verification_status (text), verification_reference (text), 
--           verified_at (timestamptz), created_at (timestamptz), updated_at (timestamptz)

-- Deposits columns
SELECT column_name, data_type FROM information_schema.columns 
WHERE table_name = 'deposits' ORDER BY ordinal_position;
-- Expected: id (uuid), user_id (uuid), currency (text), amount_minor_units (bigint), 
--           reference (text), sender_name (text), sender_bank_code (text), 
--           sender_account_number (text), name_match_score (integer), 
--           verification_status (text), verified_by (uuid), verified_at (timestamptz), 
--           notes (text), created_at (timestamptz), updated_at (timestamptz)

-- RPC signatures
SELECT proname, proargtypes::regtype[] FROM pg_proc 
WHERE proname IN ('financial_payout_account_bind', 'financial_withdraw', 
                   'financial_deposit_record', 'financial_deposit_record_verify',
                   'financial_deposit_name_check');
```

---

## 8. API Requirements

### 8.1 Server Functions (RPCs)

**`financial_payout_account_bind`** — `authenticated`
- Params: `p_user_id uuid, p_currency text, p_account_number text, p_bank_code text, p_bank_name text, p_account_name text`
- Returns: `payout_accounts` row
- Security: `user_id = auth.uid()` enforced by `authenticated` tier; uniqueness + ceiling checks in function body

**`financial_withdraw`** — `authenticated`
- Params: `p_user_id uuid, p_currency text, p_amount_minor_units bigint, p_payout_account_id uuid`
- Returns: `payouts` row
- Security: `user_id = auth.uid()` enforced; 48-hour cooling-off + balance + account ownership checks in function body

**`financial_deposit_record`** — `service_role`
- Params: `p_user_id uuid, p_currency text, p_amount_minor_units bigint, p_reference text, p_sender_name text, p_sender_bank_code text, p_sender_account_number text`
- Returns: `deposits` row with computed `name_match_score` and `verification_status`
- Security: `service_role` only — clients must never call this directly

**`financial_deposit_record_verify`** — `service_role`
- Params: `p_deposit_id uuid, p_verified_by_user_id uuid`
- Returns: updated `deposits` row
- Security: `service_role` only

**`financial_deposit_name_check`** — `service_role`
- Params: `p_deposit_id uuid`
- Returns: name match score for existing deposit
- Security: `service_role` only

### 8.2 Client-Side RPC Calls

**Allowed (authenticated):**
```dart
// PayoutAccountDataSource
await supabase.rpc('financial_payout_account_bind', params: {...});
await supabase.rpc('financial_withdraw', params: {...});
```

**Prohibited from client (service_role):**
```dart
// These must NEVER be called from lib/ code:
// await supabase.rpc('financial_deposit_record', params: {...});
// await supabase.rpc('financial_deposit_record_verify', params: {...});
// await supabase.rpc('financial_deposit_name_check', params: {...});
```

---

## 9. UI Requirements

### 9.1 Component Inventory

**New Components:**

| Component | Location | Purpose |
|-----------|----------|---------|
| `PayoutAccountView` | `lib/features/finance/screens/payout_account_view.dart` | List of bound payout accounts per currency |
| `PayoutAccountFormView` | `lib/features/finance/screens/payout_account_form_view.dart` | Form to add/edit payout account |
| `PayoutAccountLimitDisplay` | `lib/features/finance/screens/payout_account_limit_display.dart` | Shows KYC-tiered cashout limit |
| `DepositDetailsPanel` | `lib/features/finance/screens/deposit_details_panel.dart` | Structured amount field + currency conversion preview |
| `DepositNameMatchIndicator` | `lib/features/finance/screens/deposit_name_match_indicator.dart` | Visual indicator of name match status |

**Modified Components:**

| Component | Changes |
|-----------|---------|
| `FinanceScreen` | Add payout account section + deposit entry section (within scope) |
| `TransactionHistoryView` | Show payout/deposit records + verification status badges |

### 9.2 UI Flow: Payout Account Management

```
FinanceScreen
  └── PayoutAccountView (tab/section)
        ├── Currency tabs (NGN, USD, GBP, EUR)
        ├── List of PayoutAccountCards
        │     ├── Masked account number (***1234)
        │     ├── Bank name + code
        │     ├── Account name
        │     ├── Verification badge (Unverified/Pending/Verified/Failed)
        │     └── Delete button (if not primary)
        ├── "Add Account" button → PayoutAccountFormView
        │     ├── Currency selector (disabled if already bound for that currency)
        │     ├── Bank selector (NIBSS bank list)
        │     ├── Account number input (10-digit NUBAN)
        │     ├── Account name (auto-populated via name enquiry)
        │     └── "Bind Account" button
        └── PayoutAccountLimitDisplay
              ├── Current KYC tier
              ├── Cashout limit per transaction
              ├── Daily limit
              └── Monthly limit
```

### 9.3 UI Flow: Deposit Entry

```
FinanceScreen
  └── DepositDetailsPanel (section)
        ├── Currency selector (NGN, USD, GBP, EUR)
        ├── Amount input field (numeric)
        ├── Real-time conversion preview
        │     ├── "You will receive: NGN 1,500,000"
        │     ├── Exchange rate display
        │     └── Last updated timestamp
        ├── Reference field (optional)
        └── "Deposit" button → initiates deposit flow
```

### 9.4 UI Flow: Transaction History Verification

```
TransactionHistoryView
  └── TransactionItem (deposit type)
        ├── Amount + currency
        ├── Date/time
        ├── Sender info (if available)
        └── DepositVerificationStatus badge
              ├── Unverified — gray
              ├── Pending — yellow with spinner
              ├── Verified — green with checkmark
              └── Failed — red with X
```

### 9.5 Styling Requirements

- **Verification badges:** Use `AppTheme` color tokens — no hardcoded `Colors.*`
- **Account cards:** Follow existing card patterns in `FinanceScreen`
- **Form inputs:** Use `AppTheme` input decoration consistently
- **Conversion preview:** Subtle background, smaller font, secondary text color
- **Error states:** Inline error messages below form fields
- **Loading states:** `CircularProgressIndicator` within buttons during async operations

---

## 10. UX Considerations

### 10.1 User Experience Principles

- **Progressive disclosure:** Show payout accounts per currency tab, not all at once
- **Immediate feedback:** Real-time conversion preview as user types amount
- **Graceful degradation:** If name match score unavailable, show "Pending" not error
- **Error prevention:** Disable "Bind Account" button until all fields valid
- **Transparency:** Always show verification status clearly

### 10.2 Edge Cases to Handle

- **Empty state:** No payout accounts bound yet — show explainer + CTA
- **Account limit reached:** Show "Maximum accounts reached for this currency"
- **Duplicate account:** Show "This account is already bound"
- **Cooling-off period:** Show "New accounts have a 48-hour waiting period before withdrawals"
- **Insufficient balance:** Show current balance + required amount
- **Name match failure:** Show "Name verification failed — contact support"

### 10.3 Accessibility

- All form fields have labels (no placeholder-only inputs)
- Verification badges use both color AND text (not color alone)
- Error messages are announced via `Semantics` for screen readers
- Minimum touch target size 48x48dp for all interactive elements

---

## 11. Security Considerations

### 11.1 PII Protection

- **Account numbers:** Always masked in UI (`***1234`) and in `PayoutAccountEntity`
- **Full account numbers:** Only in `PayoutAccountModel` (DB representation), never exposed to UI
- **Account names:** Logged via `HivorrLogger` with `PiiRedactor` masking
- **Sender names:** Logged via `HivorrLogger` with `PiiRedactor` masking
- **Entity IDs:** Logged via `HivorrLogger` with `PiiRedactor` masking

### 11.2 Server-Side Enforcement

- `financial_payout_account_bind`: `user_id = auth.uid()` enforced by `authenticated` RPC
- `financial_withdraw`: `user_id = auth.uid()` enforced by `authenticated` RPC
- `financial_deposit_record`: `service_role` only — never callable from client
- `financial_deposit_record_verify`: `service_role` only — never callable from client
- `financial_deposit_name_check`: `service_role` only — never callable from client
- All RPCs have `SECURITY DEFINER` + `search_path = 'public, extensions'`

### 11.3 Client-Side Guards

- `PayoutAccountService` enforces user identity: `Supabase.instance.client.auth.currentUser!.id`
- `DepositService` never calls `service_role` RPCs directly — only wraps proxy calls (EP-02-18)
- No `service_role` string anywhere in `lib/` — enforced via grep in CI
- No hardcoded bank codes or account numbers

### 11.4 RLS Policies

Existing RLS policies on `payout_accounts` and `deposits` enforce:
- Users can only read their own payout accounts
- Users can only read their own deposits
- Inserts/updates/deletes handled by RPCs with `SECURITY DEFINER`

### 11.5 Audit Trail

- All payout account binds logged with timestamp, user_id, currency, bank_code (not account_number)
- All withdrawals logged with amount, currency, payout_account_id
- All deposits logged with amount, currency, sender_name (via PiiRedactor)
- Name match scores logged for audit purposes

---

## 12. Performance Considerations

### 12.1 Database Performance

- `payout_accounts` has indexes on `user_id` and `(user_id, currency)` — already in migration
- `deposits` has indexes on `user_id` and `(user_id, currency)` — already in migration
- `levenshtein()` function is called server-side only — no client-side computation
- `ledger_balance()` is a server-side function — no client-side balance calculation

### 12.2 Caching Strategy

- `PayoutAccountRepository` caches payout accounts per user in memory
- `DepositRepository` caches deposits per user in memory
- Cache invalidated on write operations (bind, withdraw, verify)
- Realtime subscriptions optional — not required for MVP

### 12.3 Network Optimization

- `PayoutAccountDataSource` batches RPC calls where possible
- `DepositDataSource` minimizes round trips — single RPC per operation
- No polling for verification status — user refreshes manually or navigates away/back

---

## 13. Testing Strategy

### 13.1 Test Pyramid

| Layer | Count | Focus |
|-------|-------|-------|
| Unit | 18-22 | Entities, mappers, enums, service logic |
| Widget | 12-15 | All new UI components |
| Integration | 6-8 | Full flows: bind, withdraw, deposit, verify |
| E2E | 2-3 | Critical paths only |

### 13.2 Key Test Scenarios

**Payout Account Bind:**
- Happy path: bind account → appears in list
- Duplicate: bind same account+bank+currency → error
- Limit reached: bind 11th account for currency → error
- Validation: invalid account number format → error
- Validation: empty bank code → error

**Withdrawal:**
- Happy path: withdraw from bound account → balance decreases
- Insufficient balance: withdraw more than balance → error
- Cooling-off: withdraw from account < 48 hours old → error
- Wrong account: withdraw from account not bound to user → error

**Deposit Recording:**
- Happy path: record deposit → appears in transaction list
- High name match: score > 80 → status = 'verified'
- Low name match: score < 80 → status = 'unverified'
- No match: no sender name → status = 'unverified'

**Deposit Verification:**
- Happy path: verify deposit → status = 'verified', verified_at set
- Double verify: verify already verified deposit → idempotent

### 13.3 Test File Locations

```
test/
  data/entities/financial/
    payout_account_model_test.dart
    payout_account_entity_test.dart
    payout_account_mapper_test.dart
    deposit_model_test.dart
    deposit_entity_test.dart
    deposit_mapper_test.dart
  systems/finance/services/
    payout_account_service_test.dart
    deposit_service_test.dart
    deposit_name_match_service_test.dart
  features/finance/screens/
    payout_account_view_test.dart
    payout_account_form_view_test.dart
    payout_account_limit_display_test.dart
    deposit_details_panel_test.dart
    deposit_name_match_indicator_test.dart
    transaction_history_view_test.dart
```

---

## 14. Implementation Sequence

### Phase 1: Foundation (Steps 1-5)

| Step | Task | Files |
|------|------|-------|
| 1 | Baseline inspection: verify schema, entities, `NameEnquiryService` contracts | `supabase/migrations/...`, `lib/integrations/payment_gateways/` |
| 2 | Create `AccountVerificationStatus` enum | `lib/systems/finance/models/account_verification_status.dart` |
| 3 | Create `DepositVerificationStatus` enum | `lib/systems/finance/models/deposit_verification_status.dart` |
| 4 | Create `PayoutAccountModel` entity | `lib/data/entities/financial/payout_account_model.dart` |
| 5 | Create `PayoutAccountEntity` domain model | `lib/data/entities/financial/payout_account_entity.dart` |

### Phase 2: Payout Account System (Steps 6-11)

| Step | Task | Files |
|------|------|-------|
| 6 | Create `PayoutAccountMapper` | `lib/data/entities/financial/payout_account_mapper.dart` |
| 7 | Create `PayoutAccountDataSource` | `lib/core/api/datasources/payout_account_data_source.dart` |
| 8 | Create `PayoutAccountRepository` | `lib/data/repositories/payout_account_repository.dart` |
| 9 | Create `PayoutAccountService` | `lib/systems/finance/services/payout_account_service.dart` |
| 10 | Create `PayoutAccountProvider` | `lib/data/providers/payout_account_provider.dart` |
| 11 | Update barrel exports (`finance.dart`, `data_layer.dart`) | `lib/systems/finance/finance.dart`, `lib/data/data_layer.dart` |

### Phase 3: Deposit System (Steps 12-16)

| Step | Task | Files |
|------|------|-------|
| 12 | Create `DepositModel` entity | `lib/data/entities/financial/deposit_model.dart` |
| 13 | Create `DepositEntity` domain model | `lib/data/entities/financial/deposit_entity.dart` |
| 14 | Create `DepositMapper` | `lib/data/entities/financial/deposit_mapper.dart` |
| 15 | Create `DepositDataSource` | `lib/core/api/datasources/deposit_data_source.dart` |
| 16 | Create `DepositRepository` | `lib/data/repositories/deposit_repository.dart` |

### Phase 4: Deposit Services (Steps 17-19)

| Step | Task | Files |
|------|------|-------|
| 17 | Create `DepositService` | `lib/systems/finance/services/deposit_service.dart` |
| 18 | Create `DepositNameMatchService` | `lib/systems/finance/services/deposit_name_match_service.dart` |
| 19 | Create `DepositProvider` | `lib/data/providers/deposit_provider.dart` |

### Phase 5: UI Components (Steps 20-23)

| Step | Task | Files |
|------|------|-------|
| 20 | Create `PayoutAccountView` + `PayoutAccountFormView` + `PayoutAccountLimitDisplay` | `lib/features/finance/screens/payout_account_*.dart` |
| 21 | Create `DepositDetailsPanel` + `DepositNameMatchIndicator` | `lib/features/finance/screens/deposit_*.dart` |
| 22 | Modify `FinanceScreen` — add payout account + deposit sections | `lib/features/finance/screens/finance_screen.dart` |
| 23 | Modify `TransactionHistoryView` — add payout/deposit records + verification badges | `lib/features/finance/screens/transaction_history_view.dart` |

---

## 15. Expected Outcome

### 15.1 Definition of Done

- [ ] All 23 implementation steps completed
- [ ] All new files created in correct directory locations
- [ ] All existing files modified without breaking changes
- [ ] `PayoutAccountModel` serializes/deserializes correctly
- [ ] `PayoutAccountEntity` derives `maskedAccountNumber`, `isVerified`, `canWithdraw` correctly
- [ ] `PayoutAccountMapper` converts between DB ↔ Domain accurately
- [ ] `DepositModel` serializes/deserializes correctly
- [ ] `DepositEntity` derives `isVerified`, `formattedAmount`, `verificationLabel` correctly
- [ ] `DepositMapper` converts between DB ↔ Domain accurately
- [ ] `PayoutAccountDataSource` calls only `authenticated` RPCs
- [ ] `DepositDataSource` never calls `service_role` RPCs from client code
- [ ] `PayoutAccountService` enforces user identity via `auth.currentUser!.id`
- [ ] `DepositService` never exposes `service_role` calls to client
- [ ] `PayoutAccountProvider` manages state correctly (loading, error, success)
- [ ] `DepositProvider` manages state correctly (loading, error, success)
- [ ] `PayoutAccountView` renders account list with verification badges
- [ ] `PayoutAccountFormView` validates form and calls service correctly
- [ ] `PayoutAccountLimitDisplay` shows correct KYC-tiered limits
- [ ] `DepositDetailsPanel` shows real-time conversion preview
- [ ] `DepositNameMatchIndicator` shows correct verification status
- [ ] `TransactionHistoryView` shows payout/deposit records with badges
- [ ] `FinanceScreen` has payout account + deposit sections
- [ ] Zero DDL changes: `git diff --stat supabase/` = 0
- [ ] No `service_role` in `lib/`: `grep -r "service_role" lib/` = 0
- [ ] No hardcoded `Colors.*` in `lib/systems/finance/` or `lib/data/`
- [ ] All log statements use `HivorrLogger` + `PiiRedactor`
- [ ] All account numbers masked as `***1234` in UI
- [ ] All unit tests pass
- [ ] All widget tests pass
- [ ] All integration tests pass

### 15.2 Success Metrics

- **Functional:** Users can bind payout accounts, view KYC-tiered limits, enter deposits with conversion preview, see verification status in transaction history
- **Security:** Zero `service_role` calls from client code; zero PII leaks in logs; all account numbers masked
- **Performance:** Payout account list loads in < 500ms; deposit conversion preview updates in < 100ms
- **Code Quality:** All files follow existing patterns; no architecture violations; all barrel exports updated

---

## 16. AI Execution Profile

| Parameter | Value |
|-----------|-------|
| **Execution Justification Level** | Very High |
| **Justification Reason** | Critical financial security (payout routing, withdrawal validation, deposit attribution) + 5 RPC functions across 3 security tiers + 4-system horizontal integration + frozen schema constraint |
| **Reasoning Depth** | Extensive — complex multi-model interactions, service_role boundary enforcement, KYC-tiered limit integration |
| **Autonomy Level** | High — clear specifications, but verify each step against AGENT.md rules |
| **Verification Checkpoints** | After each phase (1-5): grep for `service_role` in `lib/`, verify no hardcoded colors, verify barrel exports, run tests |

---

## 17. Appendix

### A. Glossary

| Term | Definition |
|------|-----------|
| **NUBAN** | Nigerian Uniform Bank Account Number (10 digits) |
| **Payout Account** | A bound bank account for receiving withdrawals |
| **Name Match Score** | `levenshtein()` distance between deposit sender name and payout account name |
| **KYC Tier** | User verification level (Tier 1-3) determining cashout limits |
| **Service Role** | Supabase role with elevated privileges — only callable from server-side |
| **Authenticated** | Supabase role for logged-in users — callable from client with valid JWT |

### B. Related Documents

- `AGENT.md` — Rules 1-5 (security guardrails)
- `ARCHITECTURE.md` — Directory structure, separation of concerns
- `EP-02 Trust, Identity & Financial Integrity Engine.md` — Phase plan
- `EP-02-12-KYC Integration Framework.md` — KycRepository for tiered limits
- `EP-02-04-Ledger System.md` — FinanceService, LedgerRepository
- `EP-02-09-Payment Gateway Integration.md` — NameEnquiryService
- `EP-02-13-Multi-Currency Financial Profile.md` — Pattern reference
- `EP-02-14-Escrow & Milestone Payment.md` — Pattern reference
- `EP-02-15-Currency Conversion Infrastructure.md` — Pattern reference
