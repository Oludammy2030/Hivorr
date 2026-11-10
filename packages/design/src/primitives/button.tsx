import { forwardRef, type ButtonHTMLAttributes, type ReactNode } from "react"

import { colorTokens, fontTokens, radiusTokens } from "../tokens"

export type ButtonVariant = "primary" | "secondary" | "ghost" | "danger"
export type ButtonSize = "sm" | "md" | "lg"

export interface ButtonProps
  extends Omit<ButtonHTMLAttributes<HTMLButtonElement>, "children"> {
  readonly children: ReactNode
  readonly variant?: ButtonVariant
  readonly size?: ButtonSize
  readonly icon?: ReactNode
}

const variantStyles: Record<ButtonVariant, {
  background: string
  color: string
}> = {
  primary: { background: colorTokens.brand, color: colorTokens.surface },
  secondary: {
    background: colorTokens.brandTint,
    color: colorTokens.brand,
  },
  ghost: { background: colorTokens.surfaceSubtle, color: colorTokens.gray },
  danger: { background: colorTokens.dangerTint, color: colorTokens.danger },
}

interface SizeStyle {
  padding: string
  fontSize: number
}

const sizeStyles: Record<ButtonSize, SizeStyle> = {
  sm: { padding: "7px 14px", fontSize: 12 },
  md: { padding: "12px 20px", fontSize: 14 },
  lg: { padding: "15px 24px", fontSize: 16 },
}

/**
 * Primary interaction primitive, extracted from the prototype's `Btn`
 * (EP-01-051). Rendering is unchanged: 12 px radius, display family at 700,
 * the same paddings and sizes, and the same hover/disabled opacity.
 */
export const Button = forwardRef<HTMLButtonElement, ButtonProps>(
  function Button(
    {
      children,
      variant = "primary",
      size = "md",
      icon,
      disabled = false,
      type = "button",
      style,
      ...rest
    },
    ref,
  ) {
    const palette = variantStyles[variant]
    const dimensions = sizeStyles[size]

    return (
      <button
        {...rest}
        ref={ref}
        type={type}
        disabled={disabled}
        style={{
          background: palette.background,
          color: palette.color,
          padding: dimensions.padding,
          borderRadius: radiusTokens.control,
          fontFamily: fontTokens.display,
          fontWeight: 700,
          fontSize: dimensions.fontSize,
          display: "flex",
          alignItems: "center",
          justifyContent: "center",
          gap: 6,
          cursor: disabled ? "default" : "pointer",
          transition: "opacity 0.15s",
          whiteSpace: "nowrap",
          opacity: disabled ? 0.65 : 1,
          ...style,
        }}
        onMouseEnter={(event) => {
          event.currentTarget.style.opacity = "0.85"
          rest.onMouseEnter?.(event)
        }}
        onMouseLeave={(event) => {
          event.currentTarget.style.opacity = "1"
          rest.onMouseLeave?.(event)
        }}
      >
        {icon}
        {children}
      </button>
    )
  },
)
