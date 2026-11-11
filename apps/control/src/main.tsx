import React from "react"
import ReactDOM from "react-dom/client"
import { BrowserRouter } from "react-router"
import { getPortal } from "@hivorr/shared"

import { App } from "./App"
import "./foundation.css"

const portal = getPortal("control")
document.title = `${portal.name} — Hivorr`

ReactDOM.createRoot(document.getElementById("root")!).render(
  <React.StrictMode>
    <BrowserRouter>
      <App />
    </BrowserRouter>
  </React.StrictMode>,
)
