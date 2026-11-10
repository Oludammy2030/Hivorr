import { Link } from "react-router"

import {
  colorTokens,
  fontTokens,
  radiusTokens,
  shadowTokens,
} from "@hivorr/design"

/**
 * Real 404 for the slice. It is deliberately outside the prototype screens:
 * an unknown path must resolve to an explicit, labelled page, not a blank
 * screen or the nearest route.
 */
export function NotFound() {
  return (
    <main
      data-testid="not-found"
      style={{
        minHeight: "100vh",
        display: "flex",
        alignItems: "center",
        justifyContent: "center",
        padding: 24,
        background: "var(--background)",
      }}
    >
      <div
        style={{
          width: "100%",
          maxWidth: 440,
          textAlign: "center",
          background: colorTokens.surface,
          border: `1px solid ${colorTokens.border}`,
          borderRadius: radiusTokens.control,
          boxShadow: shadowTokens.rest,
          padding: 32,
        }}
      >
        <p
          style={{
            color: colorTokens.brand,
            fontFamily: fontTokens.display,
            fontWeight: 800,
            fontSize: 13,
            letterSpacing: 1.5,
          }}
        >
          404
        </p>
        <h1
          style={{
            fontFamily: fontTokens.display,
            fontWeight: 800,
            fontSize: 26,
            color: colorTokens.ink,
            marginTop: 8,
          }}
        >
          Page not found
        </h1>
        <p
          style={{
            color: colorTokens.gray,
            fontSize: 15,
            lineHeight: 1.6,
            marginTop: 8,
          }}
        >
          This address does not match a Hivorr route.
        </p>
        <Link
          to="/"
          style={{
            display: "inline-flex",
            alignItems: "center",
            justifyContent: "center",
            marginTop: 20,
            padding: "12px 20px",
            borderRadius: radiusTokens.control,
            background: colorTokens.brand,
            color: colorTokens.surface,
            fontFamily: fontTokens.display,
            fontWeight: 700,
            fontSize: 14,
            textDecoration: "none",
          }}
        >
          Back to Hivorr
        </Link>
      </div>
    </main>
  )
}
