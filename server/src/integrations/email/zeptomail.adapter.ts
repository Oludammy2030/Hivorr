import type { MailConfig } from "../../config"
import {
  CaptureEmailAdapter,
  type EmailAdapter,
  type EmailMessage,
} from "./email.adapter"

interface ZeptoMailSettings {
  readonly apiUrl: string
  readonly token: string
  readonly fromAddress: string
  readonly fromName: string
}

/**
 * Sends through the ZeptoMail transactional API (Zoho).
 *
 * The token is a send-only Mail Agent credential. It is placed only in the
 * request header; recipients and message bodies are never logged here.
 */
export class ZeptoMailAdapter implements EmailAdapter {
  constructor(
    private readonly settings: ZeptoMailSettings,
    private readonly fetchImpl: typeof fetch = fetch,
  ) {}

  async send(message: EmailMessage): Promise<void> {
    const response = await this.fetchImpl(this.settings.apiUrl, {
      method: "POST",
      headers: {
        authorization: `Zoho-enczapikey ${this.settings.token}`,
        "content-type": "application/json",
        accept: "application/json",
      },
      body: JSON.stringify({
        from: {
          address: this.settings.fromAddress,
          name: this.settings.fromName,
        },
        to: [{ email_address: { address: message.to } }],
        subject: message.subject,
        textbody: message.text,
      }),
      signal: AbortSignal.timeout(10_000),
    })

    if (!response.ok) {
      throw new Error(
        `zeptomail delivery failed with status ${response.status}`,
      )
    }
  }
}

/**
 * Uses ZeptoMail when a token and sender are configured, and the capture
 * adapter otherwise so local and test runs never reach the network.
 */
export function createEmailAdapter(
  config: MailConfig | undefined,
): EmailAdapter {
  if (!config?.token || !config.fromAddress) {
    return new CaptureEmailAdapter()
  }

  return new ZeptoMailAdapter({
    apiUrl: config.apiUrl,
    token: config.token,
    fromAddress: config.fromAddress,
    fromName: config.fromName,
  })
}
