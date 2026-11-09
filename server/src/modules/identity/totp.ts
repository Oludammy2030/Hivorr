import { createHmac, randomBytes, timingSafeEqual } from "node:crypto"

const BASE32_ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567"
const STEP_SECONDS = 30
const DIGITS = 6

/**
 * RFC 4648 base32 without padding. TOTP authenticator apps expect the secret in
 * this alphabet, not hex or base64.
 */
export function base32Encode(buffer: Buffer): string {
  let bits = 0
  let value = 0
  let output = ""
  for (const byte of buffer) {
    value = (value << 8) | byte
    bits += 8
    while (bits >= 5) {
      output += BASE32_ALPHABET[(value >>> (bits - 5)) & 31]
      bits -= 5
    }
  }
  if (bits > 0) {
    output += BASE32_ALPHABET[(value << (5 - bits)) & 31]
  }
  return output
}

export function base32Decode(input: string): Buffer {
  const normalized = input.toUpperCase().replace(/[\s=]/g, "")
  let bits = 0
  let value = 0
  const bytes: number[] = []
  for (const character of normalized) {
    const index = BASE32_ALPHABET.indexOf(character)
    if (index === -1) throw new Error("Invalid base32 character")
    value = (value << 5) | index
    bits += 5
    if (bits >= 8) {
      bytes.push((value >>> (bits - 8)) & 0xff)
      bits -= 8
    }
  }
  return Buffer.from(bytes)
}

/** 160 bits of entropy, the length RFC 4226 recommends for HMAC-SHA1. */
export function generateTotpSecret(): string {
  return base32Encode(randomBytes(20))
}

export function totpCode(secret: string, timeStep: number): string {
  const counter = Buffer.alloc(8)
  counter.writeBigUInt64BE(BigInt(timeStep))
  const digest = createHmac("sha1", base32Decode(secret))
    .update(counter)
    .digest()
  const offset = digest[digest.length - 1] & 0x0f
  const binary =
    (((digest[offset] & 0x7f) << 24) |
      (digest[offset + 1] << 16) |
      (digest[offset + 2] << 8) |
      digest[offset + 3]) >>>
    0
  return (binary % 10 ** DIGITS).toString().padStart(DIGITS, "0")
}

export function currentTimeStep(now: number = Date.now()): number {
  return Math.floor(now / 1000 / STEP_SECONDS)
}

/**
 * Accepts the current time step and one step either side to tolerate clock
 * drift. The comparison is constant time so a wrong code does not leak its
 * distance from the correct one through timing.
 */
export function verifyTotp(
  secret: string,
  code: string,
  now: number = Date.now(),
  window = 1,
): boolean {
  const normalized = code.replace(/\s+/g, "")
  if (!new RegExp(`^\\d{${DIGITS}}$`).test(normalized)) return false

  const step = currentTimeStep(now)
  const supplied = Buffer.from(normalized)
  let matched = false
  for (let offset = -window; offset <= window; offset += 1) {
    const expected = Buffer.from(totpCode(secret, step + offset))
    if (
      expected.length === supplied.length &&
      timingSafeEqual(expected, supplied)
    ) {
      matched = true
    }
  }
  return matched
}

export function totpUri(
  secret: string,
  accountName: string,
  issuer = "Hivorr",
): string {
  const label = encodeURIComponent(`${issuer}:${accountName}`)
  const query = new URLSearchParams({
    secret,
    issuer,
    algorithm: "SHA1",
    digits: String(DIGITS),
    period: String(STEP_SECONDS),
  })
  return `otpauth://totp/${label}?${query.toString()}`
}
