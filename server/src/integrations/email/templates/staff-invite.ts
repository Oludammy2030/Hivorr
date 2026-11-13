/**
 * Staff invitation email.
 *
 * The layout is deliberately table-based with inline styles: Outlook and Gmail
 * ignore `<style>` blocks and modern layout, so anything clever breaks in one
 * client or another. Colours come from the visual identity palette.
 */
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

const BRAND = {
  primary: "#2D3FE7",
  primaryTint: "#EEF0FD",
  ink: "#0F1626",
  body: "#374151",
  gray: "#6B7280",
  muted: "#9CA3AF",
  border: "#E5E7EB",
  background: "#F0F2F8",
  card: "#FFFFFF",
} as const

const FONT_STACK =
  "-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif"

function escapeHtml(value: string): string {
  return value
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;")
}

function formatExpiry(expiresAt: string): string {
  const date = new Date(expiresAt)
  if (Number.isNaN(date.getTime())) return expiresAt

  return new Intl.DateTimeFormat("en-GB", {
    day: "numeric",
    month: "long",
    year: "numeric",
    timeZone: "UTC",
  }).format(date)
}

export function buildStaffInviteEmail(
  input: StaffInviteEmailInput,
): StaffInviteEmail {
  const expiry = formatExpiry(input.expiresAt)
  const role = input.jobTitle?.trim()
  const intro = role
    ? `You have been invited to join Hivorr as ${escapeHtml(role)}.`
    : "You have been invited to join Hivorr as a staff member."
  const introText = role
    ? `You have been invited to join Hivorr as ${role}.`
    : "You have been invited to join Hivorr as a staff member."

  const subject = "You're invited to join Hivorr"
  const link = escapeHtml(input.link)
  const recipient = escapeHtml(input.to)

  const text = [
    "Hello,",
    "",
    introText,
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

  const html = `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<meta name="x-apple-disable-message-reformatting">
<meta name="color-scheme" content="light">
<meta name="supported-color-schemes" content="light">
<title>${escapeHtml(subject)}</title>
</head>
<body style="margin:0;padding:0;width:100%;background-color:${BRAND.background};">
<div style="display:none;font-size:1px;line-height:1px;max-height:0;max-width:0;opacity:0;overflow:hidden;mso-hide:all;">You have been invited to join Hivorr. Set your password and authenticator within 7 days.</div>
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="width:100%;background-color:${BRAND.background};">
  <tr>
    <td align="center" style="padding:40px 16px;">
      <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="width:100%;max-width:560px;background-color:${BRAND.card};border:1px solid ${BRAND.border};border-radius:16px;">
        <tr>
          <td style="padding:28px 32px 0 32px;">
            <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
              <tr>
                <td align="left" style="font-family:${FONT_STACK};font-size:22px;font-weight:800;letter-spacing:-0.5px;color:${BRAND.ink};">Hivorr</td>
                <td align="right" style="font-family:${FONT_STACK};font-size:11px;font-weight:700;letter-spacing:1.2px;text-transform:uppercase;color:${BRAND.muted};">Staff invitation</td>
              </tr>
            </table>
          </td>
        </tr>
        <tr>
          <td style="padding:20px 32px 0 32px;">
            <div style="height:1px;background-color:${BRAND.border};line-height:1px;font-size:0;">&nbsp;</div>
          </td>
        </tr>
        <tr>
          <td style="padding:28px 32px 0 32px;font-family:${FONT_STACK};">
            <h1 style="margin:0 0 12px 0;font-size:24px;line-height:32px;font-weight:700;color:${BRAND.ink};">You're invited to join Hivorr</h1>
            <p style="margin:0 0 16px 0;font-size:15px;line-height:24px;color:${BRAND.body};">${intro}</p>
            <p style="margin:0 0 24px 0;font-size:15px;line-height:24px;color:${BRAND.body};">Set your password and register an authenticator to activate your account. This takes about two minutes.</p>
          </td>
        </tr>
        <tr>
          <td align="left" style="padding:0 32px;">
            <table role="presentation" cellpadding="0" cellspacing="0" border="0">
              <tr>
                <td align="center" bgcolor="${BRAND.primary}" style="border-radius:10px;">
                  <a href="${link}" target="_blank" rel="noopener" style="display:inline-block;padding:14px 28px;font-family:${FONT_STACK};font-size:15px;font-weight:600;line-height:20px;color:#FFFFFF;text-decoration:none;border-radius:10px;">Accept invitation</a>
                </td>
              </tr>
            </table>
          </td>
        </tr>
        <tr>
          <td style="padding:24px 32px 0 32px;font-family:${FONT_STACK};">
            <p style="margin:0 0 6px 0;font-size:12px;line-height:18px;color:${BRAND.gray};">If the button does not work, copy this link into your browser:</p>
            <p style="margin:0;font-size:12px;line-height:18px;word-break:break-all;"><a href="${link}" target="_blank" rel="noopener" style="color:${BRAND.primary};text-decoration:underline;">${link}</a></p>
          </td>
        </tr>
        <tr>
          <td style="padding:24px 32px 0 32px;">
            <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="width:100%;background-color:${BRAND.primaryTint};border-radius:12px;">
              <tr>
                <td style="padding:14px 16px;font-family:${FONT_STACK};font-size:13px;line-height:20px;color:${BRAND.ink};">
                  <strong style="font-weight:600;">This link expires on ${escapeHtml(expiry)}.</strong>
                  It can be used once. If it expires, ask your administrator for a new invitation.
                </td>
              </tr>
            </table>
          </td>
        </tr>
        <tr>
          <td style="padding:24px 32px 32px 32px;font-family:${FONT_STACK};">
            <div style="height:1px;background-color:${BRAND.border};line-height:1px;font-size:0;margin-bottom:20px;">&nbsp;</div>
            <p style="margin:0 0 6px 0;font-size:12px;line-height:18px;color:${BRAND.gray};">You received this because an administrator invited ${recipient} to Hivorr. If you were not expecting it, you can ignore this email — no account is created until the link is used.</p>
            <p style="margin:0;font-size:12px;line-height:18px;color:${BRAND.muted};">Hivorr · This mailbox is not monitored.</p>
          </td>
        </tr>
      </table>
    </td>
  </tr>
</table>
</body>
</html>`

  return { subject, text, html }
}
