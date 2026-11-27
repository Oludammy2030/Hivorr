import { randomUUID } from "node:crypto"

import { describe, expect, it } from "vitest"

import {
  LEDGER_IDEMPOTENCY_SCOPE,
  hashLedgerEntry,
  ledgerIdempotencyKey,
} from "../server/src/modules/finance/idempotency"
import type { LedgerEntryInput } from "../server/src/modules/finance/ledger"

function entry(): LedgerEntryInput {
  const debit = randomUUID()
  const credit = randomUUID()
  return {
    kind: "deposit",
    reference: "DEP-1",
    currency: "NGN",
    idempotencyKey: "client-key-0001",
    activityId: "market.buy",
    postings: [
      {
        accountId: debit,
        direction: "debit",
        amount: "100.1",
        currency: "NGN",
        activityId: "market.buy",
      },
      {
        accountId: credit,
        direction: "credit",
        amount: "100.1000",
        currency: "NGN",
      },
    ],
  }
}

describe("ledger idempotency", () => {
  it("scopes the stored key by account", () => {
    const account = randomUUID()
    expect(ledgerIdempotencyKey(account, " key-0001 ")).toBe(
      `${LEDGER_IDEMPOTENCY_SCOPE}:${account}:key-0001`,
    )
  })

  it("treats the same movement with different formatting as the same request", () => {
    const input = entry()
    const reformatted: LedgerEntryInput = {
      ...input,
      reference: "  DEP-1  ",
      postings: [
        { ...input.postings[0]!, amount: "100.1000" },
        { ...input.postings[1]!, amount: "100.1" },
      ],
    }
    expect(hashLedgerEntry(reformatted)).toBe(hashLedgerEntry(input))
  })

  it("ignores posting order", () => {
    const input = entry()
    const reordered: LedgerEntryInput = {
      ...input,
      postings: [...input.postings].reverse(),
    }
    expect(hashLedgerEntry(reordered)).toBe(hashLedgerEntry(input))
  })

  it("changes the hash when a money value, account or kind changes", () => {
    const input = entry()
    const original = hashLedgerEntry(input)

    expect(
      hashLedgerEntry({
        ...input,
        postings: [{ ...input.postings[0]!, amount: "100.2" }, input.postings[1]!],
      }),
    ).not.toBe(original)

    expect(
      hashLedgerEntry({
        ...input,
        postings: [{ ...input.postings[0]!, accountId: randomUUID() }, input.postings[1]!],
      }),
    ).not.toBe(original)

    expect(hashLedgerEntry({ ...input, kind: "adjustment" })).not.toBe(original)
    expect(hashLedgerEntry({ ...input, reference: "DEP-2" })).not.toBe(original)
  })
})
