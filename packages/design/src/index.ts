/**
 * Design-system boundary for the four portal bundles.
 *
 * The prototype remains the visual authority. `src/app/App.tsx` and
 * `src/styles/theme.css` are still the source of the design language; this
 * package carries the extracted tokens and primitives for the EP-01 slice
 * (EP-01-051), guarded by visual regression.
 *
 * Only primitives the slice uses belong here. The shadcn kit is not a source,
 * and a second palette, icon set, CSS-in-JS layer or component library is
 * forbidden.
 */

export const DESIGN_PACKAGE_NAME = "@hivorr/design" as const

export {
  colorTokens,
  fontTokens,
  gradientTokens,
  radiusTokens,
  shadowTokens,
  tokenReferences,
  type ColorToken,
  type PillTone,
} from "./tokens"
export {
  Button,
  type ButtonProps,
  type ButtonSize,
  type ButtonVariant,
} from "./primitives/button"
export { TextField, type TextFieldProps } from "./primitives/text-field"
export { Pill, type PillProps } from "./primitives/pill"
