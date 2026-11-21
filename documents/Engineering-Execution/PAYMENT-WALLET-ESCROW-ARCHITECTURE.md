# Hivorr Payment, Wallet and Internal Escrow Architecture

| Field | Value |
|---|---|
| **Document** | `documents/Engineering-Execution/PAYMENT-WALLET-ESCROW-ARCHITECTURE.md` |
| **Status** | **APPROVED — product and custody model, 15 November 2026** |
| **Authority** | Founder (AfriNova) |
| **Supersedes** | BD-D01 partner-held custody model for the product architecture |
| **Legal/regulatory confirmation** | **OPEN** — counsel and VFD written confirmation still required |
| **Applies to** | EP-02 finance, wallet, escrow, payout and reconciliation work |

> **Decision.** Hivorr will operate a pooled collection and settlement account under a VFD-approved
> banking arrangement, maintain individual wallet balances in its internal ledger, and run its own
> internal escrow reservation and release logic. VFD receives deposits, provides virtual accounts,
> confirms transactions and executes payouts. Hivorr determines wallet, escrow, release and withdrawal
> state.
>
> **Legal condition.** This is the approved product and engineering model. It is not a legal opinion
> or a regulatory authorisation. Counsel must confirm the licensing, safeguarding, segregation,
> insolvency and reporting treatment of the pooled account before production. VFD must confirm in
> writing that the account structure and the marketplace escrow use case are permitted.

---

## 1. Account and money flow

1. Every registered user is assigned an individual VFD virtual account for deposits. The virtual
   account is a **collection identifier**, not a separately held balance: the funds settle into the
   central pool account described in step 5.
2. The user transfers money to that virtual account.
3. VFD receives the payment and notifies Hivorr.
4. Hivorr verifies the transaction, matches the payer, and credits the user’s internal wallet.
5. Collected funds sit in Hivorr’s designated general collection and settlement account under the
   VFD-approved banking arrangement.
6. Hivorr records individual wallet balances, reserved funds, earnings and withdrawals in its ledger.
7. When a user requests a withdrawal, Hivorr verifies the available balance, reserves the amount and
   sends a payout instruction to VFD.
8. VFD transfers from the designated payout/general pool account to the user’s registered bank account.
9. Hivorr records the confirmed payout and updates the wallet and withdrawal records.

## 2. Ledger model

The ledger is the source of truth for Hivorr’s internal obligations, not for the bank’s legal ownership
of the pooled funds.

| Account kind | Purpose |
|---|---|
| `user_wallet` | Beneficial wallet balance per account |
| `escrow` | Funds reserved against a specific job, order or errand |
| `platform_clearing` | Deposits received but not yet posted to a wallet |
| `payout_payable` | Withdrawal reserved and awaiting provider confirmation |
| `fee_revenue` | Platform fees, when fee rules are approved |
| `commission_payable` | Partner/commission obligations, when approved |
| `adjustment` | Controlled correction account; reversing entries only |

Rules:

- Double-entry, append-only; every entry balances to zero per currency.
- No mutable `balance` column. Wallet figures are derived views.
- Corrections are reversing entries, never updates or deletes.
- Every deposit and withdrawal is idempotent and traceable to a provider reference.
- A user’s available balance is `wallet credits − reserved escrow − reserved payouts − holds`.
- Negative available balance is impossible; the service and database both refuse it.
- Every posting carries its activity attribution where one exists.

## 3. Internal escrow

Internal escrow is a **ledger reservation**, not a separate legal escrow.

- A funded job reserves the full contract value against the job’s escrow account.
- A release moves the approved amount from escrow to the professional’s available wallet.
- Daily, weekly, monthly, milestone-based and completion-based schedules are supported by the release
  policy. The schedule is chosen when the job is set up, not invented by the ledger.
- For physical work, release follows evidence the client can review: before-and-after evidence for the
  work, and an approval for the period, milestone or completion being paid. Evidence and approval are
  product flows outside EP-02; the ledger records the resulting release posting.
- A dispute can hold the reservation; release and refund remain governed by BD-D03 once decided.
- Refunds reverse the reservation to the payer’s wallet or the original payment route, as the approved
  policy requires.
- VFD does not decide milestones, approvals or releases. It executes the payout instruction.

## 4. Payouts

- Payouts are made only to bound, verified bank accounts.
- A withdrawal reserves the amount before the provider call.
- A failed provider call releases the reservation and leaves no half-posted state.
- A manual payout requires maker-checker approval.
- Payout limits are configuration; `tier_0` has zero financial limits.
- Every payout has an idempotency key and a provider reference.

## 5. Reconciliation

- Every deposit and withdrawal is reconciled against VFD settlement/status data.
- A run records the period, provider totals, ledger totals, differences, owner and resolution.
- A mismatch is an incident, not a rounding note.
- Raw provider events are stored before interpretation.
- The provider status query is authoritative when a webhook is missing or ambiguous.

## 6. Security and controls

- The service layer enforces wallet, escrow, payout and KYC rules inside the transaction.
- RLS is a second line of defence.
- The API cannot update a balance; it posts an entry.
- The API cannot move money without a capability, a limit check and an idempotency key.
- The pooled account is not accessible to any client, staff or developer credential.
- Payout bank details are field-level encrypted and never projected.
- Audit is written in the same transaction as the financial effect.

## 7. Conditions before production

| # | Condition | Owner |
|---|---|---|
| 1 | VFD written confirmation of the pooled account structure, marketplace escrow use case, licence scope and limits | Founder / counsel |
| 2 | Counsel confirmation of the licensing, safeguarding, segregation, insolvency and reporting treatment | Founder / counsel |
| 3 | VFD confirmation of virtual-account ownership/name model and payer matching | Founder / architect |
| 4 | VFD confirmation of payout authority, limits and settlement SLA | Founder / architect |
| 5 | Webhook signature/status-verification contract | Architect |
| 6 | KYC/AML responsibility split and data-sharing terms | Founder / counsel |
| 7 | Reconciliation source of truth and exception ownership | Architect |

## 8. Engineering implications

- `finance` owns wallet, escrow, payout, clearing, reconciliation and provider-reference tables.
- `profile` owns the virtual-account mapping and KYC tier.
- `integrations/vfd` owns virtual-account provisioning, deposits, payouts and status queries.
- EP-02-030 to EP-02-036 and EP-02-050 to EP-02-056 are buildable on this model.
- EP-02-040 to EP-02-045 were blocked on VFD’s written API/account confirmation. On 2026-11-21 the
  founder recorded that onboarding is complete and directed the integration to proceed; the written
  confirmation remains an accepted risk, not a completed condition.
- No implementation may describe the internal wallet as a bank deposit or Hivorr as the legal owner of
  customer funds until counsel confirms the structure.

## 9. Decision log

| Date | Decision | Authority |
|---|---|---|
| 2026-11-15 | Pooled collection/settlement account, internal wallets and internal escrow approved as the final product model | Founder |
| 2026-11-15 | Legal/regulatory confirmation remains open; provider adapter tasks blocked | Founder / counsel |
| 2026-11-21 | Virtual accounts are collection identifiers; **all collected funds settle into the central pool account**, and Hivorr records each user’s balance in its internal ledger | Founder |
| 2026-11-21 | Internal escrow releases follow daily, weekly, monthly, milestone or completion arrangements, with client review of before-and-after evidence; VFD does not provide escrow | Founder |
| 2026-11-21 | VFD onboarding is complete; integration proceeds on that basis. Written confirmation of the pooled structure and escrow use case, and counsel’s licensing confirmation, remain open accepted risks | Founder |
| 2026-11-21 | KYC is to follow the CBN-approved tier model; the exact requirements and limits still require confirmation | Founder |

## 10. Founder clarification — 21 November 2026

The founder restated the model so the three layers are not confused:

| Layer | Holds | Owner of the control |
|---|---|---|
| **VFD pool account** | the actual collected funds | VFD banking arrangement; Hivorr operates the account under it |
| **Hivorr internal wallet and ledger** | each user’s beneficial balance and every posting | Hivorr application and database |
| **Hivorr internal escrow** | the commitment of wallet funds to a job, period, milestone or completion | Hivorr application and database |

- Incoming money lands in the pool; the virtual account is a collection endpoint that identifies the
  payer, not a separate custodial balance.
- A job reserves value from the client’s wallet into the job’s escrow ledger account.
- The professional’s preferred arrangement — daily, weekly, monthly, milestone or completion — governs
  when the client reviews evidence and approves a release.
- A release posts from the job escrow to the professional’s wallet; a withdrawal posts from the wallet
  and pays out from the pool.
- VFD executes banking and payment instructions. It does not decide milestones, approvals, releases or
  wallet balances.

**Still open:** counsel’s licensing/safeguarding/segregation opinion; VFD’s written confirmation of the
account structure, virtual-account ownership/name model and settlement terms; dispute outcomes and
refund rules; platform fees. Dispute outcomes and refunds are not implemented.
