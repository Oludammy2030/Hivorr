import { createRoot } from "react-dom/client"

import { Button, Pill, TextField } from "../../packages/design/src/index"
import "../../src/styles/index.css"

const container = document.getElementById("root")
if (!container) throw new Error("missing #root")

createRoot(container).render(
  <div
    style={{
      background: "var(--hivorr-surface)",
      minHeight: "100vh",
      padding: 24,
      display: "flex",
      flexDirection: "column",
      alignItems: "flex-start",
      gap: 16,
    }}
  >
    <div data-parity="button-primary-lg" style={{ display: "block" }}>
      <Button size="lg">Sign In</Button>
    </div>
    <div data-parity="text-field">
      <TextField label="Email" placeholder="you@example.com" />
    </div>
    <div
      data-parity="pill-brand"
      style={{ display: "flex", alignItems: "center" }}
    >
      <Pill tone="brand">One account · Many activities</Pill>
    </div>
  </div>,
)
