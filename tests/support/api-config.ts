import type { ApiConfig } from "../../server/src/config"

/**
 * Provider configuration for the database-backed integration tests.
 *
 * `AppModule` builds the VFD and Paystack clients from `config.vfd` and
 * `config.paystack` while the dependency graph is created, so a hand-written
 * `ApiConfig` must carry those sections even when a test never moves money.
 *
 * The values are obviously fake and never leave the process. No real key,
 * account or secret is used here.
 */
export const testProviderConfig: Pick<ApiConfig, "vfd" | "paystack" | "payout"> = {
  vfd: {
    mode: "test",
    consumerKey: "test-consumer-key",
    consumerSecret: "test-consumer-secret",
    tokenValidityMinutes: 30,
    requestTimeoutMs: 1_000,
    maxRetries: 0,
    retryBaseMs: 10,
    sourceAccount: "0123456789",
  },
  paystack: {
    baseUrl: "https://api.paystack.test",
    secretKeyTest: "sk_test_integration_only",
    secretKeyLive: "sk_live_integration_only",
    preferredBank: "titan-paystack",
  },
  payout: {
    encryptionKey: Buffer.alloc(32, 3).toString("base64"),
    encryptionKeyId: "integration-key-1",
    fingerprintKey: "integration-fingerprint-key",
    maxActiveAccounts: 3,
  },
}
