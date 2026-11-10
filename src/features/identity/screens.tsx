import {
  useEffect,
  useRef,
  useState,
  type FormEvent,
  type ReactNode,
} from "react"
import { Link, Navigate, useNavigate, useSearchParams } from "react-router"
import { Zap } from "lucide-react"

import { ApiClientError } from "@hivorr/api-client"
import {
  Button,
  TextField,
  colorTokens,
  fontTokens,
  gradientTokens,
} from "@hivorr/design"

import { apiClient } from "./client"
import { useSession } from "@hivorr/app-shell"

const onBrand = {
  strong: "rgba(255,255,255,0.88)",
  body: "rgba(255,255,255,0.65)",
  soft: "rgba(255,255,255,0.6)",
  chip: "rgba(255,255,255,0.2)",
}

function messageFor(error: unknown): string {
  if (error instanceof ApiClientError) {
    if (error.status === 429) return "Too many attempts. Try again later."
    if (error.status === 401) return "The email or password is incorrect."
    if (error.code === "VALIDATION_FAILED") return error.message
    return error.message
  }
  return "Something went wrong. Try again."
}

function AuthPage({ children }: { children: ReactNode }) {
  return (
    <div
      style={{
        minHeight: "100vh",
        background: gradientTokens.auth,
        display: "flex",
        alignItems: "center",
        justifyContent: "center",
        padding: 24,
      }}
    >
      {children}
    </div>
  )
}

function BrandMark({ tone = "ink" }: { tone?: "ink" | "brand" }) {
  const background = tone === "brand" ? onBrand.chip : colorTokens.brand
  return (
    <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
      <div
        style={{
          width: 36,
          height: 36,
          background,
          borderRadius: 10,
          display: "flex",
          alignItems: "center",
          justifyContent: "center",
        }}
      >
        <Zap size={20} color={colorTokens.surface} fill={colorTokens.surface} />
      </div>
      <span
        style={{
          fontFamily: fontTokens.display,
          fontWeight: 800,
          fontSize: 18,
          color: tone === "brand" ? colorTokens.surface : colorTokens.ink,
        }}
      >
        Hivorr
      </span>
    </div>
  )
}

function ErrorText({ children }: { children: string }) {
  return (
    <p
      role="alert"
      style={{ color: colorTokens.danger, fontSize: 13, fontWeight: 600 }}
    >
      {children}
    </p>
  )
}

const cardShadow = "0 32px 80px rgba(0,0,0,0.2)"

export function SignInScreen() {
  const navigate = useNavigate()
  const session = useSession()
  const [email, setEmail] = useState("")
  const [password, setPassword] = useState("")
  const [code, setCode] = useState("")
  const [challenge, setChallenge] = useState<string | null>(null)
  const [error, setError] = useState<string | null>(null)
  const [busy, setBusy] = useState(false)

  async function submit(event: FormEvent) {
    event.preventDefault()
    setError(null)
    setBusy(true)
    try {
      const result = await apiClient.signIn({ email, password })
      if ("mfaRequired" in result) {
        setChallenge(result.challengeToken)
      } else {
        session.refresh()
        navigate("/activities", { replace: true })
      }
    } catch (caught) {
      setError(messageFor(caught))
    } finally {
      setBusy(false)
    }
  }

  async function verify(event: FormEvent) {
    event.preventDefault()
    if (!challenge) return
    setError(null)
    setBusy(true)
    try {
      await apiClient.verifyMfa({ challengeToken: challenge, code })
      session.refresh()
      navigate("/activities", { replace: true })
    } catch (caught) {
      setError(messageFor(caught))
    } finally {
      setBusy(false)
    }
  }

  return (
    <AuthPage>
      <div
        style={{
          width: "100%",
          maxWidth: 940,
          background: colorTokens.surface,
          borderRadius: 28,
          boxShadow: cardShadow,
          overflow: "hidden",
        }}
      >
        <div
          style={{
            display: "grid",
            gridTemplateColumns: "repeat(auto-fit,minmax(280px,1fr))",
            minHeight: 500,
          }}
        >
          <div
            style={{
              background: `linear-gradient(135deg, var(--hivorr-deep-blue), var(--hivorr-blue))`,
              padding: 48,
              display: "flex",
              flexDirection: "column",
              justifyContent: "space-between",
            }}
          >
            <BrandMark tone="brand" />
            <div>
              <h2
                style={{
                  fontFamily: fontTokens.display,
                  fontWeight: 800,
                  fontSize: 28,
                  color: colorTokens.surface,
                  lineHeight: 1.3,
                  letterSpacing: -0.5,
                }}
              >
                Africa's #1 Workforce Marketplace
              </h2>
              <p
                style={{
                  color: onBrand.body,
                  fontSize: 15,
                  marginTop: 12,
                  lineHeight: 1.6,
                }}
              >
                Join 50,000+ professionals and employers building Africa's
                future together.
              </p>
            </div>
            <div style={{ display: "flex", gap: 24 }}>
              {[
                ["52K+", "Professionals"],
                ["1.2K", "Companies"],
                ["$12M+", "Earned"],
              ].map(([value, label]) => (
                <div key={label}>
                  <p
                    style={{
                      fontFamily: fontTokens.display,
                      fontWeight: 800,
                      fontSize: 20,
                      color: colorTokens.surface,
                    }}
                  >
                    {value}
                  </p>
                  <p style={{ fontSize: 12, color: onBrand.soft }}>{label}</p>
                </div>
              ))}
            </div>
          </div>

          <div
            style={{
              padding: 48,
              display: "flex",
              flexDirection: "column",
              justifyContent: "center",
              gap: 20,
            }}
          >
            <div>
              <h1
                style={{
                  fontFamily: fontTokens.display,
                  fontWeight: 800,
                  fontSize: 26,
                  color: colorTokens.ink,
                  letterSpacing: -0.5,
                }}
              >
                {challenge ? "Verify your sign-in" : "Welcome back 👋"}
              </h1>
              <p
                style={{ color: colorTokens.gray, fontSize: 15, marginTop: 4 }}
              >
                {challenge
                  ? "Enter the six-digit code from your authenticator."
                  : "Sign in to your account"}
              </p>
            </div>

            {challenge ? (
              <form
                onSubmit={verify}
                style={{ display: "flex", flexDirection: "column", gap: 12 }}
              >
                <TextField
                  label="Authentication code"
                  inputMode="numeric"
                  autoComplete="one-time-code"
                  maxLength={6}
                  value={code}
                  onChange={(event) => setCode(event.target.value)}
                />
                {error ? <ErrorText>{error}</ErrorText> : null}
                <Button size="lg" type="submit" disabled={busy}>
                  {busy ? "Verifying…" : "Verify"}
                </Button>
                <button
                  type="button"
                  onClick={() => {
                    setChallenge(null)
                    setCode("")
                    setError(null)
                  }}
                  style={{
                    color: colorTokens.gray,
                    fontSize: 14,
                    padding: 10,
                  }}
                >
                  Back to sign in
                </button>
              </form>
            ) : (
              <form
                onSubmit={submit}
                style={{ display: "flex", flexDirection: "column", gap: 12 }}
              >
                <TextField
                  label="Email"
                  type="email"
                  autoComplete="email"
                  placeholder="you@example.com"
                  value={email}
                  onChange={(event) => setEmail(event.target.value)}
                />
                <TextField
                  label="Password"
                  type="password"
                  autoComplete="current-password"
                  placeholder="••••••••"
                  value={password}
                  onChange={(event) => setPassword(event.target.value)}
                />
                <div style={{ textAlign: "right" }}>
                  <Link
                    to="/forgot-password"
                    style={{
                      color: colorTokens.brand,
                      fontWeight: 600,
                      fontSize: 13,
                    }}
                  >
                    Forgot password?
                  </Link>
                </div>
                {error ? <ErrorText>{error}</ErrorText> : null}
                <Button size="lg" type="submit" disabled={busy}>
                  {busy ? "Signing in…" : "Sign In"}
                </Button>
              </form>
            )}

            <p
              style={{
                textAlign: "center",
                fontSize: 14,
                color: colorTokens.gray,
              }}
            >
              New to Hivorr?{" "}
              <Link
                to="/signup"
                style={{ color: colorTokens.brand, fontWeight: 700 }}
              >
                Create account
              </Link>
            </p>
          </div>
        </div>
      </div>
    </AuthPage>
  )
}

export function RegisterScreen() {
  const [name, setName] = useState("")
  const [email, setEmail] = useState("")
  const [password, setPassword] = useState("")
  const [error, setError] = useState<string | null>(null)
  const [done, setDone] = useState(false)
  const [busy, setBusy] = useState(false)

  async function submit(event: FormEvent) {
    event.preventDefault()
    setError(null)
    setBusy(true)
    try {
      await apiClient.register({
        email,
        password,
        ...(name.trim() ? { displayName: name.trim() } : {}),
      })
      setDone(true)
    } catch (caught) {
      setError(messageFor(caught))
    } finally {
      setBusy(false)
    }
  }

  return (
    <AuthPage>
      <div
        style={{
          width: "100%",
          maxWidth: 480,
          background: colorTokens.surface,
          borderRadius: 28,
          padding: 40,
          boxShadow: cardShadow,
        }}
      >
        <div style={{ marginBottom: 28 }}>
          <BrandMark tone="brand" />
        </div>
        <h1
          style={{
            fontFamily: fontTokens.display,
            fontWeight: 800,
            fontSize: 26,
            color: colorTokens.ink,
            letterSpacing: -0.5,
            marginBottom: 4,
          }}
        >
          Create account
        </h1>
        <p
          style={{
            color: colorTokens.gray,
            fontSize: 15,
            marginBottom: 24,
          }}
        >
          Join Africa's workforce marketplace
        </p>

        {done ? (
          <div style={{ display: "flex", flexDirection: "column", gap: 16 }}>
            <p style={{ color: colorTokens.body, fontSize: 15 }}>
              Your account was created. Sign in to continue.
            </p>
            <Link
              to="/login"
              style={{
                color: colorTokens.brand,
                fontFamily: fontTokens.display,
                fontWeight: 700,
                fontSize: 15,
              }}
            >
              Go to sign in
            </Link>
          </div>
        ) : (
          <form
            onSubmit={submit}
            style={{ display: "flex", flexDirection: "column", gap: 12 }}
          >
            <TextField
              label="Full name"
              autoComplete="name"
              placeholder="Amara Diallo"
              value={name}
              onChange={(event) => setName(event.target.value)}
            />
            <TextField
              label="Email"
              type="email"
              autoComplete="email"
              placeholder="you@example.com"
              value={email}
              onChange={(event) => setEmail(event.target.value)}
            />
            <TextField
              label="Password"
              type="password"
              autoComplete="new-password"
              placeholder="At least 12 characters"
              value={password}
              onChange={(event) => setPassword(event.target.value)}
            />
            <div style={{ marginTop: 8 }}>
              {error ? <ErrorText>{error}</ErrorText> : null}
              <Button size="lg" type="submit" disabled={busy}>
                {busy ? "Creating account…" : "Create account"}
              </Button>
            </div>
          </form>
        )}

        <p
          style={{
            textAlign: "center",
            fontSize: 13,
            color: colorTokens.gray,
            marginTop: 16,
          }}
        >
          Already have an account?{" "}
          <Link
            to="/login"
            style={{ color: colorTokens.brand, fontWeight: 700 }}
          >
            Sign in
          </Link>
        </p>
      </div>
    </AuthPage>
  )
}

export function ForgotPasswordScreen() {
  const [email, setEmail] = useState("")
  const [sent, setSent] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [busy, setBusy] = useState(false)

  async function submit(event: FormEvent) {
    event.preventDefault()
    setError(null)
    setBusy(true)
    try {
      await apiClient.requestPasswordReset({ email })
      setSent(true)
    } catch (caught) {
      setError(messageFor(caught))
    } finally {
      setBusy(false)
    }
  }

  return (
    <AuthPage>
      <div
        style={{
          width: "100%",
          maxWidth: 460,
          background: colorTokens.surface,
          borderRadius: 28,
          padding: 40,
          boxShadow: cardShadow,
        }}
      >
        <div style={{ marginBottom: 24 }}>
          <BrandMark tone="brand" />
        </div>
        <h1
          style={{
            fontFamily: fontTokens.display,
            fontWeight: 800,
            fontSize: 24,
            color: colorTokens.ink,
          }}
        >
          Reset your password
        </h1>
        <p
          style={{
            color: colorTokens.gray,
            fontSize: 15,
            margin: "8px 0 20px",
            lineHeight: 1.6,
          }}
        >
          We will email a reset link if the address belongs to an account.
        </p>
        {sent ? (
          <p role="status" style={{ color: colorTokens.body, fontSize: 15 }}>
            Check your email for the reset link.
          </p>
        ) : (
          <form
            onSubmit={submit}
            style={{ display: "flex", flexDirection: "column", gap: 12 }}
          >
            <TextField
              label="Email"
              type="email"
              autoComplete="email"
              placeholder="you@example.com"
              value={email}
              onChange={(event) => setEmail(event.target.value)}
            />
            {error ? <ErrorText>{error}</ErrorText> : null}
            <Button size="lg" type="submit" disabled={busy}>
              {busy ? "Sending…" : "Send reset link"}
            </Button>
          </form>
        )}
        <p
          style={{
            textAlign: "center",
            fontSize: 13,
            color: colorTokens.gray,
            marginTop: 16,
          }}
        >
          <Link
            to="/login"
            style={{ color: colorTokens.brand, fontWeight: 700 }}
          >
            Back to sign in
          </Link>
        </p>
      </div>
    </AuthPage>
  )
}

function tokenFromSearch(params: URLSearchParams): string {
  return params.get("token")?.trim() ?? ""
}

export function ResetPasswordScreen() {
  const [params] = useSearchParams()
  const [token] = useState(() => tokenFromSearch(params))
  const [password, setPassword] = useState("")
  const [confirm, setConfirm] = useState("")
  const [error, setError] = useState<string | null>(null)
  const [done, setDone] = useState(false)
  const [busy, setBusy] = useState(false)

  async function submit(event: FormEvent) {
    event.preventDefault()
    if (password !== confirm) {
      setError("The passwords do not match.")
      return
    }
    setError(null)
    setBusy(true)
    try {
      await apiClient.completePasswordReset({ token, password })
      setDone(true)
    } catch (caught) {
      setError(messageFor(caught))
    } finally {
      setBusy(false)
    }
  }

  return (
    <AuthPage>
      <div
        style={{
          width: "100%",
          maxWidth: 460,
          background: colorTokens.surface,
          borderRadius: 28,
          padding: 40,
          boxShadow: cardShadow,
        }}
      >
        <div style={{ marginBottom: 24 }}>
          <BrandMark tone="brand" />
        </div>
        <h1
          style={{
            fontFamily: fontTokens.display,
            fontWeight: 800,
            fontSize: 24,
            color: colorTokens.ink,
          }}
        >
          Choose a new password
        </h1>
        {!token ? (
          <p role="alert" style={{ color: colorTokens.danger, marginTop: 12 }}>
            This reset link is missing its token. Request a new link.
          </p>
        ) : done ? (
          <p role="status" style={{ color: colorTokens.body, marginTop: 12 }}>
            Your password was changed.{" "}
            <Link
              to="/login"
              style={{ color: colorTokens.brand, fontWeight: 700 }}
            >
              Sign in
            </Link>
          </p>
        ) : (
          <form
            onSubmit={submit}
            style={{
              display: "flex",
              flexDirection: "column",
              gap: 12,
              marginTop: 16,
            }}
          >
            <TextField
              label="New password"
              type="password"
              autoComplete="new-password"
              value={password}
              onChange={(event) => setPassword(event.target.value)}
            />
            <TextField
              label="Confirm password"
              type="password"
              autoComplete="new-password"
              value={confirm}
              onChange={(event) => setConfirm(event.target.value)}
            />
            {error ? <ErrorText>{error}</ErrorText> : null}
            <Button size="lg" type="submit" disabled={busy}>
              {busy ? "Saving…" : "Save password"}
            </Button>
          </form>
        )}
      </div>
    </AuthPage>
  )
}

export function VerifyEmailScreen() {
  const [params] = useSearchParams()
  const [token] = useState(() => tokenFromSearch(params))
  const [status, setStatus] = useState<"idle" | "busy" | "done" | "error">(
    token ? "idle" : "error",
  )
  const [error, setError] = useState<string | null>(
    token ? null : "This verification link is missing its token.",
  )
  const started = useRef(false)

  useEffect(() => {
    if (!token || started.current) return
    started.current = true
    setStatus("busy")
    apiClient
      .completeEmailVerification({ token })
      .then(() => setStatus("done"))
      .catch((caught) => {
        setError(messageFor(caught))
        setStatus("error")
      })
  }, [token])

  return (
    <AuthPage>
      <div
        style={{
          width: "100%",
          maxWidth: 460,
          background: colorTokens.surface,
          borderRadius: 28,
          padding: 40,
          textAlign: "center",
          boxShadow: cardShadow,
        }}
      >
        <h1
          style={{
            fontFamily: fontTokens.display,
            fontWeight: 800,
            fontSize: 24,
            color: colorTokens.ink,
          }}
        >
          Verify your email
        </h1>
        <p
          role={status === "error" ? "alert" : "status"}
          style={{
            color: status === "error" ? colorTokens.danger : colorTokens.body,
            fontSize: 15,
            margin: "12px 0 20px",
            lineHeight: 1.6,
          }}
        >
          {status === "busy" || status === "idle"
            ? "Verifying your link…"
            : status === "done"
              ? "Your email is verified. You can sign in."
              : (error ?? "This link is invalid or has expired.")}
        </p>
        <Link
          to="/login"
          style={{ color: colorTokens.brand, fontWeight: 700, fontSize: 15 }}
        >
          Go to sign in
        </Link>
      </div>
    </AuthPage>
  )
}

export function SessionBootstrap() {
  const session = useSession()
  if (session.status === "loading") {
    return (
      <main
        style={{
          minHeight: "100vh",
          display: "grid",
          placeItems: "center",
          background: "var(--background)",
          color: colorTokens.gray,
          fontFamily: fontTokens.body,
        }}
      >
        <p role="status">Loading your session…</p>
      </main>
    )
  }
  if (session.status === "error") {
    return (
      <main
        style={{
          minHeight: "100vh",
          display: "grid",
          placeItems: "center",
          background: "var(--background)",
          padding: 24,
        }}
      >
        <div style={{ textAlign: "center", maxWidth: 420 }}>
          <p
            role="alert"
            style={{ color: colorTokens.danger, marginBottom: 12 }}
          >
            We could not load your session.
          </p>
          <Button onClick={session.refresh}>Try again</Button>
        </div>
      </main>
    )
  }
  return (
    <Navigate
      to={session.status === "authenticated" ? "/activities" : "/login"}
      replace
    />
  )
}
