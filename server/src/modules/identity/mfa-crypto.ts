import {
  createCipheriv,
  createDecipheriv,
  createHash,
  randomBytes,
} from "node:crypto"

import { ConfigurationError } from "../../config"

const KEY_VERSION = "v1"
const ALGORITHM = "aes-256-gcm"
const RECOVERY_ALPHABET = "23456789ABCDEFGHJKLMNPQRSTUVWXYZ"
const RECOVERY_LENGTH = 10

export interface EncryptedSecret {
  readonly ciphertext: string
  readonly keyVersion: string
}

/**
 * TOTP secrets are encrypted at the application layer with a key held only by
 * the API. The database stores ciphertext and a key version, never plaintext.
 */
export class MfaCipher {
  constructor(private readonly key: Buffer) {}

  static fromBase64(value: string | undefined): MfaCipher | undefined {
    if (!value) return undefined
    const key = Buffer.from(value, "base64")
    if (key.length !== 32) {
      throw new ConfigurationError(
        "MFA_ENCRYPTION_KEY must be 32 bytes encoded as base64",
      )
    }
    return new MfaCipher(key)
  }

  encrypt(plaintext: string): EncryptedSecret {
    const iv = randomBytes(12)
    const cipher = createCipheriv(ALGORITHM, this.key, iv)
    const encrypted = Buffer.concat([
      cipher.update(plaintext, "utf8"),
      cipher.final(),
    ])
    const tag = cipher.getAuthTag()
    return {
      ciphertext: [
        KEY_VERSION,
        iv.toString("base64"),
        tag.toString("base64"),
        encrypted.toString("base64"),
      ].join(":"),
      keyVersion: KEY_VERSION,
    }
  }

  decrypt(ciphertext: string): string {
    const [version, iv, tag, encrypted] = ciphertext.split(":")
    if (version !== KEY_VERSION || !iv || !tag || !encrypted) {
      throw new Error("Unsupported MFA secret format")
    }
    const decipher = createDecipheriv(
      ALGORITHM,
      this.key,
      Buffer.from(iv, "base64"),
    )
    decipher.setAuthTag(Buffer.from(tag, "base64"))
    return Buffer.concat([
      decipher.update(Buffer.from(encrypted, "base64")),
      decipher.final(),
    ]).toString("utf8")
  }
}

/** 32 characters divide 256 evenly, so random byte modulo is unbiased here. */
export function generateRecoveryCodes(count = 10): string[] {
  const codes = new Set<string>()
  while (codes.size < count) {
    const bytes = randomBytes(RECOVERY_LENGTH)
    const characters = Array.from(
      bytes,
      (byte) => RECOVERY_ALPHABET[byte % RECOVERY_ALPHABET.length],
    )
    codes.add(
      `${characters.slice(0, 5).join("")}-${characters.slice(5).join("")}`,
    )
  }
  return [...codes]
}

export function normalizeRecoveryCode(code: string): string {
  return code.toUpperCase().replace(/[^A-Z0-9]/g, "")
}

/**
 * Recovery codes carry 50 bits of entropy, so a fast hash is appropriate. They
 * are compared by exact hash lookup and marked used once.
 */
export function hashRecoveryCode(code: string): string {
  return createHash("sha256").update(normalizeRecoveryCode(code)).digest("hex")
}
