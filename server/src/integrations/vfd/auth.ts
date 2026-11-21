import {
  PaymentProviderError,
  type PaymentProviderErrorCode,
} from "../payments/payment-provider"

/**
 * VFD access-token client (EP-02-041).
 *
 * The token endpoint is the same for every documented product. The client:
 *
 * - requests a finite `validityTime`; it never asks for the vendor's
 *   non-expiring `-1`;
 * - caches until shortly before expiry and refreshes once for concurrent
 *   callers;
 * - bounds every attempt with a timeout and the whole call with a retry count;
 * - maps failures to the provider error codes and never puts a credential or a
 *   token in a message.
 *
 * It contacts nothing in tests; the transport is injected.
 */
export type VfdMode = "test" | "live"

export const VFD_TOKEN_URLS: Readonly<Record<VfdMode, string>> = Object.freeze({
  test: "https://api-devapps.vfdbank.systems/vtech-wallet/api/v2/wallet2/token",
  live: "https://api-apps.vfdbank.systems/vtech-wallet/api/v2/wallet2/token",
})

export interface VfdAuthOptions {
  readonly mode: VfdMode
  readonly consumerKey: string | undefined
  readonly consumerSecret: string | undefined
  readonly tokenValidityMinutes: number
  readonly requestTimeoutMs: number
  readonly maxRetries: number
  readonly retryBaseMs: number
}

export interface VfdAuthDependencies {
  readonly fetchImpl?: typeof fetch
  readonly now?: () => number
  readonly sleep?: (milliseconds: number) => Promise<void>
}

interface VfdTokenEnvelope {
  readonly status?: unknown
  readonly message?: unknown
  readonly data?: {
    readonly access_token?: unknown
    readonly token_type?: unknown
    readonly expires_in?: unknown
  }
}

const MAXIMUM_ACCEPTED_LIFETIME_SECONDS = 24 * 60 * 60
const MINIMUM_CACHED_LIFETIME_MS = 30_000
const MAXIMUM_RETRY_DELAY_MS = 2_000

function defaultSleep(milliseconds: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, milliseconds))
}

class VfdTokenError extends PaymentProviderError {
  constructor(
    code: PaymentProviderErrorCode,
    message: string,
    retryable: boolean,
  ) {
    super(code, message, { retryable })
  }
}

export class VfdAuthClient {
  private readonly fetchImpl: typeof fetch
  private readonly now: () => number
  private readonly sleep: (milliseconds: number) => Promise<void>
  private token: string | null = null
  private expiresAt = 0
  private refreshing: Promise<string> | null = null

  constructor(
    private readonly options: VfdAuthOptions,
    dependencies: VfdAuthDependencies = {},
  ) {
    this.fetchImpl = dependencies.fetchImpl ?? fetch
    this.now = dependencies.now ?? Date.now
    this.sleep = dependencies.sleep ?? defaultSleep
  }

  get mode(): VfdMode {
    return this.options.mode
  }

  /** A cached token, or one fresh token shared by concurrent callers. */
  async getToken(): Promise<string> {
    if (this.token && this.now() < this.expiresAt) return this.token
    if (this.refreshing) return this.refreshing

    this.refreshing = this.requestToken()
      .then((issued) => {
        this.token = issued.token
        this.expiresAt = issued.expiresAt
        return issued.token
      })
      .finally(() => {
        this.refreshing = null
      })

    return this.refreshing
  }

  /** Call after a product endpoint answers 401/403. */
  invalidate(): void {
    this.token = null
    this.expiresAt = 0
  }

  private async requestToken(): Promise<{
    readonly token: string
    readonly expiresAt: number
  }> {
    const key = this.options.consumerKey
    const secret = this.options.consumerSecret
    if (!key || !secret) {
      throw new VfdTokenError(
        "PROVIDER_AUTH_FAILED",
        "VFD credentials are not configured.",
        false,
      )
    }

    const url = VFD_TOKEN_URLS[this.options.mode]
    const body = JSON.stringify({
      consumerKey: key,
      consumerSecret: secret,
      validityTime: String(this.options.tokenValidityMinutes),
    })

    let lastError: VfdTokenError | null = null

    for (let attempt = 0; attempt <= this.options.maxRetries; attempt += 1) {
      if (attempt > 0) {
        const delay = Math.min(
          this.options.retryBaseMs * 2 ** (attempt - 1),
          MAXIMUM_RETRY_DELAY_MS,
        )
        await this.sleep(delay)
      }

      const controller = new AbortController()
      const timer = setTimeout(
        () => controller.abort(),
        this.options.requestTimeoutMs,
      )

      try {
        const response = await this.fetchImpl(url, {
          method: "POST",
          headers: {
            accept: "application/json",
            "content-type": "application/json",
          },
          body,
          signal: controller.signal,
        })

        if (response.status === 401 || response.status === 403) {
          throw new VfdTokenError(
            "PROVIDER_AUTH_FAILED",
            "VFD rejected the credentials.",
            false,
          )
        }

        if (response.status === 429 || response.status >= 500) {
          lastError = new VfdTokenError(
            "PROVIDER_UNAVAILABLE",
            "VFD is unavailable.",
            true,
          )
          continue
        }

        if (!response.ok) {
          throw new VfdTokenError(
            "PROVIDER_REJECTED",
            "VFD rejected the token request.",
            false,
          )
        }

        const payload = (await response
          .json()
          .catch(() => null)) as VfdTokenEnvelope | null
        if (!payload) {
          throw new VfdTokenError(
            "PROVIDER_INVALID_PAYLOAD",
            "VFD returned an unreadable token response.",
            false,
          )
        }
        if (payload.status !== "00") {
          throw new VfdTokenError(
            "PROVIDER_AUTH_FAILED",
            "VFD did not issue a token.",
            false,
          )
        }

        const token = payload.data?.access_token
        if (typeof token !== "string" || token.length === 0) {
          throw new VfdTokenError(
            "PROVIDER_INVALID_PAYLOAD",
            "VFD returned no access token.",
            false,
          )
        }

        const expiresIn = payload.data?.expires_in
        const seconds =
          typeof expiresIn === "number" &&
          Number.isFinite(expiresIn) &&
          expiresIn > 0 &&
          expiresIn <= MAXIMUM_ACCEPTED_LIFETIME_SECONDS
            ? expiresIn
            : this.options.tokenValidityMinutes * 60

        const lifetimeMs = Math.max(
          seconds * 1_000 - 60_000,
          MINIMUM_CACHED_LIFETIME_MS,
        )

        return {
          token,
          expiresAt: this.now() + lifetimeMs,
        }
      } catch (error) {
        if (error instanceof VfdTokenError) {
          if (!error.retryable) throw error
          lastError = error
          continue
        }
        if (controller.signal.aborted) {
          lastError = new VfdTokenError(
            "PROVIDER_TIMEOUT",
            "VFD did not answer in time.",
            true,
          )
          continue
        }
        lastError = new VfdTokenError(
          "PROVIDER_UNAVAILABLE",
          "The VFD request failed.",
          true,
        )
      } finally {
        clearTimeout(timer)
      }
    }

    throw (
      lastError ??
      new VfdTokenError("PROVIDER_UNAVAILABLE", "VFD is unavailable.", true)
    )
  }
}
