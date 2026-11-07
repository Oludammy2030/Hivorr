import React from "react"
import ReactDOM from "react-dom/client"
import { getPortal } from "@hivorr/shared"
import "./foundation.css"

const portal = getPortal("staff")
document.title = `${portal.name} — Hivorr`

ReactDOM.createRoot(document.getElementById("root")!).render(
  <React.StrictMode>
    <main className="portal-foundation" data-portal={portal.id}>
      <h1>{portal.name}</h1>
      <p>Foundation build. Portal screens are not implemented yet.</p>
    </main>
  </React.StrictMode>,
)
