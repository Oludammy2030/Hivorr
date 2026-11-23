import {
  PaymentProviderError,
  type AccountNameEnquiry,
  type AccountNameEnquiryRequest,
  type PaymentProviderErrorCode,
} from "../payments/payment-provider"
import { type VfdAuthClient, type VfdMode } from "./auth"

/**
 * VFD wallet enquiry client (EP-02-050, extended by EP-02-043).
 *
 * Two documented reads live here:
 *
 * - `GET /transfer/recipient` resolves the beneficiary and returns the name used
 *   for binding plus the client/account identifiers a transfer echoes back;
 * - `GET /account/enquiry` resolves the source wallet, which is how the transfer
 *   obtains `fromClientId`, `fromClient` and `fromSavingsId` without storing a
 *   second copy of the wallet profile.
 *
 * The client returns only the last four account digits for a beneficiary and
 * never logs or echoes a full account number.
 */
export const VFD_WALLET_BASE_URLS: Readonly<Record<VfdMode, string>> =
  Object.freeze({
    test: "https://api-devapps.vfdbank.systems/vtech-wallet/api/v2/wallet2",
    live: "https://api-apps.vfdbank.systems/vtech-wallet/api/v2/wallet2",
  })

const TRANSFER_TYPE = "inter"
const MAXIMUM_RETRY_DELAY_MS = 2_000

export interface VfdAccountNameOptions {
  readonly requestTimeoutMs: number
  readonly maxRetries: number
  readonly retryBaseMs: number
}

export interface VfdAccountNameDependencies {
  readonly fetchImpl?: typeof fetch
  readonly sleep?: (milliseconds: number) => Promise<void>
}

/**
 * The documented recipient fields a single transfer must echo back. A value is
 * null when the vendor did not return it; the transfer builder refuses a
 * missing mandatory identifier rather than guessing.
 */
export interface VfdRecipientDetails {
  readonly accountName: string
  readonly bankCode: string
  readonly accountNumberLast4: string
  readonly clientId: string | null
  readonly accountId: string | null
  readonly bvn: string | null
  readonly bankName: string | null
}

/** The documented sender fields from `/account/enquiry`. */
export interface VfdSourceDetails {
  readonly accountNumber: string
  readonly clientId: string
  readonly clientName: string
  readonly savingsId: string
}

interface VfdRecipientEnvelope {
  readonly status?: unknown
  readonly message?: unknown
  readonly data?: {
    readonly name?: unknown
    readonly clientId?: unknown
    readonly bvn?: unknown
    readonly bank?: unknown
    readonly account?: {
      readonly number?: unknown
      readonly id?: unknown
    }
  }
}

interface VfdSourceEnvelope {
  readonly status?: unknown
  readonly message?: unknown
  readonly data?: {
    readonly accountNo?: unknown
    readonly accountId?: unknown
    readonly client?: unknown
    readonly clientId?: unknown
  }
}

function identifier(value: unknown): string | null {
  if (typeof value === "string" && value.trim().length > 0) return value.trim()
  if (typeof value === "number" && Number.isFinite(value)) return String(value)
  return null
}

function defaultSleep(milliseconds: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, milliseconds))
}

function failure(
  code: PaymentProviderErrorCode,
  message: string,
  retryable: boolean,
): PaymentProviderError {
  return new PaymentProviderError(code, message, { retryable })
}

export class VfdAccountNameClient {
  private readonly fetchImpl: typeof fetch
  private readonly sleep: (milliseconds: number) => Promise<void>

  constructor(
    private readonly auth: VfdAuthClient,
    private readonly options: VfdAccountNameOptions,
    dependencies: VfdAccountNameDependencies = {},
  ) {
    this.fetchImpl = dependencies.fetchImpl ?? fetch
    this.sleep = dependencies.sleep ?? defaultSleep
  }

  /** The neutral name enquiry the payment port exposes. */
  async resolveAccountName(
    input: AccountNameEnquiryRequest,
  ): Promise<AccountNameEnquiry> {
    const recipient = await this.enquireRecipient(input)
    return {
      accountName: recipient.accountName,
      bankCode: recipient.bankCode,
      accountNumberLast4: recipient.accountNumberLast4,
    }
  }

  /**
   * The full documented recipient record. A payout needs the client and account
   * identifiers; a name-only caller uses `resolveAccountName` instead.
   */
  async enquireRecipient(
    input: AccountNameEnquiryRequest,
  ): Promise<VfdRecipientDetails> {
    if (!/^[0-9]{3,10}$/.test(input.bankCode)) {
      throw failure(
        "PROVIDER_INVALID_PAYLOAD",
        "A name enquiry needs a bank code.",
        false,
      )
    }
    if (!/^[0-9]{10}$/.test(input.accountNumber)) {
      throw failure(
        "PROVIDER_INVALID_PAYLOAD",
        "A name enquiry needs a ten-digit account number.",
        false,
      )
    }

    const payload = await this.get<VfdRecipientEnvelope>(
      "/transfer/recipient",
      {
        accountNo: input.accountNumber,
        bank: input.bankCode,
        transfer_type: TRANSFER_TYPE,
      },
    )

    if (payload.status !== "00") {
      const message = typeof payload.message === "string" ? payload.message : ""
      if (payload.status === "104" || /not\s*found/i.test(message)) {
        throw failure(
          "PROVIDER_NOT_FOUND",
          "VFD could not resolve that account.",
          false,
        )
      }
      throw failure(
        "PROVIDER_REJECTED",
        "VFD rejected the name enquiry.",
        false,
      )
    }

    const name = payload.data?.name
    if (typeof name !== "string" || name.trim().length === 0) {
      throw failure(
        "PROVIDER_INVALID_PAYLOAD",
        "VFD returned no account name.",
        false,
      )
    }

    const accountNumber = payload.data?.account?.number
    if (
      typeof accountNumber === "string" &&
      accountNumber.length >= 4 &&
      accountNumber.slice(-4) !== input.accountNumber.slice(-4)
    ) {
      throw failure(
        "PROVIDER_INVALID_PAYLOAD",
        "VFD returned a different account number.",
        false,
      )
    }

    return {
      accountName: name.trim(),
      bankCode: input.bankCode,
      accountNumberLast4: input.accountNumber.slice(-4),
      clientId: identifier(payload.data?.clientId),
      accountId: identifier(payload.data?.account?.id),
      bvn: identifier(payload.data?.bvn),
      bankName:
        typeof payload.data?.bank === "string"
          ? payload.data.bank.trim() || null
          : null,
    }
  }

  /** The documented sender profile, used to build a single transfer. */
  async enquireSource(accountNumber: string): Promise<VfdSourceDetails> {
    if (!/^[0-9]{10}$/.test(accountNumber)) {
      throw failure(
        "PROVIDER_INVALID_PAYLOAD",
        "A source enquiry needs a ten-digit account number.",
        false,
      )
    }

    const payload = await this.get<VfdSourceEnvelope>("/account/enquiry", {
      accountNumber,
    })

    if (payload.status !== "00") {
      throw failure(
        "PROVIDER_REJECTED",
        "VFD rejected the source-account enquiry.",
        false,
      )
    }

    const returned = identifier(payload.data?.accountNo)
    if (returned && returned !== accountNumber) {
      throw failure(
        "PROVIDER_INVALID_PAYLOAD",
        "VFD returned a different source account.",
        false,
      )
    }

    const clientId = identifier(payload.data?.clientId)
    const clientName =
      typeof payload.data?.client === "string" ? payload.data.client.trim() : ""
    const savingsId = identifier(payload.data?.accountId)
    if (!clientId || !clientName || !savingsId) {
      throw failure(
        "PROVIDER_INVALID_PAYLOAD",
        "VFD returned an incomplete source-account profile.",
        false,
      )
    }

    return {
      accountNumber,
      clientId,
      clientName,
      savingsId,
    }
  }

  private async get<T,>(
    path: string,
    query: Readonly<Record<string, string>>,
  ): Promise<T> {
    const url = new URL(`${VFD_WALLET_BASE_URLS[this.auth.mode]}${path}`)
    for (const [key, value] of Object.entries(query)) {
      url.searchParams.set(key, value)
    }

    let lastError: PaymentProviderError | null = null

    for (let attempt = 0; attempt <= this.options.maxRetries; attempt += 1) {
      if (attempt > 0) {
        const delay = Math.min(
          this.options.retryBaseMs * 2 ** (attempt - 1),
          MAXIMUM_RETRY_DELAY_MS,
        )
        await this.sleep(delay)
      }

      const token = await this.auth.getToken()
      const controller = new AbortController()
      const timer = setTimeout(
        () => controller.abort(),
        this.options.requestTimeoutMs,
      )

      try {
        const response = await this.fetchImpl(url, {
          method: "GET",
          headers: {
            accept: "application/json",
            AccessToken: token,
          },
          signal: controller.signal,
        })

        if (response.status === 401 || response.status === 403) {
          this.auth.invalidate()
          throw failure(
            "PROVIDER_AUTH_FAILED",
            "VFD rejected the access token.",
            false,
          )
        }

        if (response.status === 429 || response.status >= 500) {
          lastError = failure(
            "PROVIDER_UNAVAILABLE",
            "VFD is unavailable.",
            true,
          )
          continue
        }

        if (!response.ok) {
          throw failure("PROVIDER_REJECTED", "VFD rejected the enquiry.", false)
        }

        const payload = (await response.json().catch(() => null)) as T | null
        if (!payload) {
          throw failure(
            "PROVIDER_INVALID_PAYLOAD",
            "VFD returned an unreadable enquiry.",
            false,
          )
        }
        return payload
      } catch (error) {
        if (error instanceof PaymentProviderError) {
          if (!error.retryable) throw error
          lastError = error
          continue
        }
        if (controller.signal.aborted) {
          lastError = failure(
            "PROVIDER_TIMEOUT",
            "VFD did not answer the enquiry in time.",
            true,
          )
          continue
        }
        lastError = failure(
          "PROVIDER_UNAVAILABLE",
          "The VFD enquiry failed.",
          true,
        )
      } finally {
        clearTimeout(timer)
      }
    }

    throw (
      lastError ?? failure("PROVIDER_UNAVAILABLE", "VFD is unavailable.", true)
    )
  }
}
