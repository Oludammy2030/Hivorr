import { createHash } from "node:crypto"

import { minorUnitsToMoney, moneyToMinorUnits } from "@hivorr/shared"

import type { LedgerEntryInput } from "./ledger"

/**
 * Ledger idempotency helpers (EP-02-034).
 *
 * The request hash describes the money movement, not its formatting: a retry
 * that spells `100.1` as `100.1000` is the same request and replays. Changing an
 * account, amount, direction, currency, kind, reference or reversal target
 * changes the hash and is refused.
 *
 * The stored key is scoped by account so two accounts may use the same
 * client-chosen key without colliding.
 */
export const LEDGER_IDEMPOTENCY_SCOPE = "finance.ledger.post"

export function ledgerIdempotencyKey(accountId: string, clientKey: string): string {
  return `${LEDGER_IDEMPOTENCY_SCOPE}:${accountId}:${clientKey.trim()}`
}

function canonicalPosting(posting: LedgerEntryInput["postings"][number]): string {
  const minor = moneyToMinorUnits(posting.amount)
  const amount = minor === null ? posting.amount : minorUnitsToMoney(minor)
  return JSON.stringify({
    accountId: posting.accountId,
    direction: posting.direction,
    amount,
    currency: posting.currency,
    activityId: posting.activityId?.trim() || null,
  })
}

export function hashLedgerEntry(input: LedgerEntryInput): string {
  const postings = input.postings
    .map(canonicalPosting)
    .sort((left, right) => left.localeCompare(right))

  const canonical = JSON.stringify({
    kind: input.kind,
    reference: input.reference.trim(),
    currency: input.currency,
    activityId: input.activityId?.trim() || null,
    reversesEntryId: input.reversesEntryId?.trim() || null,
    postings,
  })

  return createHash("sha256").update(canonical).digest("hex")
}
