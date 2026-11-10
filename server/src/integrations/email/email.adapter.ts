/**
 * Capture-only email adapter (EP-01-031).
 *
 * No provider credential exists yet. The adapter records the message in
 * memory so a test or an operator can inspect it; it never logs the message,
 * the token, or the recipient. A real provider adapter replaces it without
 * changing the service contract.
 */
export interface EmailMessage {
  readonly to: string
  readonly subject: string
  readonly text: string
}

export interface EmailAdapter {
  send(message: EmailMessage): Promise<void>
}

export const EMAIL_ADAPTER = "HIVORR_EMAIL_ADAPTER" as const

export class CaptureEmailAdapter implements EmailAdapter {
  private readonly messages: EmailMessage[] = []

  async send(message: EmailMessage): Promise<void> {
    this.messages.push({ ...message })
  }

  captured(): readonly EmailMessage[] {
    return [...this.messages]
  }

  clear(): void {
    this.messages.length = 0
  }
}
