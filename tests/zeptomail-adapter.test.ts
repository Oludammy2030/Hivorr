import { describe, expect, it } from "vitest"

import type { MailConfig } from "../server/src/config"
import { CaptureEmailAdapter } from "../server/src/integrations/email/email.adapter"
import {
  ZeptoMailAdapter,
  createEmailAdapter,
} from "../server/src/integrations/email/zeptomail.adapter"

const settings = {
  apiUrl: "https://api.zeptomail.com/v1.1/email",
  token: "send-mail-token",
  fromAddress: "no-reply@mail.hivorr.com",
  fromName: "Hivorr",
}

function mailConfig(overrides: Partial<MailConfig> = {}): MailConfig {
  return {
    token: settings.token,
    apiUrl: settings.apiUrl,
    fromAddress: settings.fromAddress,
    fromName: settings.fromName,
    appOrigin: "https://staging.hivorr.com",
    ...overrides,
  }
}

interface CapturedRequest {
  url: string
  init: RequestInit
}

describe("ZeptoMail adapter", () => {
  it("sends the documented payload with a send-only token", async () => {
    let captured: CapturedRequest | undefined
    const adapter = new ZeptoMailAdapter(settings, async (url, init) => {
      captured = { url: String(url), init: init ?? {} }
      return new Response(null, { status: 201 })
    })

    await adapter.send({
      to: "new.staff@example.com",
      subject: "Your Hivorr staff invitation",
      text: "Open the link.",
    })

    expect(captured?.url).toBe(settings.apiUrl)
    const headers = captured?.init.headers as Record<string, string>
    expect(headers.authorization).toBe(`Zoho-enczapikey ${settings.token}`)
    expect(JSON.parse(String(captured?.init.body))).toEqual({
      from: { address: settings.fromAddress, name: settings.fromName },
      to: [{ email_address: { address: "new.staff@example.com" } }],
      subject: "Your Hivorr staff invitation",
      textbody: "Open the link.",
    })
  })

  it("adds the rich body only when the message has one", async () => {
    const bodies: string[] = []
    const adapter = new ZeptoMailAdapter(settings, async (_url, init) => {
      bodies.push(String(init?.body))
      return new Response(null, { status: 201 })
    })

    await adapter.send({ to: "x@example.com", subject: "s", text: "t" })
    await adapter.send({
      to: "x@example.com",
      subject: "s",
      text: "t",
      html: "<p>rich</p>",
    })

    expect(JSON.parse(bodies[0]!)).not.toHaveProperty("htmlbody")
    expect(JSON.parse(bodies[1]!).htmlbody).toBe("<p>rich</p>")
  })

  it("fails without exposing the provider response body", async () => {
    const adapter = new ZeptoMailAdapter(
      settings,
      async () => new Response("secret provider detail", { status: 401 }),
    )

    await expect(
      adapter.send({ to: "x@example.com", subject: "s", text: "t" }),
    ).rejects.toThrow("zeptomail delivery failed with status 401")
  })

  it("does not double the auth scheme when the token already has it", async () => {
    let header: string | undefined
    const adapter = new ZeptoMailAdapter(
      { ...settings, token: "  Zoho-enczapikey copied-token  " },
      async (_url, init) => {
        header = (init?.headers as Record<string, string>).authorization
        return new Response(null, { status: 201 })
      },
    )

    await adapter.send({ to: "x@example.com", subject: "s", text: "t" })

    expect(header).toBe("Zoho-enczapikey copied-token")
  })

  it("stays on the capture adapter until a token and sender exist", () => {
    expect(createEmailAdapter(mailConfig({ token: undefined }))).toBeInstanceOf(
      CaptureEmailAdapter,
    )
    expect(
      createEmailAdapter(mailConfig({ fromAddress: undefined })),
    ).toBeInstanceOf(CaptureEmailAdapter)
    expect(createEmailAdapter(mailConfig())).toBeInstanceOf(ZeptoMailAdapter)
  })
})
