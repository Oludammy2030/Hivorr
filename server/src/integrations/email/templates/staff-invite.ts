import { formatExpiryDate, renderEmailLayout } from "./layout"

export interface StaffInviteEmailInput {
  readonly to: string
  readonly link: string
  readonly expiresAt: string
  readonly jobTitle?: string | undefined
}

export interface StaffInviteEmail {
  readonly subject: string
  readonly text: string
  readonly html: string
}

export function buildStaffInviteEmail(
  input: StaffInviteEmailInput,
): StaffInviteEmail {
  const expiry = formatExpiryDate(input.expiresAt)
  const role = input.jobTitle?.trim()
  const intro = role
    ? `You have been invited to join Hivorr as ${role}.`
    : "You have been invited to join Hivorr as a staff member."

  const subject = "You're invited to join Hivorr"

  const text = [
    "Hello,",
    "",
    intro,
    "",
    "Open the link below to set your password and register your authenticator:",
    input.link,
    "",
    `This single-use link expires on ${expiry}.`,
    "",
    "If you were not expecting this invitation, you can ignore this email. The link cannot be used once it expires.",
    "",
    "— The Hivorr team",
  ].join("\n")

  const html = renderEmailLayout({
    preheader:
      "You have been invited to join Hivorr. Set your password and authenticator within 7 days.",
    eyebrow: "Staff invitation",
    heading: "You're invited to join Hivorr",
    paragraphs: [
      intro,
      "Set your password and register an authenticator to activate your account. This takes about two minutes.",
    ],
    action: { label: "Accept invitation", url: input.link },
    fallbackUrl: input.link,
    note: {
      title: `This link expires on ${expiry}.`,
      body: "It can be used once. If it expires, ask your administrator for a new invitation.",
    },
    recipient: input.to,
    footerNote:
      "You received this because an administrator invited {recipient} to Hivorr. If you were not expecting it, you can ignore this email — no account is created until the link is used.",
  })

  return { subject, text, html }
}
