import { useEffect, useState, type FormEvent } from "react"

import {
  api,
  errorMessage,
  isMfaChallenge,
  type MfaChallenge,
  type Session,
} from "./api"

interface LoadingView {
  kind: "loading"
}

interface SignedOutView {
  kind: "signedOut"
  error?: string
}

interface MfaView {
  kind: "mfa"
  challenge: MfaChallenge
  error?: string
}

interface SignedInView {
  kind: "signedIn"
  session: Session
}

type View = LoadingView | SignedOutView | MfaView | SignedInView

function formatTime(value: string): string {
  return new Date(value).toLocaleString(undefined, {
    dateStyle: "medium",
    timeStyle: "short",
  })
}

export function App() {
  const [view, setView] = useState<View>({ kind: "loading" })
  const [busy, setBusy] = useState(false)

  useEffect(() => {
    let active = true
    api
      .session()
      .then((session) => {
        if (active) setView({ kind: "signedIn", session })
      })
      .catch((error: unknown) => {
        if (!active) return
        setView({ kind: "signedOut", error: errorMessage(error) })
      })
    return () => {
      active = false
    }
  }, [])

  async function handleSignIn(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    const form = new FormData(event.currentTarget)
    const email = String(form.get("email") ?? "").trim()
    const password = String(form.get("password") ?? "")
    if (!email || !password) {
      setView({ kind: "signedOut", error: "Enter your email and password." })
      return
    }

    setBusy(true)
    try {
      const result = await api.signIn(email, password)
      if (isMfaChallenge(result)) {
        setView({ kind: "mfa", challenge: result })
      } else {
        setView({ kind: "signedIn", session: result })
      }
    } catch (error) {
      setView({ kind: "signedOut", error: errorMessage(error) })
    } finally {
      setBusy(false)
    }
  }

  async function handleMfa(
    event: FormEvent<HTMLFormElement>,
    challenge: MfaChallenge,
  ) {
    event.preventDefault()
    const form = new FormData(event.currentTarget)
    const code = String(form.get("code") ?? "").trim()
    if (!code) {
      setView({ kind: "mfa", challenge, error: "Enter the 6-digit code." })
      return
    }

    setBusy(true)
    try {
      const session = await api.verifyMfa(challenge.challengeToken, code)
      setView({ kind: "signedIn", session })
    } catch (error) {
      setView({ kind: "mfa", challenge, error: errorMessage(error) })
    } finally {
      setBusy(false)
    }
  }

  async function handleSignOut() {
    setBusy(true)
    try {
      await api.signOut()
    } finally {
      setBusy(false)
      setView({ kind: "signedOut" })
    }
  }

  return (
    <main className="auth-shell">
      <section className="auth-card" aria-labelledby="portal-title">
        <header className="brand">
          <span className="brand-mark" aria-hidden="true">
            H
          </span>
          <div>
            <p className="brand-name">Hivorr</p>
            <p className="brand-portal">Control portal</p>
          </div>
          <span className="badge">Staging</span>
        </header>

        {view.kind === "loading" && (
          <p className="muted" role="status">
            Checking your session…
          </p>
        )}

        {view.kind === "signedOut" && (
          <form className="form" onSubmit={handleSignIn} noValidate>
            <div>
              <h1 id="portal-title">Sign in</h1>
              <p className="muted">
                Founder and authorised developer access. Two-factor
                authentication is required.
              </p>
            </div>

            {view.error && (
              <p className="error" role="alert" aria-live="polite">
                {view.error}
              </p>
            )}

            <label className="field">
              <span>Email</span>
              <input
                name="email"
                type="email"
                autoComplete="username"
                autoFocus
                required
                disabled={busy}
              />
            </label>

            <label className="field">
              <span>Password</span>
              <input
                name="password"
                type="password"
                autoComplete="current-password"
                required
                disabled={busy}
              />
            </label>

            <button className="button" type="submit" disabled={busy}>
              {busy ? "Signing in…" : "Continue"}
            </button>
          </form>
        )}

        {view.kind === "mfa" && (
          <form
            className="form"
            onSubmit={(event) => handleMfa(event, view.challenge)}
            noValidate
          >
            <div>
              <h1 id="portal-title">Two-factor code</h1>
              <p className="muted">
                Enter the current code from your authenticator app.
              </p>
            </div>

            {view.error && (
              <p className="error" role="alert" aria-live="polite">
                {view.error}
              </p>
            )}

            <label className="field">
              <span>Authenticator code</span>
              <input
                name="code"
                inputMode="numeric"
                autoComplete="one-time-code"
                pattern="[0-9]*"
                maxLength={6}
                autoFocus
                required
                disabled={busy}
              />
            </label>

            <button className="button" type="submit" disabled={busy}>
              {busy ? "Verifying…" : "Verify"}
            </button>

            <button
              className="button button-quiet"
              type="button"
              onClick={() => setView({ kind: "signedOut" })}
              disabled={busy}
            >
              Use a different account
            </button>
          </form>
        )}

        {view.kind === "signedIn" && (
          <div className="form">
            <div>
              <h1 id="portal-title">Signed in</h1>
              <p className="muted">
                You are authenticated for the control portal.
              </p>
            </div>

            <dl className="details">
              <div>
                <dt>Email</dt>
                <dd>{view.session.email}</dd>
              </div>
              <div>
                <dt>Environment</dt>
                <dd>{view.session.environment}</dd>
              </div>
              <div>
                <dt>Session expires</dt>
                <dd>{formatTime(view.session.expiresAt)}</dd>
              </div>
              <div>
                <dt>Session id</dt>
                <dd className="mono">{view.session.sessionId}</dd>
              </div>
            </dl>

            <button
              className="button button-quiet"
              type="button"
              onClick={handleSignOut}
              disabled={busy}
            >
              {busy ? "Signing out…" : "Sign out"}
            </button>
          </div>
        )}
      </section>
    </main>
  )
}
