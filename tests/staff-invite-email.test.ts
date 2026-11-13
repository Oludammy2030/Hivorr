import { describe, expect, it } from "vitest"

import { hivorrMarkAttachment } from "../server/src/integrations/email/assets/hivorr-mark"
import { buildEmailVerificationEmail } from "../server/src/integrations/email/templates/email-verification"
import { buildPasswordResetEmail } from "../server/src/integrations/email/templates/password-reset"
import { buildStaffInviteEmail } from "../server/src/integrations/email/templates/staff-invite"

const link = "https://staging.hivorr.com/invite.html?token=abc123"
const accountEmail = "amara.okafor@hivorr.com"

interface BuildOverrides {
  jobTitle?: string
  to?: string
}

function build(overrides: BuildOverrides = {}) {
  return buildStaffInviteEmail({
    to: overrides.to ?? "new.staff@example.com",
    accountEmail,
    link,
    expiresAt: "2026-11-20T09:30:00.000Z",
    jobTitle: overrides.jobTitle,
  })
}

describe("staff invitation email", () => {
  it("offers a linked button and a plain-text fallback", () => {
    const email = build()

    expect(email.subject).toBe("You're invited to join Hivorr")
    expect(email.html).toContain(`href="${link}"`)
    expect(email.text).toContain(link)
    expect(email.text).toContain(
      "You have been invited to join Hivorr as a staff member.",
    )
  })

  it("renders a readable expiry rather than the raw timestamp", () => {
    const email = build()

    expect(email.text).toContain("expires on 20 November 2026")
    expect(email.html).toContain("expires on 20 November 2026")
    expect(email.html).not.toContain("2026-11-20T09:30")
  })

  it("names the role when one was given", () => {
    const email = build({ jobTitle: "Operations Associate" })

    expect(email.html).toContain("join Hivorr as Operations Associate.")
    expect(email.text).toContain("join Hivorr as Operations Associate.")
  })

  it("escapes every interpolated value", () => {
    const email = buildStaffInviteEmail({
      to: 'x"<script>@example.com',
      accountEmail: 'y"<script>@hivorr.com',
      link: 'https://staging.hivorr.com/invite.html?token=a"b<c>',
      expiresAt: "2026-11-20T09:30:00.000Z",
      jobTitle: "<b>Admin</b>",
    })

    expect(email.html).not.toContain("<script>")
    expect(email.html).not.toContain("<b>Admin</b>")
    expect(email.html).toContain("&lt;script&gt;")
    expect(email.html).toContain("&lt;b&gt;Admin&lt;/b&gt;")
  })

  it("tells the invitee to register with the official address", () => {
    const email = build()

    expect(email.html).toContain(accountEmail)
    expect(email.text).toContain(accountEmail)
    expect(email.text).toContain("Use that address to register")
    expect(email.html).toContain("Do not register with your personal address")
    expect(email.html).toContain("Your Hivorr email")
  })

  it("uses the brand surface and keeps a hidden preheader", () => {
    const email = build()

    expect(email.html).toContain("#2D3FE7")
    expect(email.html).toContain("#F0F2F8")
    expect(email.html).toContain("display:none")
    expect(email.html).toContain("Staff invitation")
  })

  it("references the inline mark that travels with the message", () => {
    const email = build()
    const mark = hivorrMarkAttachment()

    expect(email.html).toContain(`cid:${mark.cid}`)
    expect(mark.mimeType).toBe("image/png")
    expect(mark.content.length).toBeGreaterThan(1000)
    expect(mark.content).toMatch(/^[A-Za-z0-9+/=\s]+$/)
  })
})

describe("password reset email", () => {
  const resetLink = "https://staging.hivorr.com/reset.html?token=abc123"
  const email = buildPasswordResetEmail({
    to: "founder@example.com",
    link: resetLink,
    expiresInMinutes: 30,
  })

  it("links to the reset page and states the window", () => {
    expect(email.subject).toBe("Reset your Hivorr password")
    expect(email.html).toContain(`href="${resetLink}"`)
    expect(email.text).toContain(resetLink)
    expect(email.html).toContain("expires in 30 minutes")
  })

  it("reassures the recipient when they did not ask for it", () => {
    expect(email.text).toContain("If you did not request this")
    expect(email.html).toContain("your password has not changed")
  })
})

describe("email verification email", () => {
  const verifyLink = "https://staging.hivorr.com/verify.html?token=abc123"
  const email = buildEmailVerificationEmail({
    to: "founder@example.com",
    link: verifyLink,
    expiresInHours: 24,
  })

  it("links to the verification page and states the window", () => {
    expect(email.subject).toBe("Verify your Hivorr email")
    expect(email.html).toContain(`href="${verifyLink}"`)
    expect(email.text).toContain(verifyLink)
    expect(email.html).toContain("expires in 24 hours")
  })

  it("shares the same brand surfaces as every other message", () => {
    expect(email.html).toContain("#2D3FE7")
    expect(email.html).toContain("Hivorr")
    expect(email.html).toContain("Email verification")
  })
})
