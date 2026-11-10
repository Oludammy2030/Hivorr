/**
 * Design tokens as CSS custom-property references (EP-01-051).
 *
 * `src/styles/theme.css` is the only place that defines a colour value
 * (AGENTS.md §2.12). This module names the references; it must never carry a
 * hex, an rgb(), or a second palette. A test asserts every reference exists in
 * the theme layer.
 */

export const colorTokens = {
  brand: "var(--hivorr-blue)",
  brandTint: "var(--hivorr-blue-tint)",
  success: "var(--hivorr-green)",
  successTint: "var(--hivorr-green-tint)",
  attention: "var(--hivorr-orange)",
  attentionTint: "var(--hivorr-orange-tint)",
  seller: "var(--hivorr-purple)",
  sellerTint: "var(--hivorr-purple-tint)",
  danger: "var(--hivorr-red)",
  dangerTint: "var(--hivorr-red-tint)",
  info: "var(--hivorr-cyan)",
  infoTint: "var(--hivorr-cyan-tint)",
  ink: "var(--hivorr-ink)",
  body: "var(--hivorr-body)",
  bodySoft: "var(--hivorr-body-soft)",
  mutedText: "var(--hivorr-muted-text)",
  /** `C.gray` in the prototype; theme exposes this value as a shadcn token. */
  gray: "var(--muted-foreground)",
  surface: "var(--hivorr-surface)",
  surfaceSubtle: "var(--hivorr-surface-subtle)",
  border: "var(--hivorr-border)",
  disabled: "var(--hivorr-disabled)",
} as const

export const fontTokens = {
  display: "var(--hivorr-font-display)",
  body: "var(--hivorr-font-body)",
} as const

export const radiusTokens = {
  control: "var(--radius)",
  pill: "20px",
} as const

export const shadowTokens = {
  rest: "var(--hivorr-shadow-rest)",
  hover: "var(--hivorr-shadow-hover)",
  overlay: "var(--hivorr-shadow-overlay)",
} as const

export const gradientTokens = {
  auth: "var(--hivorr-gradient-auth)",
} as const

/** Every token reference the primitives may use. */
export const tokenReferences = [
  ...Object.values(colorTokens),
  ...Object.values(fontTokens),
  ...Object.values(radiusTokens),
  ...Object.values(shadowTokens),
  ...Object.values(gradientTokens),
] as const

export type ColorToken = keyof typeof colorTokens
export type PillTone = "brand" | "success" | "attention" | "seller" | "danger" | "info" | "neutral"
