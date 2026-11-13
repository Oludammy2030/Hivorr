import { describe, expect, it } from "vitest"

import { buildStaffInviteEmail } from "../server/src/integrations/email/templates/staff-invite"

const link = "https://staging.hivorr.com/invite.html?token=abc123"

interface BuildOverrides {
  jobTitle?: string
  to?: string
}

function build(overrides: BuildOverrides = {}) {
  return buildStaffInviteEmail({
    to: overrides.to ?? "new.staff@example.com",
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
      link: 'https://staging.hivorr.com/invite.html?token=a"b<c>',
      expiresAt: "2026-11-20T09:30:00.000Z",
      jobTitle: "<b>Admin</b>",
    })

    expect(email.html).not.toContain("<script>")
    expect(email.html).not.toContain("<b>Admin</b>")
    expect(email.html).toContain("&lt;script&gt;")
    expect(email.html).toContain("&lt;b&gt;Admin&lt;/b&gt;")
  })

  it("uses the brand surface and keeps a hidden preheader", () => {
    const email = build()

    expect(email.html).toContain("#2D3FE7")
    expect(email.html).toContain("#F0F2F8")
    expect(email.html).toContain("display:none")
    expect(email.html).toContain("Staff invitation")
  })
})
