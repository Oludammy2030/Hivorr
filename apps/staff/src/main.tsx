import React from "react"
import ReactDOM from "react-dom/client"
import { getPortal } from "@hivorr/shared"

import { App } from "./App"
import "./foundation.css"

const portal = getPortal("staff")
document.title = `${portal.name} — Hivorr`

ReactDOM.createRoot(document.getElementById("root")!).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>,
)
