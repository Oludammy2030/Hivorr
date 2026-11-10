import type { HTMLAttributes, ReactNode } from "react"

import { colorTokens, radiusTokens } from "../tokens"
import type { PillTone } from "../tokens"

interface ToneStyle {
  color: string
  background: string
}

const toneStyles: Record<PillTone, ToneStyle> = {
  brand: { color: colorTokens.brand, background: colorTokens.brandTint },
  success: { color: colorTokens.success, background: colorTokens.successTint },
  attention: {
    color: colorTokens.attention,
    background: colorTokens.attentionTint,
  },
  seller: { color: colorTokens.seller, background: colorTokens.sellerTint },
  danger: { color: colorTokens.danger, background: colorTokens.dangerTint },
  info: { color: colorTokens.info, background: colorTokens.infoTint },
  neutral: {
    color: colorTokens.gray,
    background: colorTokens.surfaceSubtle,
  },
}

export interface PillProps
  extends Omit<HTMLAttributes<HTMLSpanElement>, "color"> {
  readonly children: ReactNode
  readonly tone?: PillTone
}

/**
 * Status pill, extracted from the prototype's `Pill` (EP-01-051). Status is
 * always carried by the label text, never by colour alone (AGENTS.md §2.11).
 */
export function Pill({
  children,
  tone = "neutral",
  style,
  ...rest
}: PillProps) {
  const palette = toneStyles[tone]

  return (
    <span
      {...rest}
      title={
        rest.title ?? (typeof children === "string" ? children : undefined)
      }
      style={{
        color: palette.color,
        background: palette.background,
        fontSize: 11,
        fontWeight: 600,
        padding: "3px 9px",
        borderRadius: radiusTokens.pill,
        whiteSpace: "nowrap",
        display: "inline-block",
        maxWidth: "100%",
        overflow: "hidden",
        textOverflow: "ellipsis",
        verticalAlign: "middle",
        ...style,
      }}
    >
      {children}
    </span>
  )
}
