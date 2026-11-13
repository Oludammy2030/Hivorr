import { renderEmailLayout } from "./layout"
import type { TransactionalEmail } from "./password-reset"

export interface EmailVerificationEmailInput {
  readonly to: string
  readonly link: string
  readonly expiresInHours: number
}

export function buildEmailVerificationEmail(
  input: EmailVerificationEmailInput,
): TransactionalEmail {
  const subject = "Verify your Hivorr email"
  const window = `${input.expiresInHours} hours`

  const text = [
    "Hello,",
    "",
    "Confirm this address is yours so we can reach you about your Hivorr account.",
    "",
    "Open the link below to verify your email:",
    input.link,
    "",
    `This single-use link expires in ${window}.`,
    "",
    "If you did not ask for this, you can ignore this email.",
    "",
    "— The Hivorr team",
  ].join("\n")

  const html = renderEmailLayout({
    preheader: `Confirm your Hivorr email address. The link expires in ${window}.`,
    eyebrow: "Email verification",
    heading: "Confirm your email address",
    paragraphs: [
      "Confirm this address is yours so we can reach you about your Hivorr account.",
      "Open the link below to verify your email. You will be taken back to the portal when it succeeds.",
    ],
    action: { label: "Verify email", url: input.link },
    fallbackUrl: input.link,
    note: {
      title: `This link expires in ${window}.`,
      body: "It can be used once. You can request another verification email from your account settings.",
    },
    recipient: input.to,
    footerNote:
      "You received this because email verification was requested for {recipient}. If it was not you, you can ignore this email.",
  })

  return { subject, text, html }
}
