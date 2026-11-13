/**
 * Shared transactional email layout.
 *
 * Every Hivorr message renders through this shell so the brand, spacing and
 * footer cannot drift between messages. The markup is table-based with inline
 * styles because Gmail and Outlook ignore `<style>` blocks and modern layout.
 */
import { HIVORR_MARK_CID } from "../assets/hivorr-mark"

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

export interface EmailAction {
  readonly label: string
  readonly url: string
}

export interface EmailNote {
  readonly title: string
  readonly body: string
}

/** A labelled value shown in a bordered block, for an address or reference. */
export interface EmailReference {
  readonly label: string
  readonly value: string
  readonly hint?: string
}

export interface EmailLayoutInput {
  /** Inbox preview line, hidden in the body. */
  readonly preheader: string
  /** Small tracked label beside the wordmark. */
  readonly eyebrow: string
  readonly heading: string
  /** Plain text; escaped by the layout. */
  readonly paragraphs: readonly string[]
  readonly action?: EmailAction
  readonly note?: EmailNote
  /** Shown above the action when the message must state one exact value. */
  readonly reference?: EmailReference
  /** Shown when a client cannot follow the action, or when there is no action. */
  readonly fallbackUrl?: string
  readonly recipient: string
  readonly footerNote: string
}

export function escapeHtml(value: string): string {
  return value
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;")
}

/** Renders an ISO timestamp as a readable date in UTC. */
export function formatExpiryDate(value: string): string {
  const date = new Date(value)
  if (Number.isNaN(date.getTime())) return value

  return new Intl.DateTimeFormat("en-GB", {
    day: "numeric",
    month: "long",
    year: "numeric",
    timeZone: "UTC",
  }).format(date)
}

export function renderEmailLayout(input: EmailLayoutInput): string {
  const action = input.action
  const note = input.note
  const fallback = input.fallbackUrl

  const actionRow = action
    ? `<tr>
          <td align="left" style="padding:4px 32px 0 32px;">
            <table role="presentation" cellpadding="0" cellspacing="0" border="0">
              <tr>
                <td align="center" bgcolor="${BRAND.primary}" style="border-radius:10px;">
                  <a href="${escapeHtml(action.url)}" target="_blank" rel="noopener" style="display:inline-block;padding:14px 28px;font-family:${FONT_STACK};font-size:15px;font-weight:600;line-height:20px;color:#FFFFFF;text-decoration:none;border-radius:10px;">${escapeHtml(action.label)}</a>
                </td>
              </tr>
            </table>
          </td>
        </tr>`
    : ""

  const fallbackRow = fallback
    ? `<tr>
          <td style="padding:22px 32px 0 32px;font-family:${FONT_STACK};">
            <p style="margin:0 0 6px 0;font-size:12px;line-height:18px;color:${BRAND.gray};">If the button does not work, copy this link into your browser:</p>
            <p style="margin:0;font-size:12px;line-height:18px;word-break:break-all;"><a href="${escapeHtml(fallback)}" target="_blank" rel="noopener" style="color:${BRAND.primary};text-decoration:underline;">${escapeHtml(fallback)}</a></p>
          </td>
        </tr>`
    : ""

  const noteRow = note
    ? `<tr>
          <td style="padding:24px 32px 0 32px;">
            <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="width:100%;background-color:${BRAND.primaryTint};border-radius:12px;">
              <tr>
                <td style="padding:14px 16px;font-family:${FONT_STACK};font-size:13px;line-height:20px;color:${BRAND.ink};">
                  <strong style="font-weight:600;">${escapeHtml(note.title)}</strong>
                  ${escapeHtml(note.body)}
                </td>
              </tr>
            </table>
          </td>
        </tr>`
    : ""

  const referenceRow = input.reference
    ? `<tr>
          <td style="padding:24px 32px 0 32px;">
            <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="width:100%;border:1px solid ${BRAND.border};border-radius:12px;">
              <tr>
                <td style="padding:14px 16px;font-family:${FONT_STACK};">
                  <p style="margin:0 0 4px 0;font-size:11px;font-weight:700;letter-spacing:1.2px;text-transform:uppercase;color:${BRAND.gray};">${escapeHtml(input.reference.label)}</p>
                  <p style="margin:0;font-size:15px;line-height:22px;font-weight:600;color:${BRAND.ink};word-break:break-all;">${escapeHtml(input.reference.value)}</p>
                  ${
                    input.reference.hint
                      ? `<p style="margin:6px 0 0 0;font-size:12px;line-height:18px;color:${BRAND.gray};">${escapeHtml(input.reference.hint)}</p>`
                      : ""
                  }
                </td>
              </tr>
            </table>
          </td>
        </tr>`
    : ""

  const paragraphs = input.paragraphs
    .map(
      (paragraph) =>
        `<p style="margin:0 0 16px 0;font-size:15px;line-height:24px;color:${BRAND.body};">${escapeHtml(paragraph)}</p>`,
    )
    .join("\n            ")

  return `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<meta name="x-apple-disable-message-reformatting">
<meta name="color-scheme" content="light">
<meta name="supported-color-schemes" content="light">
<title>${escapeHtml(input.heading)}</title>
</head>
<body style="margin:0;padding:0;width:100%;background-color:${BRAND.background};">
<div style="display:none;font-size:1px;line-height:1px;max-height:0;max-width:0;opacity:0;overflow:hidden;mso-hide:all;">${escapeHtml(input.preheader)}</div>
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="width:100%;background-color:${BRAND.background};">
  <tr>
    <td align="center" style="padding:40px 16px;">
      <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="width:100%;max-width:560px;background-color:${BRAND.card};border:1px solid ${BRAND.border};border-radius:16px;">
        <tr>
          <td style="padding:28px 32px 0 32px;">
            <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
              <tr>
                <td align="left" style="vertical-align:middle;">
                  <table role="presentation" cellpadding="0" cellspacing="0" border="0">
                    <tr>
                      <td style="vertical-align:middle;padding-right:10px;">
                        <img src="cid:${HIVORR_MARK_CID}" width="36" height="36" alt="Hivorr" style="display:block;border:0;outline:none;text-decoration:none;border-radius:10px;">
                      </td>
                      <td style="vertical-align:middle;font-family:${FONT_STACK};font-size:22px;font-weight:800;letter-spacing:-0.5px;color:${BRAND.ink};">Hivorr</td>
                    </tr>
                  </table>
                </td>
                <td align="right" style="vertical-align:middle;font-family:${FONT_STACK};font-size:11px;font-weight:700;letter-spacing:1.2px;text-transform:uppercase;color:${BRAND.muted};">${escapeHtml(input.eyebrow)}</td>
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
            <h1 style="margin:0 0 12px 0;font-size:24px;line-height:32px;font-weight:700;color:${BRAND.ink};">${escapeHtml(input.heading)}</h1>
            ${paragraphs}
          </td>
        </tr>
        ${referenceRow}
        ${actionRow}
        ${fallbackRow}
        ${noteRow}
        <tr>
          <td style="padding:24px 32px 32px 32px;font-family:${FONT_STACK};">
            <div style="height:1px;background-color:${BRAND.border};line-height:1px;font-size:0;margin-bottom:20px;">&nbsp;</div>
            <p style="margin:0 0 6px 0;font-size:12px;line-height:18px;color:${BRAND.gray};">${escapeHtml(input.footerNote.replace("{recipient}", input.recipient))}</p>
            <p style="margin:0;font-size:12px;line-height:18px;color:${BRAND.muted};">Hivorr · This mailbox is not monitored.</p>
          </td>
        </tr>
      </table>
    </td>
  </tr>
</table>
</body>
</html>`
}
