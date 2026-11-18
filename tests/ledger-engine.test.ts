import { randomUUID } from "node:crypto"

import {
  ACTIVITY_IDS,
  minorUnitsToMoney,
  moneyToMinorUnits,
  type PostingDirection,
} from "@hivorr/shared"
import { describe, expect, it } from "vitest"

import {
  LedgerValidationError,
  type LedgerEntryInput,
  type LedgerPostingInput,
  deriveAccountEffects,
  validateJournalEntry,
} from "../server/src/modules/finance/ledger"

/**
 * A deterministic generator keeps the property tests reproducible without a
 * second test framework. Each run uses the same seed and the same shape.
 */
function mulberry32(seed: number): () => number {
  let state = seed >>> 0
  return () => {
    state = (state + 0x6d2b79f5) >>> 0
    let value = state
    value = Math.imul(value ^ (value >>> 15), value | 1)
    value ^= value + Math.imul(value ^ (value >>> 7), value | 61)
    return ((value ^ (value >>> 14)) >>> 0) / 4294967296
  }
}

function randomInt(random: () => number, minimum: number, maximum: number) {
  return minimum + Math.floor(random() * (maximum - minimum + 1))
}

function randomMinor(random: () => number): bigint {
  const units = BigInt(randomInt(random, 1, 999_999_999))
  const fraction = BigInt(randomInt(random, 0, 9999))
  return units * 10_000n + fraction
}

function withDirection(
  posting: LedgerPostingInput,
  direction: PostingDirection,
): LedgerPostingInput {
  return { ...posting, direction }
}

function expectValidationCode(
  action: () => unknown,
  code: LedgerValidationError["code"],
): void {
  try {
    action()
    throw new Error(`expected ${code}`)
  } catch (error) {
    expect(error).toBeInstanceOf(LedgerValidationError)
    expect((error as LedgerValidationError).code).toBe(code)
  }
}

function validEntry(random: () => number): LedgerEntryInput {
  const currency = "NGN"
  const accounts = [randomUUID(), randomUUID(), randomUUID(), randomUUID()]
  const platform = randomUUID()
  const postings: LedgerPostingInput[] = []
  let debits = 0n
  let credits = 0n

  const debitsCount = randomInt(random, 1, 5)
  const creditsCount = randomInt(random, 1, 5)

  for (let index = 0; index < debitsCount; index += 1) {
    const minor = randomMinor(random)
    debits += minor
    postings.push({
      accountId: accounts[index % accounts.length]!,
      direction: "debit",
      amount: minorUnitsToMoney(minor),
      currency,
      activityId: ACTIVITY_IDS[index % 3],
    })
  }

  for (let index = 0; index < creditsCount; index += 1) {
    const minor = randomMinor(random)
    credits += minor
    postings.push({
      accountId: accounts[(index + 1) % accounts.length]!,
      direction: "credit",
      amount: minorUnitsToMoney(minor),
      currency,
    })
  }

  if (debits > credits) {
    postings.push({
      accountId: platform,
      direction: "credit",
      amount: minorUnitsToMoney(debits - credits),
      currency,
    })
  } else if (credits > debits) {
    postings.push({
      accountId: platform,
      direction: "debit",
      amount: minorUnitsToMoney(credits - debits),
      currency,
    })
  }

  return {
    kind: "adjustment",
    reference: `ADJ-${randomInt(random, 1000, 9999)}`,
    currency,
    idempotencyKey: `idem-${randomInt(random, 100000, 999999)}`,
    postings,
  }
}

describe("ledger posting engine", () => {
  it("accepts a balanced entry and derives per-account effects", () => {
    const wallet = randomUUID()
    const clearing = randomUUID()

    const entry = validateJournalEntry({
      kind: "deposit",
      reference: "DEP-TEST-1",
      currency: "NGN",
      idempotencyKey: "idem-test-1",
      postings: [
        {
          accountId: wallet,
          direction: "debit",
          amount: "100.1",
          currency: "NGN",
          activityId: "market.buy",
        },
        {
          accountId: clearing,
          direction: "credit",
          amount: "100.1000",
          currency: "NGN",
        },
      ],
    })

    expect(entry.postings.map((posting) => posting.amount)).toEqual([
      "100.1000",
      "100.1000",
    ])

    const effects = deriveAccountEffects(entry.postings)
    const byAccount = new Map(
      effects.map((effect) => [effect.accountId, effect]),
    )
    expect(byAccount.get(wallet)).toEqual({
      accountId: wallet,
      currency: "NGN",
      debit: "100.1000",
      credit: "0.0000",
      net: "100.1000",
    })
    expect(byAccount.get(clearing)).toEqual({
      accountId: clearing,
      currency: "NGN",
      debit: "0.0000",
      credit: "100.1000",
      net: "-100.1000",
    })
  })

  it("balances decimal amounts without floating-point drift", () => {
    const entry = validateJournalEntry({
      kind: "adjustment",
      reference: "ADJ-ROUNDING",
      currency: "NGN",
      postings: [
        {
          accountId: randomUUID(),
          direction: "debit",
          amount: "0.1",
          currency: "NGN",
        },
        {
          accountId: randomUUID(),
          direction: "debit",
          amount: "0.2",
          currency: "NGN",
        },
        {
          accountId: randomUUID(),
          direction: "credit",
          amount: "0.3",
          currency: "NGN",
        },
      ],
    })

    expect(entry.postings).toHaveLength(3)
  })

  it("rejects an unbalanced entry", () => {
    expectValidationCode(
      () =>
        validateJournalEntry({
          kind: "adjustment",
          reference: "ADJ-UNBALANCED",
          currency: "NGN",
          postings: [
            {
              accountId: randomUUID(),
              direction: "debit",
              amount: "10.0000",
              currency: "NGN",
            },
            {
              accountId: randomUUID(),
              direction: "credit",
              amount: "9.9999",
              currency: "NGN",
            },
          ],
        }),
      "LEDGER_ENTRY_UNBALANCED",
    )
  })

  it("rejects a mixed currency", () => {
    expectValidationCode(
      () =>
        validateJournalEntry({
          kind: "adjustment",
          reference: "ADJ-CURRENCY",
          currency: "NGN",
          postings: [
            {
              accountId: randomUUID(),
              direction: "debit",
              amount: "10.0000",
              currency: "NGN",
            },
            {
              accountId: randomUUID(),
              direction: "credit",
              amount: "10.0000",
              currency: "USD",
            },
          ],
        }),
      "LEDGER_POSTING_CURRENCY_MISMATCH",
    )
  })

  it("rejects invalid directions, amounts and account identifiers", () => {
    const base = {
      kind: "adjustment",
      reference: "ADJ-DENY",
      currency: "NGN",
    }
    const posting = {
      accountId: randomUUID(),
      direction: "debit",
      amount: "10.0000",
      currency: "NGN",
    }

    expectValidationCode(
      () =>
        validateJournalEntry({
          ...base,
          postings: [
            { ...posting, direction: "sideways" },
            { ...posting, accountId: randomUUID(), direction: "credit" },
          ],
        }),
      "LEDGER_DIRECTION_INVALID",
    )

    expectValidationCode(
      () =>
        validateJournalEntry({
          ...base,
          postings: [
            { ...posting, amount: "10.00001" },
            { ...posting, accountId: randomUUID(), direction: "credit" },
          ],
        }),
      "LEDGER_AMOUNT_INVALID",
    )

    expectValidationCode(
      () =>
        validateJournalEntry({
          ...base,
          postings: [
            { ...posting, amount: "0" },
            { ...posting, accountId: randomUUID(), direction: "credit" },
          ],
        }),
      "LEDGER_AMOUNT_INVALID",
    )

    expectValidationCode(
      () =>
        validateJournalEntry({
          ...base,
          postings: [
            { ...posting, accountId: "not-an-account" },
            { ...posting, accountId: randomUUID(), direction: "credit" },
          ],
        }),
      "LEDGER_ACCOUNT_INVALID",
    )
  })

  it("rejects a posting count outside the approved range", () => {
    const posting: LedgerPostingInput = {
      accountId: randomUUID(),
      direction: "debit",
      amount: "1.0000",
      currency: "NGN",
    }

    expectValidationCode(
      () =>
        validateJournalEntry({
          kind: "adjustment",
          reference: "ADJ-ONE",
          currency: "NGN",
          postings: [posting],
        }),
      "LEDGER_POSTING_COUNT_INVALID",
    )

    expectValidationCode(
      () =>
        validateJournalEntry({
          kind: "adjustment",
          reference: "ADJ-MANY",
          currency: "NGN",
          postings: Array.from({ length: 101 }, () => ({ ...posting })),
        }),
      "LEDGER_POSTING_COUNT_INVALID",
    )
  })

  it("rejects reference, key and vocabulary violations", () => {
    const balanced: LedgerPostingInput[] = [
      {
        accountId: randomUUID(),
        direction: "debit",
        amount: "1.0000",
        currency: "NGN",
      },
      {
        accountId: randomUUID(),
        direction: "credit",
        amount: "1.0000",
        currency: "NGN",
      },
    ]

    expectValidationCode(
      () =>
        validateJournalEntry({
          kind: "adjustment",
          reference: "x",
          currency: "NGN",
          postings: balanced,
        }),
      "LEDGER_REFERENCE_INVALID",
    )

    expectValidationCode(
      () =>
        validateJournalEntry({
          kind: "adjustment",
          reference: "ADJ-KEY",
          currency: "NGN",
          idempotencyKey: "short",
          postings: balanced,
        }),
      "LEDGER_IDEMPOTENCY_KEY_INVALID",
    )

    expectValidationCode(
      () =>
        validateJournalEntry({
          kind: "gift",
          reference: "ADJ-KIND",
          currency: "NGN",
          postings: balanced,
        }),
      "LEDGER_ENTRY_KIND_INVALID",
    )

    expectValidationCode(
      () =>
        validateJournalEntry({
          kind: "adjustment",
          reference: "ADJ-ACTIVITY",
          currency: "NGN",
          activityId: "market.discover",
          postings: balanced,
        }),
      "LEDGER_ACTIVITY_INVALID",
    )
  })

  it("requires a reversal target and an exact inversion", () => {
    const original = validateJournalEntry({
      kind: "deposit",
      reference: "DEP-REVERSAL",
      currency: "NGN",
      postings: [
        {
          accountId: randomUUID(),
          direction: "debit",
          amount: "25.0000",
          currency: "NGN",
        },
        {
          accountId: randomUUID(),
          direction: "credit",
          amount: "25.0000",
          currency: "NGN",
        },
      ],
    })

    const reversalInput: LedgerEntryInput = {
      kind: "reversal",
      reference: "REV-REVERSAL",
      currency: "NGN",
      reversesEntryId: randomUUID(),
      postings: original.postings.map((posting) =>
        withDirection(
          posting,
          posting.direction === "debit" ? "credit" : "debit",
        ),
      ),
    }

    expectValidationCode(
      () => validateJournalEntry(reversalInput),
      "LEDGER_REVERSAL_TARGET_MISSING",
    )

    const reversal = validateJournalEntry(reversalInput, {
      reversalTarget: {
        currency: original.currency,
        postings: original.postings,
      },
    })
    expect(reversal.kind).toBe("reversal")

    const wrongAmount = reversalInput.postings.map((posting) => ({
      ...posting,
      amount: "24.9999",
    }))
    expectValidationCode(
      () =>
        validateJournalEntry({ ...reversalInput, postings: wrongAmount }, {
          reversalTarget: {
            currency: original.currency,
            postings: original.postings,
          },
        }),
      "LEDGER_REVERSAL_MISMATCH",
    )

    expectValidationCode(
      () =>
        validateJournalEntry(
          { ...reversalInput, postings: reversalInput.postings.slice(0, 1) },
          {
            reversalTarget: {
              currency: original.currency,
              postings: original.postings,
            },
          },
        ),
      "LEDGER_POSTING_COUNT_INVALID",
    )
  })

  it("rejects a reversal link on a non-reversal entry", () => {
    expectValidationCode(
      () =>
        validateJournalEntry({
          kind: "adjustment",
          reference: "ADJ-REVERSES",
          currency: "NGN",
          reversesEntryId: randomUUID(),
          postings: [
            {
              accountId: randomUUID(),
              direction: "debit",
              amount: "1.0000",
              currency: "NGN",
            },
            {
              accountId: randomUUID(),
              direction: "credit",
              amount: "1.0000",
              currency: "NGN",
            },
          ],
        }),
      "LEDGER_REVERSAL_TARGET_INVALID",
    )
  })

  it("property: every generated balanced entry is accepted and nets to zero", () => {
    for (let seed = 1; seed <= 200; seed += 1) {
      const random = mulberry32(seed)
      const input = validEntry(random)
      const entry = validateJournalEntry(input)

      const debits = entry.postings
        .filter((posting) => posting.direction === "debit")
        .reduce((sum, posting) => sum + posting.amountMinor, 0n)
      const credits = entry.postings
        .filter((posting) => posting.direction === "credit")
        .reduce((sum, posting) => sum + posting.amountMinor, 0n)

      expect(debits, `seed ${seed}`).toBe(credits)

      const effects = deriveAccountEffects(entry.postings)
      const netTotal = effects.reduce((sum, effect) => {
        const debit = moneyToMinorUnits(effect.debit)
        const credit = moneyToMinorUnits(effect.credit)
        return sum + (debit ?? 0n) - (credit ?? 0n)
      }, 0n)
      expect(netTotal, `seed ${seed}`).toBe(0n)
    }
  })

  it("property: every reversal exactly negates the original effects", () => {
    for (let seed = 201; seed <= 400; seed += 1) {
      const random = mulberry32(seed)
      const original = validateJournalEntry(validEntry(random))
      const reversed = validateJournalEntry(
        {
          kind: "reversal",
          reference: `REV-${seed}`,
          currency: original.currency,
          reversesEntryId: randomUUID(),
          postings: original.postings.map((posting) =>
            withDirection(
              posting,
              posting.direction === "debit" ? "credit" : "debit",
            ),
          ),
        },
        {
          reversalTarget: {
            currency: original.currency,
            postings: original.postings,
          },
        },
      )

      const originalEffects = new Map(
        deriveAccountEffects(original.postings).map((effect) => [
          effect.accountId,
          effect,
        ]),
      )
      for (const effect of deriveAccountEffects(reversed.postings)) {
        const before = originalEffects.get(effect.accountId)
        expect(before, `seed ${seed}`).toBeDefined()
        const beforeNet =
          (moneyToMinorUnits(before!.debit) ?? 0n) -
          (moneyToMinorUnits(before!.credit) ?? 0n)
        const afterNet =
          (moneyToMinorUnits(effect.debit) ?? 0n) -
          (moneyToMinorUnits(effect.credit) ?? 0n)
        expect(afterNet, `seed ${seed}`).toBe(-beforeNet)
      }
    }
  })

  it("property: amount strings round-trip through minor units", () => {
    for (let seed = 401; seed <= 600; seed += 1) {
      const random = mulberry32(seed)
      const minor = randomMinor(random)
      const amount = minorUnitsToMoney(minor)
      expect(moneyToMinorUnits(amount), `seed ${seed}`).toBe(minor)
      expect(moneyToMinorUnits(`${amount}0`), `seed ${seed}`).toBeNull()
    }
  })

  it("does not mutate or persist input postings", () => {
    const input = validEntry(mulberry32(999))
    const snapshot = JSON.stringify(input)
    const entry = validateJournalEntry(input)
    expect(JSON.stringify(input)).toBe(snapshot)
    expect(entry.postings).not.toBe(input.postings)
  })
})
