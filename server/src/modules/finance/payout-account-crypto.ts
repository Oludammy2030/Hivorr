import {
  createCipheriv,
  createDecipheriv,
  createHmac,
  randomBytes,
} from "node:crypto"

import { ConfigurationError } from "../../config"

/**
 * Payout-account protection (EP-02-050).
 *
 * The account number is encrypted with AES-256-GCM under a managed key before
 * it ever reaches the database. The envelope carries only a format version and
 * the GCM nonce/tag; the key version is stored beside it in
 * `finance.payout_accounts.encryption_key_id`. The uniqueness fingerprint uses
 * a separate HMAC key, so holding one key cannot reveal or confirm the other.
 *
 * Nothing here logs, echoes or projects a plaintext account number. The only
 * account-number material this module may return for display is the last four
 * digits.
 */
const ENVELOPE_VERSION = 1
const ALGORITHM = "aes-256-gcm"
const IV_LENGTH = 12
const TAG_LENGTH = 16
const KEY_LENGTH = 32

export const PAYOUT_ACCOUNT_NUMBER_PATTERN = /^[0-9]{10}$/
export const PAYOUT_BANK_CODE_PATTERN = /^[0-9]{3,10}$/
export const PAYOUT_ACCOUNT_LAST4_PATTERN = /^[0-9]{4}$/
export const PAYOUT_FINGERPRINT_PATTERN = /^[0-9a-f]{64}$/

export interface PayoutAccountKeys {
  readonly encryptionKey: string | undefined
  readonly encryptionKeyId: string
  readonly fingerprintKey: string | undefined
}

export interface EncryptedPayoutAccount {
  readonly ciphertext: Buffer
  readonly keyId: string
  readonly last4: string
  readonly fingerprint: string
}

function decodeKey(value: string, name: string): Buffer {
  const key = Buffer.from(value, "base64")
  if (key.length !== KEY_LENGTH) {
    throw new ConfigurationError(`${name} must be 32 bytes encoded as base64`)
  }
  return key
}

/** Removes the spaces and hyphens people type into an account number. */
export function normalizeAccountNumber(value: string): string {
  return value.replace(/[\s-]/g, "")
}

/**
 * Case-folds and collapses whitespace so "ADEBAYO  O. JOHNSON" and
 * "Adebayo O. Johnson" compare equal. It deliberately does not strip titles or
 * reorder names: a match is evidence, not a guess.
 */
export function normalizeAccountName(value: string): string {
  return value.normalize("NFKC").trim().replace(/\s+/g, " ").toUpperCase()
}

/** True when a resolved bank account name matches a verified legal name. */
export function accountNamesMatch(
  resolvedName: string,
  legalName: string,
): boolean {
  const left = normalizeAccountName(resolvedName)
  const right = normalizeAccountName(legalName)
  return left.length > 0 && left === right
}

export class PayoutAccountCipher {
  constructor(
    private readonly encryptionKey: Buffer,
    private readonly encryptionKeyId: string,
    private readonly fingerprintKey: Buffer,
  ) {}

  /**
   * Builds the cipher from configuration. The caller decides that payout
   * binding is available; this throws only when a supplied key is malformed.
   */
  static fromConfig(keys: PayoutAccountKeys): PayoutAccountCipher {
    if (!keys.encryptionKey || !keys.fingerprintKey) {
      throw new ConfigurationError(
        "Payout encryption and fingerprint keys are required",
      )
    }
    if (keys.encryptionKey === keys.fingerprintKey) {
      throw new ConfigurationError(
        "The payout encryption and fingerprint keys must be different",
      )
    }
    return new PayoutAccountCipher(
      decodeKey(keys.encryptionKey, "PAYOUT_ENCRYPTION_KEY"),
      keys.encryptionKeyId,
      decodeKey(keys.fingerprintKey, "PAYOUT_FINGERPRINT_KEY"),
    )
  }

  encrypt(accountNumber: string): EncryptedPayoutAccount {
    const normalized = normalizeAccountNumber(accountNumber)
    if (!PAYOUT_ACCOUNT_NUMBER_PATTERN.test(normalized)) {
      throw new Error("A payout account number is ten digits")
    }

    const iv = randomBytes(IV_LENGTH)
    const cipher = createCipheriv(ALGORITHM, this.encryptionKey, iv)
    const encrypted = Buffer.concat([
      cipher.update(normalized, "utf8"),
      cipher.final(),
    ])
    const tag = cipher.getAuthTag()

    return {
      ciphertext: Buffer.concat([
        Buffer.from([ENVELOPE_VERSION]),
        iv,
        tag,
        encrypted,
      ]),
      keyId: this.encryptionKeyId,
      last4: normalized.slice(-4),
      fingerprint: this.fingerprint(normalized),
    }
  }

  decrypt(ciphertext: Buffer, keyId: string): string {
    if (keyId !== this.encryptionKeyId) {
      throw new Error("The payout ciphertext was encrypted under another key")
    }
    if (ciphertext.length < 1 + IV_LENGTH + TAG_LENGTH) {
      throw new Error("The payout ciphertext envelope is malformed")
    }
    if (ciphertext[0] !== ENVELOPE_VERSION) {
      throw new Error("Unsupported payout ciphertext version")
    }

    const iv = ciphertext.subarray(1, 1 + IV_LENGTH)
    const tag = ciphertext.subarray(1 + IV_LENGTH, 1 + IV_LENGTH + TAG_LENGTH)
    const encrypted = ciphertext.subarray(1 + IV_LENGTH + TAG_LENGTH)

    const decipher = createDecipheriv(ALGORITHM, this.encryptionKey, iv)
    decipher.setAuthTag(tag)
    return Buffer.concat([
      decipher.update(encrypted),
      decipher.final(),
    ]).toString("utf8")
  }

  /** HMAC-SHA256 of the normalised account number, hex encoded. */
  fingerprint(accountNumber: string): string {
    return createHmac("sha256", this.fingerprintKey)
      .update(normalizeAccountNumber(accountNumber), "utf8")
      .digest("hex")
  }
}
