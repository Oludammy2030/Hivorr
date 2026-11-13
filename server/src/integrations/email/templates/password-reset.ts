import { renderEmailLayout } from "./layout"

export interface PasswordResetEmailInput {
  readonly to: string
  readonly link: string
  readonly expiresInMinutes: number
}

export interface TransactionalEmail {
  readonly subject: string
  readonly text: string
  readonly html: string
}

export function buildPasswordResetEmail(
  input: PasswordResetEmailInput,
): TransactionalEmail {
  const subject = "Reset your Hivorr password"
  const window = `${input.expiresInMinutes} minutes`

  const text = [
    "Hello,",
    "",
    "A password reset was requested for your Hivorr account.",
    "",
    "Open the link below to choose a new password:",
    input.link,
    "",
    `This single-use link expires in ${window}.`,
    "",
    "If you did not request this, you do not need to do anything. Your password stays unchanged and the link expires on its own.",
    "",
    "— The Hivorr team",
  ].join("\n")

  const html = renderEmailLayout({
    preheader: `Reset your Hivorr password. The link expires in ${window}.`,
    eyebrow: "Password reset",
    heading: "Choose a new password",
    paragraphs: [
      "A password reset was requested for your Hivorr account.",
      "Open the link below to choose a new password. You will stay signed in on this device until the new password is saved.",
    ],
    action: { label: "Reset password", url: input.link },
    fallbackUrl: input.link,
    note: {
      title: `This link expires in ${window}.`,
      body: "It can be used once. If it expires, request a new reset link.",
    },
    recipient: input.to,
    footerNote:
      "You received this because a password reset was requested for {recipient}. If it was not you, no action is needed — your password has not changed.",
  })

  return { subject, text, html }
}
