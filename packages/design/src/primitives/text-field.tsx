import { forwardRef, useId, type InputHTMLAttributes } from "react"

import { colorTokens, fontTokens, radiusTokens } from "../tokens"

export interface TextFieldProps
  extends Omit<InputHTMLAttributes<HTMLInputElement>, "size"> {
  /** Visible label. The prototype renders it above the field. */
  readonly label?: string
}

/**
 * Single-line text field, extracted from the prototype's `Input` (EP-01-051).
 * The fill, 1.5 px transparent border, focus colour, 13/14 px type and 12 px
 * radius are unchanged; the label is now associated with the input.
 */
export const TextField = forwardRef<HTMLInputElement, TextFieldProps>(
  function TextField({ label, id, style, onFocus, onBlur, ...rest }, ref) {
    const generatedId = useId()
    const fieldId = id ?? generatedId

    return (
      <div style={{ display: "flex", flexDirection: "column", gap: 6 }}>
        {label ? (
          <label
            htmlFor={fieldId}
            style={{
              fontSize: 13,
              fontWeight: 600,
              color: colorTokens.body,
            }}
          >
            {label}
          </label>
        ) : null}
        <input
          {...rest}
          ref={ref}
          id={fieldId}
          style={{
            width: "100%",
            padding: "13px 14px",
            background: colorTokens.surfaceSubtle,
            borderRadius: radiusTokens.control,
            border: "1.5px solid transparent",
            fontSize: 14,
            outline: "none",
            boxSizing: "border-box",
            fontFamily: fontTokens.body,
            color: colorTokens.ink,
            transition: "border-color 0.2s",
            ...style,
          }}
          onFocus={(event) => {
            event.currentTarget.style.borderColor = colorTokens.brand
            onFocus?.(event)
          }}
          onBlur={(event) => {
            event.currentTarget.style.borderColor = "transparent"
            onBlur?.(event)
          }}
        />
      </div>
    )
  },
)
