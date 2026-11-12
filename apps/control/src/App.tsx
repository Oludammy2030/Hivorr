import { useEffect, useState, type FormEvent } from "react"
import { NavLink, useLocation } from "react-router"

import {
  api,
  errorMessage,
  isMfaChallenge,
  type AuditEntry,
  type ControlAuthority,
  type Grant,
  type MfaChallenge,
  type Session,
  type UserSummary,
} from "./api"
import { NAV_GROUPS, canSee, isKnownPath, sectionFromPath } from "./routes"

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

const GRANT_SCOPES: Record<string, readonly string[]> = {
  admin: ["admin.audit.read", "admin.grant.read", "admin.grant.manage"],
  staff: ["staff.support.handle"],
  partner: ["partner.referral.read"],
  platform_engineering: ["platform.engineering"],
}

function formatTime(value: string): string {
  return new Date(value).toLocaleString(undefined, {
    dateStyle: "medium",
    timeStyle: "short",
  })
}

interface AuditActorView {
  readonly headline: string
  readonly detail: string | null
  readonly capability: string | null
}

const ROLE_LABELS: Record<string, string> = {
  founder: "Founder",
  governance_admin: "Governance Administrator",
  verification_officer: "Verification Officer",
  support_officer: "Support Officer",
  operations_officer: "Operations Officer",
  finance_officer: "Finance Officer",
  investigator: "Investigator",
  compliance_reviewer: "Compliance Reviewer",
  partner_manager: "Partner Manager",
  auditor: "Auditor",
  department_manager: "Department Manager",
}

function roleLabel(key: string): string {
  return ROLE_LABELS[key] ?? key.split("_").join(" ")
}

function scopeLabel(scopeType: string): string {
  return scopeType.charAt(0).toUpperCase() + scopeType.slice(1)
}

/**
 * A role is only half the answer: the same role held at platform scope and at
 * one department are different amounts of authority. Roles are grouped with the
 * scopes they were held at, and a platform assignment adds nothing because it is
 * the widest scope the role can carry.
 */
function describeRoles(entry: AuditEntry): string | null {
  if (entry.actorRoleScopes.length > 0) {
    const scopesByRole = new Map<string, Set<string>>()
    const order: string[] = []
    for (const held of entry.actorRoleScopes) {
      if (!scopesByRole.has(held.roleKey)) {
        scopesByRole.set(held.roleKey, new Set<string>())
        order.push(held.roleKey)
      }
      if (held.scopeType && held.scopeType !== "platform") {
        const scoped = held.scopeId
          ? `${scopeLabel(held.scopeType)} ${held.scopeId.slice(0, 8)}`
          : scopeLabel(held.scopeType)
        scopesByRole.get(held.roleKey)?.add(scoped)
      }
    }
    return order
      .map((roleKey) => {
        const scopes = scopesByRole.get(roleKey)
        return scopes && scopes.size > 0
          ? `${roleLabel(roleKey)} (${[...scopes].join(", ")})`
          : roleLabel(roleKey)
      })
      .join(", ")
  }
  if (entry.actorRoleKeys.length > 0) {
    return entry.actorRoleKeys.map(roleLabel).join(", ")
  }
  return null
}

/**
 * The actor is a person first and a role second. Rows written before the
 * snapshot existed carry no role or name, so they fall back to the actor type
 * rather than inventing an identity. The capability is shown because authority
 * can also come from a grant, where the actor holds no governance role.
 */
function formatActor(entry: AuditEntry): AuditActorView {
  const name = entry.actorDisplayName ?? entry.actorEmail ?? null
  const role = describeRoles(entry)
  const nameIsRole =
    name !== null &&
    role !== null &&
    role.toLowerCase().includes(name.toLowerCase())
  const headline =
    role && name && !nameIsRole
      ? `${role} — ${name}`
      : (role ?? name ?? entry.actorType)
  const detail =
    entry.actorEmail && entry.actorEmail !== entry.actorDisplayName
      ? entry.actorEmail
      : null
  return { headline, detail, capability: entry.capability ?? null }
}

function Brand() {
  return (
    <div className="brand">
      <span className="brand-mark" aria-hidden="true">
        <svg viewBox="0 0 24 24" width="17" height="17" fill="currentColor">
          <path d="M4 14a1 1 0 0 1-.78-1.63l9.9-10.2a.5.5 0 0 1 .86.46l-1.92 6.02A1 1 0 0 0 13 10h7a1 1 0 0 1 .78 1.63l-9.9 10.2a.5.5 0 0 1-.86-.46l1.92-6.02A1 1 0 0 0 11 14z" />
        </svg>
      </span>
      <div>
        <p className="brand-name">Hivorr</p>
        <p className="brand-portal">Control portal</p>
      </div>
    </div>
  )
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

  if (view.kind === "signedIn") {
    return (
      <Dashboard
        session={view.session}
        onSignOut={handleSignOut}
        signingOut={busy}
      />
    )
  }

  return (
    <main className="auth-shell">
      <section className="auth-card" aria-labelledby="portal-title">
        <header className="brand">
          <span className="brand-mark" aria-hidden="true">
            <svg viewBox="0 0 24 24" width="17" height="17" fill="currentColor">
              <path d="M4 14a1 1 0 0 1-.78-1.63l9.9-10.2a.5.5 0 0 1 .86.46l-1.92 6.02A1 1 0 0 0 13 10h7a1 1 0 0 1 .78 1.63l-9.9 10.2a.5.5 0 0 1-.86-.46l1.92-6.02A1 1 0 0 0 11 14z" />
            </svg>
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
      </section>
    </main>
  )
}

interface DashboardProps {
  session: Session
  onSignOut: () => void
  signingOut: boolean
}

function Dashboard({ session, onSignOut, signingOut }: DashboardProps) {
  const location = useLocation()
  const section = sectionFromPath(location.pathname)
  const knownPath = isKnownPath(location.pathname)
  const [own, setOwn] = useState<ControlAuthority | null>(null)
  const [grants, setGrants] = useState<readonly Grant[] | null>(null)
  const [audit, setAudit] = useState<readonly AuditEntry[] | null>(null)
  const [auditCursor, setAuditCursor] = useState<string | null>(null)
  const [error, setError] = useState<string | undefined>()
  const [busy, setBusy] = useState(false)
  const [grantType, setGrantType] = useState("staff")
  const [scope, setScope] = useState("staff.support.handle")
  const [users, setUsers] = useState<readonly UserSummary[] | null>(null)
  const [nextCursor, setNextCursor] = useState<string | null>(null)
  const [userSearch, setUserSearch] = useState("")
  const [userQuery, setUserQuery] = useState("")
  const [userStatus, setUserStatus] = useState("")
  const [selectedUser, setSelectedUser] = useState<UserSummary | null>(null)

  const capabilities = own?.capabilities ?? []
  const canReadUsers = capabilities.includes("admin.user.read")
  const canReadGrants =
    capabilities.includes("admin.grant.read") ||
    capabilities.includes("admin.grant.manage")
  const canReadAudit = capabilities.includes("admin.audit.read")

  useEffect(() => {
    let active = true
    api
      .authority()
      .then((value) => {
        if (active) setOwn(value)
      })
      .catch((value: unknown) => {
        if (active) setError(errorMessage(value))
      })
    return () => {
      active = false
    }
  }, [])

  useEffect(() => {
    if (section !== "grants" || grants !== null || !canReadGrants) return
    let active = true
    setBusy(true)
    api
      .listGrants()
      .then((value) => {
        if (active) setGrants(value)
      })
      .catch((value: unknown) => {
        if (active) setError(errorMessage(value))
      })
      .finally(() => {
        if (active) setBusy(false)
      })
    return () => {
      active = false
    }
  }, [section, grants, canReadGrants])

  useEffect(() => {
    if (section !== "users" || !canReadUsers) return
    let active = true
    setBusy(true)
    api
      .listUsers(userQuery, userStatus)
      .then((value) => {
        if (!active) return
        setUsers(value.items)
        setNextCursor(value.nextCursor)
        setError(undefined)
      })
      .catch((value: unknown) => {
        if (active) setError(errorMessage(value))
      })
      .finally(() => {
        if (active) setBusy(false)
      })
    return () => {
      active = false
    }
  }, [section, userQuery, userStatus, canReadUsers])

  useEffect(() => {
    if (section !== "audit" || audit !== null || !canReadAudit) return
    let active = true
    setBusy(true)
    api
      .listAudit()
      .then((value) => {
        if (!active) return
        setAudit(value.items)
        setAuditCursor(value.nextCursor)
      })
      .catch((value: unknown) => {
        if (active) setError(errorMessage(value))
      })
      .finally(() => {
        if (active) setBusy(false)
      })
    return () => {
      active = false
    }
  }, [section, audit, canReadAudit])

  async function handleCreateGrant(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    const form = new FormData(event.currentTarget)
    const email = String(form.get("email") ?? "").trim()
    const grantType = String(form.get("grantType") ?? "staff")
    const scope = String(form.get("scope") ?? "")
    const reason = String(form.get("reason") ?? "").trim()
    if (!email || !scope || reason.length < 3) {
      setError("An email, a scope and a reason are required.")
      return
    }

    setBusy(true)
    setError(undefined)
    try {
      const created = await api.createGrant({
        email,
        grantType,
        scope,
        reason,
      })
      setGrants((current) => [created, ...(current ?? [])])
      event.currentTarget.reset()
    } catch (value) {
      setError(errorMessage(value))
    } finally {
      setBusy(false)
    }
  }

  async function handleRevoke(grant: Grant) {
    const reason = window.prompt(
      `Reason for revoking ${grant.scope} from ${grant.email ?? "this user"}:`,
    )
    if (!reason || reason.trim().length < 3) return
    setBusy(true)
    setError(undefined)
    try {
      const revoked = await api.revokeGrant(grant.id, reason.trim())
      setGrants((current) =>
        (current ?? []).map((entry) =>
          entry.id === revoked.id ? revoked : entry,
        ),
      )
    } catch (value) {
      setError(errorMessage(value))
    } finally {
      setBusy(false)
    }
  }

  const visibleGroups = NAV_GROUPS.map((group) => ({
    label: group.label,
    items: group.items.filter((item) => canSee(item, capabilities)),
  })).filter((group) => group.items.length > 0)
  const allNav = NAV_GROUPS.flatMap((group) => group.items)

  function handleUserSearch(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    setSelectedUser(null)
    setNextCursor(null)
    setUserQuery(userSearch)
  }

  async function handleLoadMore() {
    if (!nextCursor) return
    setBusy(true)
    setError(undefined)
    try {
      const value = await api.listUsers(userQuery, userStatus, nextCursor)
      setUsers((current) => [...(current ?? []), ...value.items])
      setNextCursor(value.nextCursor)
    } catch (value) {
      setError(errorMessage(value))
    } finally {
      setBusy(false)
    }
  }

  async function handleLoadMoreAudit() {
    if (!auditCursor) return
    setBusy(true)
    setError(undefined)
    try {
      const value = await api.listAudit(auditCursor)
      setAudit((current) => [...(current ?? []), ...value.items])
      setAuditCursor(value.nextCursor)
    } catch (value) {
      setError(errorMessage(value))
    } finally {
      setBusy(false)
    }
  }

  function statusClass(status: string): string {
    if (status === "active") return "chip chip-ok"
    if (status === "suspended" || status === "closed") return "chip chip-danger"
    return "chip"
  }

  return (
    <div className="app-shell">
      <aside className="app-sidebar">
        <Brand />
        <nav className="app-nav">
          {visibleGroups.map((group) => (
            <div key={group.label} className="nav-group">
              <p className="nav-label">{group.label}</p>
              {group.items.map((item) => (
                <NavLink
                  key={item.id}
                  to={item.path}
                  end
                  className={({ isActive }) =>
                    `nav-item${isActive ? " is-active" : ""}`
                  }
                >
                  {item.label}
                </NavLink>
              ))}
            </div>
          ))}
        </nav>
        <div className="app-sidebar-footer">
          <p className="muted">{session.email}</p>
          <button
            type="button"
            className="button button-quiet"
            onClick={onSignOut}
            disabled={signingOut}
          >
            {signingOut ? "Signing out…" : "Sign out"}
          </button>
        </div>
      </aside>

      <main className="app-main">
        <header className="app-topbar">
          <div>
            <p className="eyebrow">Control portal</p>
            <h1>
              {knownPath
                ? (allNav.find((item) => item.id === section)?.label ??
                  "Overview")
                : "Not found"}
            </h1>
          </div>
          <span className="badge">{session.environment}</span>
        </header>

        {error && (
          <p className="error" role="alert">
            {error}
          </p>
        )}

        {!knownPath && (
          <section className="panel">
            <h2>Page not found</h2>
            <p className="muted">
              This control-portal route does not exist. Use the navigation to
              return to an authorised area.
            </p>
          </section>
        )}

        {knownPath && section === "overview" && (
          <div className="dash-grid">
            <section className="panel">
              <h2>Session</h2>
              <dl className="details">
                <div>
                  <dt>Email</dt>
                  <dd>{session.email}</dd>
                </div>
                <div>
                  <dt>Environment</dt>
                  <dd>{session.environment}</dd>
                </div>
                <div>
                  <dt>Expires</dt>
                  <dd>{formatTime(session.expiresAt)}</dd>
                </div>
                <div>
                  <dt>Idle expires</dt>
                  <dd>{formatTime(session.idleExpiresAt)}</dd>
                </div>
              </dl>
            </section>

            <section className="panel">
              <h2>Capabilities</h2>
              {own === null && <p className="muted">Loading…</p>}
              {own && own.capabilities.length === 0 && (
                <p className="muted">
                  No capabilities yet. The first administrator grant must be
                  bootstrapped out of band.
                </p>
              )}
              {own && own.capabilities.length > 0 && (
                <ul className="chip-list">
                  {own.capabilities.map((capability) => (
                    <li key={capability} className="chip">
                      {capability}
                    </li>
                  ))}
                </ul>
              )}
            </section>

            <section className="panel">
              <h2>Your grants</h2>
              {own === null && <p className="muted">Loading…</p>}
              {own && own.grants.length === 0 && (
                <p className="muted">No active grants.</p>
              )}
              {own && own.grants.length > 0 && (
                <ul className="plain-list">
                  {own.grants.map((grant) => (
                    <li key={grant.id}>
                      <span className="chip">{grant.grantType}</span>{" "}
                      <span className="mono">{grant.scope}</span>
                    </li>
                  ))}
                </ul>
              )}
            </section>
          </div>
        )}

        {knownPath && section === "users" && !canReadUsers && (
          <section className="panel">
            <h2>Users</h2>
            <p className="muted">
              Your governance role does not include user directory access.
            </p>
          </section>
        )}

        {knownPath && section === "users" && canReadUsers && (
          <div className="dash-stack">
            <section className="panel">
              <form className="user-toolbar" onSubmit={handleUserSearch}>
                <input
                  className="search-input"
                  type="search"
                  placeholder="Search by email or name"
                  value={userSearch}
                  onChange={(event) => setUserSearch(event.target.value)}
                  aria-label="Search users"
                />
                <select
                  className="filter-select"
                  value={userStatus}
                  onChange={(event) => {
                    setSelectedUser(null)
                    setNextCursor(null)
                    setUserStatus(event.target.value)
                  }}
                  aria-label="Filter by status"
                >
                  <option value="">All statuses</option>
                  <option value="active">Active</option>
                  <option value="suspended">Suspended</option>
                  <option value="closed">Closed</option>
                </select>
                <button
                  className="button button-small"
                  type="submit"
                  disabled={busy}
                >
                  Search
                </button>
              </form>
            </section>

            <section className="panel">
              <div className="panel-head">
                <h2>Users</h2>
                <span className="muted">
                  {users === null ? "Loading…" : `${users.length} shown`}
                </span>
              </div>

              {users && users.length === 0 && (
                <p className="muted">
                  No users match this search. Clear the filters or create an
                  account through onboarding.
                </p>
              )}

              {users && users.length > 0 && (
                <div className="table-wrap">
                  <table className="table">
                    <thead>
                      <tr>
                        <th>Email</th>
                        <th>Name</th>
                        <th>Status</th>
                        <th>Authenticator</th>
                        <th>Created</th>
                      </tr>
                    </thead>
                    <tbody>
                      {users.map((user) => (
                        <tr
                          key={user.id}
                          className={
                            selectedUser?.id === user.id ? "is-selected" : ""
                          }
                          onClick={() => setSelectedUser(user)}
                        >
                          <td>{user.email}</td>
                          <td>{user.displayName ?? "—"}</td>
                          <td>
                            <span className={statusClass(user.status)}>
                              {user.status}
                            </span>
                          </td>
                          <td>
                            {user.confirmedFactors > 0 ? "Enabled" : "Not set"}
                          </td>
                          <td>{formatTime(user.createdAt)}</td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              )}

              {nextCursor && (
                <button
                  type="button"
                  className="button button-quiet button-small"
                  onClick={handleLoadMore}
                  disabled={busy}
                >
                  {busy ? "Loading…" : "Load more"}
                </button>
              )}
            </section>

            {selectedUser && (
              <section className="panel">
                <div className="panel-head">
                  <h2>{selectedUser.email}</h2>
                  <button
                    type="button"
                    className="button button-quiet button-small"
                    onClick={() => setSelectedUser(null)}
                  >
                    Close
                  </button>
                </div>
                <dl className="details">
                  <div>
                    <dt>Name</dt>
                    <dd>{selectedUser.displayName ?? "—"}</dd>
                  </div>
                  <div>
                    <dt>Status</dt>
                    <dd>{selectedUser.status}</dd>
                  </div>
                  <div>
                    <dt>Email verified</dt>
                    <dd>{selectedUser.emailVerified ? "Yes" : "No"}</dd>
                  </div>
                  <div>
                    <dt>Authenticator</dt>
                    <dd>
                      {selectedUser.confirmedFactors > 0
                        ? `${selectedUser.confirmedFactors} confirmed`
                        : "Not enrolled"}
                    </dd>
                  </div>
                  <div>
                    <dt>Created</dt>
                    <dd>{formatTime(selectedUser.createdAt)}</dd>
                  </div>
                  <div>
                    <dt>User id</dt>
                    <dd className="mono">{selectedUser.id}</dd>
                  </div>
                  <div>
                    <dt>Account id</dt>
                    <dd className="mono">{selectedUser.accountId}</dd>
                  </div>
                </dl>
                <p className="hint">
                  Account actions — suspend, reinstate, revoke sessions — are
                  the next control slice. This view is read-only.
                </p>
              </section>
            )}
          </div>
        )}

        {knownPath && section === "grants" && !canReadGrants && (
          <section className="panel">
            <h2>Grants</h2>
            <p className="muted">
              Your governance role does not include grant administration.
            </p>
          </section>
        )}

        {knownPath && section === "grants" && canReadGrants && (
          <div className="dash-stack">
            <section className="panel">
              <h2>Create a grant</h2>
              <form className="form" onSubmit={handleCreateGrant}>
                <div className="form-row">
                  <label className="field">
                    <span>User email</span>
                    <input name="email" type="email" required disabled={busy} />
                  </label>
                  <label className="field">
                    <span>Grant type</span>
                    <select
                      name="grantType"
                      value={grantType}
                      onChange={(event) => {
                        const next = event.target.value
                        setGrantType(next)
                        setScope(GRANT_SCOPES[next][0])
                      }}
                      disabled={busy}
                    >
                      {Object.keys(GRANT_SCOPES).map((type) => (
                        <option key={type} value={type}>
                          {type}
                        </option>
                      ))}
                    </select>
                  </label>
                  <label className="field">
                    <span>Scope</span>
                    <select
                      name="scope"
                      value={scope}
                      onChange={(event) => setScope(event.target.value)}
                      disabled={busy}
                    >
                      {(GRANT_SCOPES[grantType] ?? []).map((value) => (
                        <option key={value} value={value}>
                          {value}
                        </option>
                      ))}
                    </select>
                  </label>
                </div>
                <label className="field">
                  <span>Reason</span>
                  <input
                    name="reason"
                    type="text"
                    minLength={3}
                    maxLength={500}
                    required
                    disabled={busy}
                  />
                </label>
                <button className="button" type="submit" disabled={busy}>
                  {busy ? "Working…" : "Create grant"}
                </button>
              </form>
            </section>

            <section className="panel">
              <h2>Grants</h2>
              {grants === null && <p className="muted">Loading…</p>}
              {grants && grants.length === 0 && (
                <p className="muted">No grants in this environment.</p>
              )}
              {grants && grants.length > 0 && (
                <div className="table-wrap">
                  <table className="table">
                    <thead>
                      <tr>
                        <th>Email</th>
                        <th>Type</th>
                        <th>Scope</th>
                        <th>Status</th>
                        <th />
                      </tr>
                    </thead>
                    <tbody>
                      {grants.map((grant) => (
                        <tr key={grant.id}>
                          <td>{grant.email ?? grant.userId}</td>
                          <td>{grant.grantType}</td>
                          <td className="mono">{grant.scope}</td>
                          <td>
                            {grant.revokedAt ? (
                              <span className="chip chip-danger">revoked</span>
                            ) : (
                              <span className="chip chip-ok">active</span>
                            )}
                          </td>
                          <td>
                            {!grant.revokedAt && (
                              <button
                                type="button"
                                className="button button-quiet button-small"
                                onClick={() => handleRevoke(grant)}
                                disabled={busy}
                              >
                                Revoke
                              </button>
                            )}
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              )}
            </section>
          </div>
        )}

        {knownPath && section === "audit" && !canReadAudit && (
          <section className="panel">
            <h2>Audit log</h2>
            <p className="muted">
              Your governance role does not include audit access.
            </p>
          </section>
        )}

        {knownPath && section === "audit" && canReadAudit && (
          <section className="panel">
            <h2>Audit log</h2>
            {audit === null && <p className="muted">Loading…</p>}
            {audit && audit.length === 0 && (
              <p className="muted">No audit entries.</p>
            )}
            {audit && audit.length > 0 && (
              <div className="table-wrap">
                <table className="table">
                  <thead>
                    <tr>
                      <th>Time</th>
                      <th>Action</th>
                      <th>Actor</th>
                      <th>Target</th>
                      <th>Reason</th>
                    </tr>
                  </thead>
                  <tbody>
                    {audit.map((entry) => {
                      const actor = formatActor(entry)
                      return (
                        <tr key={entry.id}>
                          <td>{formatTime(entry.occurredAt)}</td>
                          <td className="mono">{entry.action}</td>
                          <td>
                            <div>{actor.headline}</div>
                            {actor.detail && (
                              <div className="muted">{actor.detail}</div>
                            )}
                            {actor.capability && (
                              <div className="muted mono">
                                {actor.capability}
                              </div>
                            )}
                          </td>
                          <td className="mono">
                            {entry.targetType ?? "—"}
                            {entry.targetId
                              ? `:${entry.targetId.slice(0, 8)}`
                              : ""}
                          </td>
                          <td>{entry.reason ?? "Not required"}</td>
                        </tr>
                      )
                    })}
                  </tbody>
                </table>
              </div>
            )}

            {auditCursor && (
              <button
                type="button"
                className="button button-quiet button-small"
                onClick={handleLoadMoreAudit}
                disabled={busy}
              >
                {busy ? "Loading…" : "Load more"}
              </button>
            )}
          </section>
        )}
      </main>
    </div>
  )
}
