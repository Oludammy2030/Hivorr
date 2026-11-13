import { useEffect, useRef, useState, type FormEvent } from "react"
import { Link, Navigate, NavLink, useLocation, useNavigate } from "react-router"
import { capabilityLabel, grantTypeLabel } from "@hivorr/shared"

import {
  api,
  errorMessage,
  isMfaChallenge,
  type AuditEntry,
  type ControlAuthority,
  type Department,
  type Grant,
  type MfaChallenge,
  type Role,
  type RoleAssignment,
  type RoleScopeTarget,
  type RoleScopeType,
  type AssignableStaff,
  type AccountNote,
  type AccountTimelineEntry,
  type ApprovalRequest,
  type PartnerOrganisation,
  type PartnerRepresentative,
  type CaseSummary,
  type CaseEvent,
  type CaseEvidence,
  type VerificationReview,
  type Session,
  type UserSummary,
} from "./api"
import {
  NAV_GROUPS,
  canSee,
  isKnownPath,
  sectionFromPath,
  sectionTitle,
} from "./routes"
import { StaffPage } from "./StaffPage"

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

type GrantStatus = "active" | "expired" | "revoked"

function grantStatusOf(grant: Grant): GrantStatus {
  if (grant.revokedAt) return "revoked"
  if (grant.expiresAt && new Date(grant.expiresAt).getTime() <= Date.now()) {
    return "expired"
  }
  return "active"
}

function grantStatusChip(status: GrantStatus): string {
  if (status === "active") return "chip chip-ok"
  if (status === "expired") return "chip"
  return "chip chip-danger"
}

type AssignmentStatus = "active" | "expired" | "revoked"

function assignmentStatusOf(assignment: RoleAssignment): AssignmentStatus {
  if (assignment.revokedAt) return "revoked"
  if (
    assignment.expiresAt &&
    new Date(assignment.expiresAt).getTime() <= Date.now()
  ) {
    return "expired"
  }
  return "active"
}

function assignmentStatusChip(status: AssignmentStatus): string {
  if (status === "active") return "chip chip-ok"
  if (status === "expired") return "chip"
  return "chip chip-danger"
}

function approvalStatusChip(status: string): string {
  if (status === "approved") return "chip chip-ok"
  if (status === "rejected") return "chip chip-danger"
  return "chip"
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
  const navigate = useNavigate()
  const mainRef = useRef<HTMLElement | null>(null)
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
  const [departments, setDepartments] = useState<readonly Department[] | null>(
    null,
  )
  const [grantDepartment, setGrantDepartment] = useState("")
  const [openDepartment, setOpenDepartment] = useState<string | null>(null)
  const [grantSearch, setGrantSearch] = useState("")
  const [grantStatusFilter, setGrantStatusFilter] = useState("all")
  const [roles, setRoles] = useState<readonly Role[] | null>(null)
  const [roleAssignments, setRoleAssignments] =
    useState<readonly RoleAssignment[] | null>(null)
  const [scopeTargets, setScopeTargets] = useState<{
    readonly department: readonly RoleScopeTarget[]
    readonly organisation: readonly RoleScopeTarget[]
  }>({ department: [], organisation: [] })
  const [assignableStaff, setAssignableStaff] =
    useState<readonly AssignableStaff[]>([])
  const [staffSearch, setStaffSearch] = useState("")
  const [assignStaffEmail, setAssignStaffEmail] = useState("")
  const [assignRoleKey, setAssignRoleKey] = useState("")
  const [assignScopeType, setAssignScopeType] =
    useState<RoleScopeType>("platform")
  const [assignScopeId, setAssignScopeId] = useState("")
  const [roleQuery, setRoleQuery] = useState("")
  const [roleStatusFilter, setRoleStatusFilter] = useState("active")
  const [roleFilterKey, setRoleFilterKey] = useState("")
  const [accessPerson, setAccessPerson] = useState("")
  const [users, setUsers] = useState<readonly UserSummary[] | null>(null)
  const [nextCursor, setNextCursor] = useState<string | null>(null)
  const [userSearch, setUserSearch] = useState("")
  const [userQuery, setUserQuery] = useState("")
  const [userStatus, setUserStatus] = useState("")
  const [selectedUser, setSelectedUser] = useState<UserSummary | null>(null)
  const [userNotes, setUserNotes] = useState<readonly AccountNote[]>([])
  const [userTimeline, setUserTimeline] =
    useState<readonly AccountTimelineEntry[]>([])
  const [approvals, setApprovals] = useState<readonly ApprovalRequest[] | null>(
    null,
  )
  const [partners, setPartners] =
    useState<readonly PartnerOrganisation[] | null>(null)
  const [selectedPartner, setSelectedPartner] =
    useState<PartnerOrganisation | null>(null)
  const [partnerReps, setPartnerReps] =
    useState<readonly PartnerRepresentative[]>([])
  const [cases, setCases] = useState<readonly CaseSummary[] | null>(null)
  const [caseStatusFilter, setCaseStatusFilter] = useState("")
  const [caseTypeFilter, setCaseTypeFilter] = useState("")
  const [caseQuery, setCaseQuery] = useState("")
  const [selectedCase, setSelectedCase] = useState<CaseSummary | null>(null)
  const [caseEvents, setCaseEvents] = useState<readonly CaseEvent[]>([])
  const [caseEvidence, setCaseEvidence] = useState<readonly CaseEvidence[]>([])
  const [verification, setVerification] =
    useState<readonly VerificationReview[] | null>(null)
  const [verificationStatus, setVerificationStatus] = useState("")

  const capabilities = own?.capabilities ?? []
  const canReadUsers = capabilities.includes("admin.user.read")
  const canManageUsers = capabilities.includes("admin.user.manage")
  const canReadApprovals =
    capabilities.includes("admin.approval.read") ||
    capabilities.includes("admin.approval.decide")
  const canDecideApprovals = capabilities.includes("admin.approval.decide")
  const canReadPartners =
    capabilities.includes("admin.partner.read") ||
    capabilities.includes("admin.partner.manage")
  const canManagePartners = capabilities.includes("admin.partner.manage")
  const canReadCases =
    capabilities.includes("admin.case.read") ||
    capabilities.includes("admin.case.assign")
  const canWorkCases = capabilities.includes("admin.case.assign")
  const canReviewVerification = capabilities.includes(
    "admin.verification.review",
  )
  const canReadStaff = capabilities.includes("admin.user.read")
  const canManageStaff = capabilities.includes("admin.user.manage")
  const canReadGrants =
    capabilities.includes("admin.grant.read") ||
    capabilities.includes("admin.grant.manage")
  const canReadAudit = capabilities.includes("admin.audit.read")
  const canReadRoles =
    capabilities.includes("admin.role.read") ||
    capabilities.includes("admin.role.manage")
  const canManageRoles = capabilities.includes("admin.role.manage")

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
    // React Router preserves an inner scroll container across navigation, so a
    // section or filter change would otherwise land mid-page.
    mainRef.current?.scrollTo(0, 0)
  }, [location.pathname, location.search])

  useEffect(() => {
    // Contextual links land on /grants pre-filtered. Both filters are applied
    // client-side over data the screen already loads.
    if (section !== "grants") return
    const params = new URLSearchParams(location.search)
    const userParam = params.get("user")?.trim() ?? ""
    const departmentParam = params.get("department")?.trim() ?? ""
    if (departmentParam) {
      setOpenDepartment(departmentParam)
      setAccessPerson("")
    }
    if (userParam) {
      setAccessPerson(userParam)
      setOpenDepartment(null)
    }
    if (!departmentParam && !userParam) {
      setAccessPerson("")
      setOpenDepartment(null)
    }
  }, [section, location.search])

  useEffect(() => {
    if (section !== "grants" || grants !== null || !canReadGrants) return
    let active = true
    setBusy(true)
    Promise.all([api.listGrants(), api.listDepartments()])
      .then(([grantRows, departmentRows]) => {
        if (!active) return
        setGrants(grantRows)
        setDepartments(departmentRows)
        setGrantDepartment(
          (current) => current || (departmentRows[0]?.key ?? ""),
        )
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
    if (!selectedUser || !canReadUsers) return
    let active = true
    Promise.all([
      api.listUserNotes(selectedUser.id),
      api.userTimeline(selectedUser.id),
    ])
      .then(([notes, timeline]) => {
        if (!active) return
        setUserNotes(notes)
        setUserTimeline(timeline)
      })
      .catch((value: unknown) => {
        if (active) setError(errorMessage(value))
      })
    return () => {
      active = false
    }
  }, [selectedUser, canReadUsers])

  useEffect(() => {
    if (section !== "approvals" || !canReadApprovals) return
    let active = true
    setBusy(true)
    api
      .listApprovals()
      .then((rows) => {
        if (active) setApprovals(rows)
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
  }, [section, canReadApprovals])

  useEffect(() => {
    if (section !== "partners" || !canReadPartners) return
    let active = true
    setBusy(true)
    api
      .listPartners()
      .then((rows) => {
        if (active) setPartners(rows)
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
  }, [section, canReadPartners])

  useEffect(() => {
    if (!selectedPartner || !canReadPartners) return
    let active = true
    api
      .listPartnerRepresentatives(selectedPartner.id)
      .then((rows) => {
        if (active) setPartnerReps(rows)
      })
      .catch((value: unknown) => {
        if (active) setError(errorMessage(value))
      })
    return () => {
      active = false
    }
  }, [selectedPartner, canReadPartners])

  useEffect(() => {
    if (section !== "cases" || !canReadCases) return
    let active = true
    setBusy(true)
    api
      .listCases(caseStatusFilter, caseTypeFilter, caseQuery)
      .then((rows) => {
        if (active) setCases(rows)
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
  }, [section, canReadCases, caseStatusFilter, caseTypeFilter, caseQuery])

  useEffect(() => {
    if (!selectedCase || !canReadCases) return
    let active = true
    api
      .listCaseEvents(selectedCase.id)
      .then((rows) => {
        if (active) setCaseEvents(rows)
      })
      .catch((value: unknown) => {
        if (active) setError(errorMessage(value))
      })
    api
      .listCaseEvidence(selectedCase.id)
      .then((rows) => {
        if (active) setCaseEvidence(rows)
      })
      .catch((value: unknown) => {
        if (active) setError(errorMessage(value))
      })
    return () => {
      active = false
    }
  }, [selectedCase, canReadCases])

  useEffect(() => {
    if (section !== "verification" || !canReviewVerification) return
    let active = true
    setBusy(true)
    api
      .listVerification(verificationStatus)
      .then((rows) => {
        if (active) setVerification(rows)
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
  }, [section, canReviewVerification, verificationStatus])

  async function handleVerificationDecision(
    entry: VerificationReview,
    decision: "approve" | "reject" | "request_information",
  ) {
    const reason = window.prompt(
      `Reason for ${decision.replace("_", " ")} on ${entry.reference}:`,
    )
    if (!reason || reason.trim().length < 5) return
    setBusy(true)
    setError(undefined)
    try {
      await api.decideVerification(entry.caseId, decision, reason.trim())
      setVerification(await api.listVerification(verificationStatus))
    } catch (value) {
      setError(errorMessage(value))
    } finally {
      setBusy(false)
    }
  }

  async function handleCreateCase(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    const form = new FormData(event.currentTarget)
    const title = String(form.get("title") ?? "").trim()
    const reason = String(form.get("reason") ?? "").trim()
    if (title.length < 3 || reason.length < 5) {
      setError("A title and a reason of at least five characters are required.")
      return
    }
    setBusy(true)
    setError(undefined)
    try {
      const created = await api.createCase({
        caseType: String(form.get("caseType") ?? "support"),
        title,
        description: String(form.get("description") ?? "").trim() || undefined,
        priority: String(form.get("priority") ?? "normal"),
        severity: String(form.get("severity") ?? "medium"),
        queueKey: String(form.get("queueKey") ?? "").trim() || undefined,
        reason,
      })
      setCases((current) => [created, ...(current ?? [])])
      setSelectedCase(created)
      event.currentTarget.reset()
    } catch (value) {
      setError(errorMessage(value))
    } finally {
      setBusy(false)
    }
  }

  async function handleAddCaseNote(
    event: FormEvent<HTMLFormElement>,
    entry: CaseSummary,
  ) {
    event.preventDefault()
    const form = new FormData(event.currentTarget)
    const summary = String(form.get("summary") ?? "").trim()
    if (summary.length < 3) return
    setBusy(true)
    setError(undefined)
    try {
      await api.addCaseEvent(entry.id, summary)
      setCaseEvents(await api.listCaseEvents(entry.id))
      event.currentTarget.reset()
    } catch (value) {
      setError(errorMessage(value))
    } finally {
      setBusy(false)
    }
  }

  async function handleAssignCase(entry: CaseSummary) {
    const email = window.prompt(
      `Assignee email for ${entry.reference} (leave blank to unassign):`,
      entry.assigneeEmail ?? "",
    )
    if (email === null) return
    const queueKey = window.prompt(
      "Queue key (optional):",
      entry.queueKey ?? "",
    )
    if (queueKey === null) return
    setBusy(true)
    setError(undefined)
    try {
      const updated = await api.assignCase(entry.id, email, queueKey)
      setCases((current) =>
        (current ?? []).map((row) => (row.id === updated.id ? updated : row)),
      )
      setSelectedCase(updated)
    } catch (value) {
      setError(errorMessage(value))
    } finally {
      setBusy(false)
    }
  }

  async function handleCaseStatus(entry: CaseSummary) {
    const status = window.prompt(
      `New status for ${entry.reference} (TRIAGED, OPEN, INVESTIGATING, PENDING_INFORMATION, ESCALATED, REVIEW, DECIDED, ACTION_PENDING, CLOSED, REOPENED, ARCHIVED):`,
      entry.status,
    )
    if (!status) return
    const reason = window.prompt(`Reason for moving to ${status}:`)
    if (!reason || reason.trim().length < 5) return
    setBusy(true)
    setError(undefined)
    try {
      const updated = await api.setCaseStatus(
        entry.id,
        status.trim(),
        reason.trim(),
      )
      setCases((current) =>
        (current ?? []).map((row) => (row.id === updated.id ? updated : row)),
      )
      setSelectedCase(updated)
      setCaseEvents(await api.listCaseEvents(entry.id))
    } catch (value) {
      setError(errorMessage(value))
    } finally {
      setBusy(false)
    }
  }

  async function handleAddEvidence(
    event: FormEvent<HTMLFormElement>,
    entry: CaseSummary,
  ) {
    event.preventDefault()
    const form = new FormData(event.currentTarget)
    const storageKey = String(form.get("storageKey") ?? "").trim()
    const fileName = String(form.get("fileName") ?? "").trim()
    const sha256 = String(form.get("sha256") ?? "").trim()
    const reason = String(form.get("reason") ?? "").trim()
    if (!storageKey || !fileName || reason.length < 5) {
      setError("A storage key, file name and reason are required.")
      return
    }
    setBusy(true)
    setError(undefined)
    try {
      await api.addCaseEvidence(entry.id, {
        storageKey,
        fileName,
        sha256: sha256 || undefined,
        reason,
      })
      setCaseEvidence(await api.listCaseEvidence(entry.id))
      setCaseEvents(await api.listCaseEvents(entry.id))
      event.currentTarget.reset()
    } catch (value) {
      setError(errorMessage(value))
    } finally {
      setBusy(false)
    }
  }

  async function handleEvidenceAccess(
    entry: CaseSummary,
    evidence: CaseEvidence,
  ) {
    const purpose = window.prompt(
      `Why are you accessing ${evidence.fileName}?`,
      "Case review",
    )
    if (!purpose) return
    setBusy(true)
    setError(undefined)
    try {
      await api.recordEvidenceAccess(entry.id, evidence.id, purpose)
      setCaseEvents(await api.listCaseEvents(entry.id))
    } catch (value) {
      setError(errorMessage(value))
    } finally {
      setBusy(false)
    }
  }

  async function handleSupersedeEvidence(
    entry: CaseSummary,
    evidence: CaseEvidence,
  ) {
    const replacementId = window.prompt(
      "Id of the replacement evidence for " + evidence.fileName + ":",
    )
    if (!replacementId) return
    const reason = window.prompt("Reason for superseding:")
    if (!reason || reason.trim().length < 5) return
    setBusy(true)
    setError(undefined)
    try {
      await api.supersedeEvidence(
        evidence.id,
        replacementId.trim(),
        reason.trim(),
      )
      setCaseEvidence(await api.listCaseEvidence(entry.id))
      setCaseEvents(await api.listCaseEvents(entry.id))
    } catch (value) {
      setError(errorMessage(value))
    } finally {
      setBusy(false)
    }
  }

  async function handleRequestCaseDecision(entry: CaseSummary) {
    const outcome = window.prompt(
      `Outcome for ${entry.reference} (for example: resolved in the customer's favour):`,
    )
    if (!outcome || outcome.trim().length < 3) return
    const reason = window.prompt("Reason for this decision:")
    if (!reason || reason.trim().length < 5) return
    setBusy(true)
    setError(undefined)
    try {
      const request = await api.requestCaseDecision(
        entry.id,
        outcome.trim(),
        reason.trim(),
      )
      setError(
        `Decision requested (${request.reference}). A second administrator must approve it.`,
      )
      setCaseEvents(await api.listCaseEvents(entry.id))
    } catch (value) {
      setError(errorMessage(value))
    } finally {
      setBusy(false)
    }
  }

  async function handleCreatePartner(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    const form = new FormData(event.currentTarget)
    const legalName = String(form.get("legalName") ?? "").trim()
    const reason = String(form.get("reason") ?? "").trim()
    if (legalName.length < 2 || reason.length < 5) {
      setError(
        "A legal name and a reason of at least five characters are required.",
      )
      return
    }
    setBusy(true)
    setError(undefined)
    try {
      const created = await api.createPartner({
        legalName,
        tradingName: String(form.get("tradingName") ?? "").trim() || undefined,
        category: String(form.get("category") ?? "").trim() || undefined,
        country: String(form.get("country") ?? "").trim() || undefined,
        reason,
      })
      setPartners((current) => [created, ...(current ?? [])])
      setSelectedPartner(created)
      event.currentTarget.reset()
    } catch (value) {
      setError(errorMessage(value))
    } finally {
      setBusy(false)
    }
  }

  async function handlePartnerStatus(
    partner: PartnerOrganisation,
    status: "active" | "suspended" | "terminated",
  ) {
    const reason = window.prompt(
      `Reason for marking ${partner.legalName} as ${status}:`,
    )
    if (!reason || reason.trim().length < 5) return
    setBusy(true)
    setError(undefined)
    try {
      const updated = await api.setPartnerStatus(
        partner.id,
        status,
        reason.trim(),
      )
      setPartners((current) =>
        (current ?? []).map((entry) =>
          entry.id === updated.id ? updated : entry,
        ),
      )
      setSelectedPartner(updated)
    } catch (value) {
      setError(errorMessage(value))
    } finally {
      setBusy(false)
    }
  }

  async function handleAddPartnerRepresentative(
    event: FormEvent<HTMLFormElement>,
    partner: PartnerOrganisation,
  ) {
    event.preventDefault()
    const form = new FormData(event.currentTarget)
    const email = String(form.get("email") ?? "").trim()
    const role = String(form.get("role") ?? "member")
    const reason = String(form.get("reason") ?? "").trim()
    if (!email || reason.length < 5) {
      setError(
        "An account email and a reason of at least five characters are required.",
      )
      return
    }
    setBusy(true)
    setError(undefined)
    try {
      await api.addPartnerRepresentative(partner.id, email, role, reason)
      setPartnerReps(await api.listPartnerRepresentatives(partner.id))
      event.currentTarget.reset()
    } catch (value) {
      setError(errorMessage(value))
    } finally {
      setBusy(false)
    }
  }

  async function handleDecideApproval(
    approval: ApprovalRequest,
    decision: "approve" | "reject",
  ) {
    const reason = window.prompt(
      `Reason for ${
        decision === "approve" ? "approving" : "rejecting"
      } ${approval.reference}:`,
    )
    if (!reason || reason.trim().length < 5) return
    setBusy(true)
    setError(undefined)
    try {
      const updated = await api.decideApproval(
        approval.id,
        decision,
        reason.trim(),
      )
      setApprovals((current) =>
        (current ?? []).map((entry) =>
          entry.id === updated.id ? updated : entry,
        ),
      )
      if (updated.status === "approved") {
        setUsers((current) =>
          (current ?? []).map((entry) =>
            entry.id === updated.targetId
              ? { ...entry, status: "closed" }
              : entry,
          ),
        )
        setSelectedUser((current) =>
          current && current.id === updated.targetId
            ? { ...current, status: "closed" }
            : current,
        )
      }
    } catch (value) {
      setError(errorMessage(value))
    } finally {
      setBusy(false)
    }
  }

  async function handleRequestClosure(user: UserSummary) {
    const reason = window.prompt(
      `Reason for requesting closure of ${user.email}:`,
    )
    if (!reason || reason.trim().length < 5) return
    setBusy(true)
    setError(undefined)
    try {
      const request = await api.requestApproval({
        actionType: "account.closure",
        targetType: "user",
        targetId: user.id,
        reason: reason.trim(),
      })
      setError(
        `Closure requested (${request.reference}). A second administrator must approve it.`,
      )
      setUserTimeline(await api.userTimeline(user.id))
    } catch (value) {
      setError(errorMessage(value))
    } finally {
      setBusy(false)
    }
  }

  async function handleAccountAction(
    user: UserSummary,
    action: "suspend" | "reactivate" | "revoke-sessions",
  ) {
    const reason = window.prompt(
      `Reason for ${action.replace("-", " ")} on ${user.email}:`,
    )
    if (!reason || reason.trim().length < 5) return

    setBusy(true)
    setError(undefined)
    try {
      const run =
        action === "suspend"
          ? api.suspendUser(user.id, reason.trim())
          : action === "reactivate"
            ? api.reactivateUser(user.id, reason.trim())
            : api.revokeUserSessions(user.id, reason.trim())

      const result = await run
      if (action === "revoke-sessions") {
        setError(
          `Revoked ${result.sessionsRevoked} session${
            result.sessionsRevoked === 1 ? "" : "s"
          }.`,
        )
      } else {
        setSelectedUser({ ...user, status: result.status })
        setUsers((current) =>
          (current ?? []).map((entry) =>
            entry.id === user.id ? { ...entry, status: result.status } : entry,
          ),
        )
      }
      setUserTimeline(await api.userTimeline(user.id))
    } catch (value) {
      setError(errorMessage(value))
    } finally {
      setBusy(false)
    }
  }

  async function handleAddNote(
    event: FormEvent<HTMLFormElement>,
    user: UserSummary,
  ) {
    event.preventDefault()
    const form = new FormData(event.currentTarget)
    const body = String(form.get("note") ?? "").trim()
    if (body.length < 3) return
    setBusy(true)
    setError(undefined)
    try {
      await api.addUserNote(user.id, body)
      event.currentTarget.reset()
      setUserNotes(await api.listUserNotes(user.id))
      setUserTimeline(await api.userTimeline(user.id))
    } catch (value) {
      setError(errorMessage(value))
    } finally {
      setBusy(false)
    }
  }

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

  useEffect(() => {
    if (section !== "roles" || roles !== null || !canReadRoles) return
    let active = true
    setBusy(true)
    Promise.all([
      api.listRoles(),
      api.listRoleAssignments(),
      api.listRoleScopeTargets("department"),
      api.listRoleScopeTargets("organisation"),
      api.listAssignableStaff(),
    ])
      .then(
        ([
          roleRows,
          assignmentRows,
          departmentRows,
          organisationRows,
          staffRows,
        ]) => {
          if (!active) return
          setRoles(roleRows)
          setRoleAssignments(assignmentRows)
          setScopeTargets({
            department: departmentRows,
            organisation: organisationRows,
          })
          setAssignableStaff(staffRows)
          setAssignRoleKey((current) => current || (roleRows[0]?.key ?? ""))
        },
      )
      .catch((value: unknown) => {
        if (active) setError(errorMessage(value))
      })
      .finally(() => {
        if (active) setBusy(false)
      })
    return () => {
      active = false
    }
  }, [section, roles, canReadRoles])

  async function handleAssignRole(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    const form = new FormData(event.currentTarget)
    const email = assignStaffEmail
    const roleKey = String(form.get("roleKey") ?? "")
    const scopeType = String(
      form.get("scopeType") ?? "platform",
    ) as RoleScopeType
    const scopeId = String(form.get("scopeId") ?? "").trim()
    const expiresAtRaw = String(form.get("expiresAt") ?? "").trim()
    const reason = String(form.get("reason") ?? "").trim()

    if (!email || !roleKey || reason.length < 3) {
      setError("Choose a staff member, a role and a reason.")
      return
    }
    if (scopeType !== "platform" && !scopeId) {
      setError("Choose the target this role applies to.")
      return
    }

    setBusy(true)
    setError(undefined)
    try {
      const created = await api.assignRole({
        email,
        roleKey,
        scopeType,
        ...(scopeType === "platform" ? {} : { scopeId }),
        ...(expiresAtRaw
          ? { expiresAt: new Date(expiresAtRaw).toISOString() }
          : {}),
        reason,
      })
      setRoleAssignments((current) => [created, ...(current ?? [])])
      setRoles((current) =>
        (current ?? []).map((role) =>
          role.key === created.roleKey
            ? { ...role, activeAssignments: role.activeAssignments + 1 }
            : role,
        ),
      )
      event.currentTarget.reset()
      setAssignScopeType("platform")
      setAssignScopeId("")
      setAssignStaffEmail("")
      setStaffSearch("")
    } catch (value) {
      setError(errorMessage(value))
    } finally {
      setBusy(false)
    }
  }

  async function handleRevokeRole(assignment: RoleAssignment) {
    const reason = window.prompt(
      `Reason for removing ${assignment.roleName} from ${assignment.email}:`,
    )
    if (!reason || reason.trim().length < 3) return
    setBusy(true)
    setError(undefined)
    try {
      const revoked = await api.revokeRole(assignment.id, reason.trim())
      setRoleAssignments((current) =>
        (current ?? []).map((entry) =>
          entry.id === revoked.id ? revoked : entry,
        ),
      )
      setRoles((current) =>
        (current ?? []).map((role) =>
          role.key === revoked.roleKey
            ? {
                ...role,
                activeAssignments: Math.max(0, role.activeAssignments - 1),
              }
            : role,
        ),
      )
    } catch (value) {
      setError(errorMessage(value))
    } finally {
      setBusy(false)
    }
  }

  async function handleCreateGrant(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    const form = new FormData(event.currentTarget)
    const email = String(form.get("email") ?? "").trim()
    const grantType = String(form.get("grantType") ?? "staff")
    const scope = String(form.get("scope") ?? "")
    const departmentKey = String(form.get("departmentKey") ?? "").trim()
    const reason = String(form.get("reason") ?? "").trim()
    if (!email || !scope || !departmentKey || reason.length < 3) {
      setError("An email, scope, department and reason are required.")
      return
    }

    setBusy(true)
    setError(undefined)
    try {
      const created = await api.createGrant({
        email,
        grantType,
        scope,
        departmentKey,
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

  async function handleAssignDepartment(grant: Grant, departmentKey: string) {
    if (!departmentKey) return
    const reason = window.prompt(
      `Reason for recording ${grant.scope} under this department:`,
    )
    if (!reason || reason.trim().length < 3) return
    setBusy(true)
    setError(undefined)
    try {
      const updated = await api.setGrantDepartment(
        grant.id,
        departmentKey,
        reason.trim(),
      )
      setGrants((current) =>
        (current ?? []).map((entry) =>
          entry.id === updated.id ? updated : entry,
        ),
      )
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

  const grantRows = grants ?? []
  const accessPersonQuery = accessPerson.trim().toLowerCase()
  const userScopedGrants = accessPersonQuery
    ? grantRows.filter((grant) =>
        [grant.email, grant.userName, grant.userId].some((value) =>
          (value ?? "").toLowerCase().includes(accessPersonQuery),
        ),
      )
    : []
  const activeOwnGrants = (own?.grants ?? []).filter(
    (grant) => grantStatusOf(grant) === "active",
  )
  const departmentSummaries = (departments ?? []).map((department) => {
    const rows = grantRows.filter(
      (grant) => grant.departmentKey === department.key,
    )
    const active = rows.filter((grant) => grantStatusOf(grant) === "active")
    return {
      key: department.key,
      name: department.name,
      total: rows.length,
      active: active.length,
      people: new Set(active.map((grant) => grant.userId)).size,
    }
  })
  const unassignedGrants = grantRows.filter(
    (grant) => grant.departmentKey === null,
  )
  if (unassignedGrants.length > 0) {
    const active = unassignedGrants.filter(
      (grant) => grantStatusOf(grant) === "active",
    )
    departmentSummaries.push({
      key: "unassigned",
      name: "Unassigned",
      total: unassignedGrants.length,
      active: active.length,
      people: new Set(active.map((grant) => grant.userId)).size,
    })
  }

  const openSummary =
    departmentSummaries.find((summary) => summary.key === openDepartment) ??
    null
  const departmentGrants =
    openDepartment === null
      ? []
      : openDepartment === "unassigned"
        ? unassignedGrants
        : grantRows.filter((grant) => grant.departmentKey === openDepartment)
  const grantQuery = grantSearch.trim().toLowerCase()
  const visibleGrants = departmentGrants
    .filter((grant) => {
      if (
        grantStatusFilter !== "all" &&
        grantStatusOf(grant) !== grantStatusFilter
      ) {
        return false
      }
      if (!grantQuery) return true
      return [grant.userName, grant.email, grant.scope, grant.grantType].some(
        (value) => (value ?? "").toLowerCase().includes(grantQuery),
      )
    })
    .sort((left, right) => {
      const leftRank = grantStatusOf(left) === "active" ? 0 : 1
      const rightRank = grantStatusOf(right) === "active" ? 0 : 1
      if (leftRank !== rightRank) return leftRank - rightRank
      return (left.userName ?? left.email ?? "").localeCompare(
        right.userName ?? right.email ?? "",
      )
    })

  const scopeName = (assignment: RoleAssignment): string => {
    if (assignment.scopeType === "platform") return "Platform"
    const choices =
      assignment.scopeType === "department"
        ? scopeTargets.department
        : scopeTargets.organisation
    const label = assignment.scopeId
      ? choices.find((target) => target.id === assignment.scopeId)?.name
      : undefined
    return (
      label ??
      `${assignment.scopeType} ${assignment.scopeId?.slice(0, 8) ?? ""}`
    )
  }

  const assignmentQuery = roleQuery.trim().toLowerCase()
  const visibleAssignments = (roleAssignments ?? [])
    .filter((assignment) => {
      if (
        roleStatusFilter !== "all" &&
        assignmentStatusOf(assignment) !== roleStatusFilter
      ) {
        return false
      }
      if (roleFilterKey && assignment.roleKey !== roleFilterKey) return false
      if (
        accessPersonQuery &&
        ![assignment.displayName, assignment.email].some((value) =>
          (value ?? "").toLowerCase().includes(accessPersonQuery),
        )
      ) {
        return false
      }
      if (!assignmentQuery) return true
      return [
        assignment.displayName,
        assignment.email,
        assignment.roleName,
        scopeName(assignment),
      ].some((value) => (value ?? "").toLowerCase().includes(assignmentQuery))
    })
    .sort((left, right) => {
      const leftRank = assignmentStatusOf(left) === "active" ? 0 : 1
      const rightRank = assignmentStatusOf(right) === "active" ? 0 : 1
      if (leftRank !== rightRank) return leftRank - rightRank
      return (left.displayName ?? left.email).localeCompare(
        right.displayName ?? right.email,
      )
    })

  const scopeChoices =
    assignScopeType === "department"
      ? scopeTargets.department
      : assignScopeType === "organisation"
        ? scopeTargets.organisation
        : []

  const staffQuery = staffSearch.trim().toLowerCase()
  const matchingStaff = assignableStaff.filter((staff) =>
    [staff.displayName, staff.email, staff.departmentName].some((value) =>
      (value ?? "").toLowerCase().includes(staffQuery),
    ),
  )
  const visibleStaff =
    matchingStaff.length > 0
      ? matchingStaff
      : assignableStaff.filter((staff) => staff.email === assignStaffEmail)

  if (location.pathname === "/roles" || location.pathname === "/grants") {
    return (
      <Navigate to={`/access${location.pathname}${location.search}`} replace />
    )
  }

  if (knownPath && section === "roles" && !canReadRoles && canReadGrants) {
    return <Navigate to="/access/grants" replace />
  }

  if (knownPath && section === "grants" && !canReadGrants && canReadRoles) {
    return <Navigate to="/access/roles" replace />
  }

  return (
    <div className="app-shell">
      <aside className="app-sidebar">
        <Brand />
        <nav className="app-nav">
          {visibleGroups.map((group) => (
            <div key={group.label} className="nav-group">
              <p className="nav-label">{group.label}</p>
              {group.items.map((item) => {
                const active =
                  location.pathname === item.path ||
                  (item.activePaths ?? []).includes(location.pathname)
                return (
                  <NavLink
                    key={item.id}
                    to={item.path}
                    end
                    className={`nav-item${active ? " is-active" : ""}`}
                  >
                    {item.label}
                  </NavLink>
                )
              })}
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

      <main className="app-main" ref={mainRef}>
        <header className="app-topbar">
          <div>
            <p className="eyebrow">Control portal</p>
            <h1>{knownPath ? sectionTitle(section) : "Not found"}</h1>
          </div>
          <span className="badge">{session.environment}</span>
        </header>

        {knownPath && (section === "roles" || section === "grants") && (
          <nav className="access-tabs" aria-label="Access">
            <div className="access-tab-list">
              {canReadRoles && (
                <NavLink
                  to="/access/roles"
                  className={({ isActive }) =>
                    `access-tab${isActive ? " is-active" : ""}`
                  }
                >
                  Roles
                </NavLink>
              )}
              {canReadGrants && (
                <NavLink
                  to="/access/grants"
                  className={({ isActive }) =>
                    `access-tab${isActive ? " is-active" : ""}`
                  }
                >
                  Grants
                </NavLink>
              )}
            </div>
            <input
              className="search-input access-person"
              type="search"
              placeholder="Find a person by name or email"
              value={accessPerson}
              onChange={(event) => setAccessPerson(event.target.value)}
              aria-label="Find a person across roles and grants"
            />
          </nav>
        )}

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
              <div className="panel-head">
                <h2>What you can do</h2>
                <span className="muted">
                  {own ? `${own.capabilities.length} allowed` : "—"}
                </span>
              </div>
              {own === null && <p className="muted">Loading…</p>}
              {own && own.capabilities.length === 0 && (
                <p className="muted">
                  No capabilities yet. The first administrator grant must be
                  bootstrapped out of band.
                </p>
              )}
              {own && own.capabilities.length > 0 && (
                <details className="overview-details">
                  <summary title="Expand the full list">
                    <span className="overview-summary">
                      {own.capabilities.map(capabilityLabel).join(" · ")}
                    </span>
                  </summary>
                  <ul className="overview-list">
                    {own.capabilities.map((capability) => (
                      <li key={capability}>
                        <span>{capabilityLabel(capability)}</span>
                        <span className="mono muted">{capability}</span>
                      </li>
                    ))}
                  </ul>
                </details>
              )}
            </section>

            <section className="panel">
              <div className="panel-head">
                <h2>Your grants</h2>
                <span className="muted">
                  {own ? `${activeOwnGrants.length} active` : "—"}
                </span>
              </div>
              {own === null && <p className="muted">Loading…</p>}
              {own && activeOwnGrants.length === 0 && (
                <p className="muted">No active grants.</p>
              )}
              {own && activeOwnGrants.length > 0 && (
                <details className="overview-details">
                  <summary title="Expand the full list">
                    <span className="overview-summary">
                      {activeOwnGrants
                        .map(
                          (grant) =>
                            `${grantTypeLabel(grant.grantType)} · ${capabilityLabel(grant.scope)}`,
                        )
                        .join(" · ")}
                    </span>
                  </summary>
                  <ul className="overview-list">
                    {activeOwnGrants.map((grant) => (
                      <li key={grant.id}>
                        <span>{capabilityLabel(grant.scope)}</span>
                        <span className="mono muted">
                          {grant.grantType} · {grant.scope}
                        </span>
                      </li>
                    ))}
                  </ul>
                </details>
              )}
            </section>

            {canReadGrants && (
              <section className="panel">
                <div className="panel-head">
                  <h2>Grant administration</h2>
                </div>
                <p className="muted">
                  Grants are filed by department and reached from the people
                  they apply to. This is the universal entry point when you can
                  read grants but not the user directory.
                </p>
                <Link
                  className="button button-quiet button-small button-link"
                  to="/access/grants"
                >
                  Open grants
                </Link>
              </section>
            )}
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
                {canReadGrants && (
                  <Link
                    className="button button-quiet button-small button-link"
                    to={`/grants?user=${encodeURIComponent(selectedUser.email)}`}
                    onClick={() => setSelectedUser(null)}
                  >
                    Manage access
                  </Link>
                )}
                <p className="hint">
                  Closing an account removes its grants and roles. Every action
                  here requires a reason and is audited.
                </p>

                {canManageUsers && selectedUser.id !== session.userId && (
                  <div className="account-actions">
                    {selectedUser.status === "active" && (
                      <button
                        type="button"
                        className="button button-quiet button-small"
                        onClick={() =>
                          handleAccountAction(selectedUser, "suspend")
                        }
                        disabled={busy}
                      >
                        Suspend
                      </button>
                    )}
                    {selectedUser.status === "suspended" && (
                      <button
                        type="button"
                        className="button button-quiet button-small"
                        onClick={() =>
                          handleAccountAction(selectedUser, "reactivate")
                        }
                        disabled={busy}
                      >
                        Reactivate
                      </button>
                    )}
                    <button
                      type="button"
                      className="button button-quiet button-small"
                      onClick={() =>
                        handleAccountAction(selectedUser, "revoke-sessions")
                      }
                      disabled={busy}
                    >
                      Revoke sessions
                    </button>
                    {selectedUser.status !== "closed" && (
                      <button
                        type="button"
                        className="button button-danger button-small"
                        onClick={() => handleRequestClosure(selectedUser)}
                        disabled={busy}
                      >
                        Request closure
                      </button>
                    )}
                  </div>
                )}

                <h3 className="section-title">Notes</h3>
                {userNotes.length === 0 && (
                  <p className="muted">No notes yet.</p>
                )}
                {userNotes.length > 0 && (
                  <ul className="plain-list">
                    {userNotes.map((note) => (
                      <li key={note.id}>
                        <div>{note.body}</div>
                        <div className="muted">
                          {formatTime(note.createdAt)}
                          {note.authorName || note.authorEmail
                            ? ` · ${note.authorName ?? note.authorEmail}`
                            : ""}
                        </div>
                      </li>
                    ))}
                  </ul>
                )}
                {canManageUsers && (
                  <form
                    className="form"
                    onSubmit={(event) => handleAddNote(event, selectedUser)}
                  >
                    <label className="field">
                      <span>Add a note</span>
                      <textarea
                        name="note"
                        rows={2}
                        maxLength={2000}
                        minLength={3}
                        required
                        disabled={busy}
                      />
                    </label>
                    <button
                      className="button button-small"
                      type="submit"
                      disabled={busy}
                    >
                      Add note
                    </button>
                  </form>
                )}

                <h3 className="section-title">Timeline</h3>
                {userTimeline.length === 0 && (
                  <p className="muted">No recorded activity yet.</p>
                )}
                {userTimeline.length > 0 && (
                  <ul className="plain-list">
                    {userTimeline.map((entry, index) => (
                      <li key={`${entry.occurredAt}-${index}`}>
                        <div>
                          <span className="mono">{entry.action}</span>
                          {entry.reason ? ` — ${entry.reason}` : ""}
                        </div>
                        <div className="muted">
                          {formatTime(entry.occurredAt)} ·{" "}
                          {entry.actorName ??
                            entry.actorEmail ??
                            "recorded by the system"}
                        </div>
                      </li>
                    ))}
                  </ul>
                )}
              </section>
            )}
          </div>
        )}

        {knownPath && section === "staff" && !canReadStaff && (
          <section className="panel">
            <h2>Staff</h2>
            <p className="muted">
              Your governance role does not include staff directory access.
            </p>
          </section>
        )}

        {knownPath && section === "staff" && canReadStaff && (
          <StaffPage canManage={canManageStaff} />
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
              <div className="panel-head">
                <h2>Create a grant</h2>
                <span className="muted">Every change is audited</span>
              </div>
              <form className="form" onSubmit={handleCreateGrant}>
                <div className="form-row">
                  <label className="field">
                    <span>User email</span>
                    <input name="email" type="email" required disabled={busy} />
                  </label>
                  <label className="field">
                    <span>Department</span>
                    <select
                      name="departmentKey"
                      value={grantDepartment}
                      onChange={(event) =>
                        setGrantDepartment(event.target.value)
                      }
                      disabled={busy || departments === null}
                      required
                    >
                      {departments === null && (
                        <option value="">Loading…</option>
                      )}
                      {(departments ?? []).map((department) => (
                        <option key={department.key} value={department.key}>
                          {department.name}
                        </option>
                      ))}
                    </select>
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
                <button
                  className="button"
                  type="submit"
                  disabled={busy || departments === null}
                >
                  {busy ? "Working…" : "Create grant"}
                </button>
              </form>
            </section>

            {accessPersonQuery !== "" && (
              <section className="panel">
                <div className="panel-head">
                  <div>
                    <h2>Grants for {accessPerson}</h2>
                    <span className="muted">
                      {userScopedGrants.length}{" "}
                      {userScopedGrants.length === 1 ? "grant" : "grants"}
                    </span>
                  </div>
                  <button
                    type="button"
                    className="button button-quiet button-small"
                    onClick={() => {
                      setAccessPerson("")
                      navigate("/access/grants", { replace: true })
                    }}
                  >
                    Clear
                  </button>
                </div>
                {grants === null && <p className="muted">Loading…</p>}
                {grants !== null && userScopedGrants.length === 0 && (
                  <p className="muted">
                    This person holds no grants in this environment.
                  </p>
                )}
                {grants !== null && userScopedGrants.length > 0 && (
                  <div className="table-wrap">
                    <table className="table">
                      <thead>
                        <tr>
                          <th>Type</th>
                          <th>Scope</th>
                          <th>Department</th>
                          <th>Status</th>
                          <th>Expires</th>
                        </tr>
                      </thead>
                      <tbody>
                        {userScopedGrants.map((grant) => {
                          const status = grantStatusOf(grant)
                          return (
                            <tr key={grant.id}>
                              <td>{grant.grantType}</td>
                              <td className="mono">{grant.scope}</td>
                              <td>{grant.departmentName ?? "Unassigned"}</td>
                              <td>
                                <span className={grantStatusChip(status)}>
                                  {status}
                                </span>
                              </td>
                              <td>
                                {grant.expiresAt
                                  ? formatTime(grant.expiresAt)
                                  : "Never"}
                              </td>
                            </tr>
                          )
                        })}
                      </tbody>
                    </table>
                  </div>
                )}
              </section>
            )}

            {openSummary === null && accessPersonQuery === "" && (
              <section className="panel">
                <div className="panel-head">
                  <h2>Departments</h2>
                  <span className="muted">
                    {grants === null
                      ? "Loading…"
                      : `${grants.length} ${
                          grants.length === 1 ? "grant" : "grants"
                        } in this environment`}
                  </span>
                </div>
                <p className="muted">
                  Choose an area to see the grants held in it. A grant belongs
                  to exactly one department.
                </p>
                {departments === null && <p className="muted">Loading…</p>}
                {departments !== null && (
                  <div className="table-wrap">
                    <table className="table">
                      <thead>
                        <tr>
                          <th>Department</th>
                          <th>Active grants</th>
                          <th>People</th>
                          <th>Total</th>
                          <th />
                        </tr>
                      </thead>
                      <tbody>
                        {departmentSummaries.map((summary) => (
                          <tr key={summary.key}>
                            <td>{summary.name}</td>
                            <td>{summary.active}</td>
                            <td>{summary.people}</td>
                            <td>{summary.total}</td>
                            <td>
                              <button
                                type="button"
                                className="button button-quiet button-small"
                                onClick={() => {
                                  setOpenDepartment(summary.key)
                                  setGrantSearch("")
                                  setGrantStatusFilter("all")
                                  setAccessPerson("")
                                  navigate(
                                    `/grants?department=${encodeURIComponent(summary.key)}`,
                                  )
                                }}
                              >
                                View
                              </button>
                            </td>
                          </tr>
                        ))}
                      </tbody>
                    </table>
                  </div>
                )}
              </section>
            )}

            {openSummary !== null && accessPersonQuery === "" && (
              <section className="panel">
                <div className="panel-head">
                  <div>
                    <button
                      type="button"
                      className="button button-quiet button-small"
                      onClick={() => {
                        setOpenDepartment(null)
                        navigate("/access/grants", { replace: true })
                      }}
                    >
                      ← All departments
                    </button>
                  </div>
                  <span className="muted">
                    {openSummary.active} active · {openSummary.people}{" "}
                    {openSummary.people === 1 ? "person" : "people"} ·{" "}
                    {openSummary.total} total
                  </span>
                </div>
                <h2>{openSummary.name}</h2>

                <form
                  className="user-toolbar"
                  onSubmit={(event) => event.preventDefault()}
                >
                  <input
                    className="search-input"
                    type="search"
                    placeholder="Search name, email or scope"
                    value={grantSearch}
                    onChange={(event) => setGrantSearch(event.target.value)}
                    aria-label="Search grants in this department"
                  />
                  <select
                    className="filter-select"
                    value={grantStatusFilter}
                    onChange={(event) =>
                      setGrantStatusFilter(event.target.value)
                    }
                    aria-label="Filter by grant status"
                  >
                    <option value="all">All statuses</option>
                    <option value="active">Active</option>
                    <option value="expired">Expired</option>
                    <option value="revoked">Revoked</option>
                  </select>
                  <span className="muted">
                    {visibleGrants.length} of {departmentGrants.length}
                  </span>
                </form>

                {visibleGrants.length === 0 && (
                  <p className="muted">
                    No grants match this view. Clear the search or choose
                    another status.
                  </p>
                )}

                {visibleGrants.length > 0 && (
                  <div className="table-wrap">
                    <table className="table">
                      <thead>
                        <tr>
                          <th>User</th>
                          <th>Type</th>
                          <th>Scope</th>
                          <th>Status</th>
                          <th>Expires</th>
                          <th />
                        </tr>
                      </thead>
                      <tbody>
                        {visibleGrants.map((grant) => {
                          const status = grantStatusOf(grant)
                          return (
                            <tr key={grant.id}>
                              <td>
                                <div>{grant.userName ?? "—"}</div>
                                <div className="muted">{grant.email}</div>
                              </td>
                              <td>{grant.grantType}</td>
                              <td className="mono">{grant.scope}</td>
                              <td>
                                <span className={grantStatusChip(status)}>
                                  {status}
                                </span>
                              </td>
                              <td>
                                {grant.expiresAt
                                  ? formatTime(grant.expiresAt)
                                  : "Never"}
                              </td>
                              <td>
                                {grant.departmentKey === null ? (
                                  <select
                                    className="filter-select"
                                    defaultValue=""
                                    aria-label={`Set the department for ${grant.email ?? "this grant"}`}
                                    disabled={busy || departments === null}
                                    onChange={(event) => {
                                      const next = event.target.value
                                      if (next) {
                                        void handleAssignDepartment(grant, next)
                                      }
                                    }}
                                  >
                                    <option value="">Assign department…</option>
                                    {(departments ?? []).map((department) => (
                                      <option
                                        key={department.key}
                                        value={department.key}
                                      >
                                        {department.name}
                                      </option>
                                    ))}
                                  </select>
                                ) : (
                                  !grant.revokedAt && (
                                    <button
                                      type="button"
                                      className="button button-quiet button-small"
                                      onClick={() => handleRevoke(grant)}
                                      disabled={busy}
                                    >
                                      Revoke
                                    </button>
                                  )
                                )}
                              </td>
                            </tr>
                          )
                        })}
                      </tbody>
                    </table>
                  </div>
                )}
              </section>
            )}
          </div>
        )}

        {knownPath && section === "roles" && !canReadRoles && (
          <section className="panel">
            <h2>Roles</h2>
            <p className="muted">
              Your governance role does not include role administration.
            </p>
          </section>
        )}

        {knownPath && section === "roles" && canReadRoles && (
          <div className="dash-stack">
            {canManageRoles && (
              <section className="panel">
                <div className="panel-head">
                  <h2>Assign a role</h2>
                  <button
                    className="button button-small"
                    type="submit"
                    form="assign-role-form"
                    disabled={busy || assignableStaff.length === 0}
                  >
                    {busy ? "Working…" : "Assign role"}
                  </button>
                </div>
                <form
                  id="assign-role-form"
                  className="form"
                  onSubmit={handleAssignRole}
                >
                  <div className="form-row">
                    <label className="field">
                      <span>Find a staff member</span>
                      <input
                        type="search"
                        placeholder="Filter by name, email or department"
                        value={staffSearch}
                        onChange={(event) => setStaffSearch(event.target.value)}
                        disabled={busy}
                        aria-label="Filter staff"
                      />
                    </label>
                    <label className="field">
                      <span>Staff member</span>
                      <select
                        value={assignStaffEmail}
                        onChange={(event) =>
                          setAssignStaffEmail(event.target.value)
                        }
                        disabled={busy || assignableStaff.length === 0}
                        required
                        aria-label="Choose a staff member"
                      >
                        <option value="">
                          {assignableStaff.length === 0
                            ? "No active staff yet"
                            : "Choose a staff member"}
                        </option>
                        {visibleStaff.map((staff) => (
                          <option key={staff.userId} value={staff.email}>
                            {staff.displayName ?? staff.email} — {staff.email}
                            {staff.departmentName
                              ? ` — ${staff.departmentName}`
                              : ""}
                          </option>
                        ))}
                      </select>
                    </label>
                    <label className="field">
                      <span>Role</span>
                      <select
                        name="roleKey"
                        value={assignRoleKey}
                        onChange={(event) =>
                          setAssignRoleKey(event.target.value)
                        }
                        disabled={busy || roles === null}
                        required
                      >
                        {(roles ?? []).map((role) => (
                          <option key={role.key} value={role.key}>
                            {role.name}
                          </option>
                        ))}
                      </select>
                    </label>
                    <label className="field">
                      <span>Scope</span>
                      <select
                        name="scopeType"
                        value={assignScopeType}
                        onChange={(event) => {
                          setAssignScopeType(
                            event.target.value as RoleScopeType,
                          )
                          setAssignScopeId("")
                        }}
                        disabled={busy}
                      >
                        <option value="platform">Platform</option>
                        <option value="department">Department</option>
                        <option value="organisation">Organisation</option>
                      </select>
                    </label>
                    {assignScopeType !== "platform" && (
                      <label className="field">
                        <span>Target</span>
                        <select
                          name="scopeId"
                          value={assignScopeId}
                          onChange={(event) =>
                            setAssignScopeId(event.target.value)
                          }
                          disabled={busy}
                          required
                        >
                          <option value="">Choose…</option>
                          {scopeChoices.map((target) => (
                            <option key={target.id} value={target.id}>
                              {target.name}
                            </option>
                          ))}
                        </select>
                      </label>
                    )}
                    <label className="field">
                      <span>Expires (optional)</span>
                      <input name="expiresAt" type="date" disabled={busy} />
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
                  <p className="hint">
                    You cannot change your own roles, and the last role manager
                    cannot be removed. Only active staff can be chosen.
                  </p>
                </form>
              </section>
            )}

            <section className="panel">
              <details className="catalogue-details">
                <summary>
                  <span className="catalogue-summary">Role catalogue</span>
                  <span className="muted">
                    {roles === null
                      ? "Loading…"
                      : `${roles.length} roles · expand to see permissions`}
                  </span>
                </summary>
                <p className="muted">
                  Roles are fixed, reviewed collections of permissions. Expand a
                  role to see what it allows.
                </p>
                {roles !== null && (
                  <div className="table-wrap">
                    <table className="table">
                      <thead>
                        <tr>
                          <th>Role</th>
                          <th>Permissions</th>
                          <th>Active assignments</th>
                        </tr>
                      </thead>
                      <tbody>
                        {roles.map((role) => (
                          <tr key={role.key}>
                            <td>
                              <div>{role.name}</div>
                              <div className="muted mono">{role.key}</div>
                            </td>
                            <td>
                              <details className="overview-details">
                                <summary title="Show the permissions">
                                  <span className="overview-summary">
                                    {role.permissions.length} permissions
                                  </span>
                                </summary>
                                <ul className="overview-list">
                                  {role.permissions.map((permission) => (
                                    <li key={permission}>
                                      <span>{capabilityLabel(permission)}</span>
                                      <span className="mono muted">
                                        {permission}
                                      </span>
                                    </li>
                                  ))}
                                </ul>
                              </details>
                            </td>
                            <td>{role.activeAssignments}</td>
                          </tr>
                        ))}
                      </tbody>
                    </table>
                  </div>
                )}
              </details>
            </section>

            <section className="panel">
              <div className="panel-head">
                <h2>Assignments</h2>
                <span className="muted">
                  {roleAssignments === null
                    ? "Loading…"
                    : `${visibleAssignments.length} of ${roleAssignments.length}`}
                </span>
              </div>
              <form
                className="user-toolbar"
                onSubmit={(event) => event.preventDefault()}
              >
                <input
                  className="search-input"
                  type="search"
                  placeholder="Search person, role or scope"
                  value={roleQuery}
                  onChange={(event) => setRoleQuery(event.target.value)}
                  aria-label="Search role assignments"
                />
                <select
                  className="filter-select"
                  value={roleFilterKey}
                  onChange={(event) => setRoleFilterKey(event.target.value)}
                  aria-label="Filter by role"
                >
                  <option value="">All roles</option>
                  {(roles ?? []).map((role) => (
                    <option key={role.key} value={role.key}>
                      {role.name}
                    </option>
                  ))}
                </select>
                <select
                  className="filter-select"
                  value={roleStatusFilter}
                  onChange={(event) => setRoleStatusFilter(event.target.value)}
                  aria-label="Filter by status"
                >
                  <option value="active">Active</option>
                  <option value="expired">Expired</option>
                  <option value="revoked">Revoked</option>
                  <option value="all">All</option>
                </select>
              </form>

              {visibleAssignments.length === 0 && (
                <p className="muted">No assignments match this view.</p>
              )}

              {visibleAssignments.length > 0 && (
                <div className="table-wrap">
                  <table className="table">
                    <thead>
                      <tr>
                        <th>Person</th>
                        <th>Role</th>
                        <th>Scope</th>
                        <th>Expires</th>
                        <th>Status</th>
                        <th />
                      </tr>
                    </thead>
                    <tbody>
                      {visibleAssignments.map((assignment) => {
                        const status = assignmentStatusOf(assignment)
                        const self = assignment.userId === session.userId
                        return (
                          <tr key={assignment.id}>
                            <td>
                              <div>{assignment.displayName ?? "—"}</div>
                              <div className="muted">{assignment.email}</div>
                            </td>
                            <td>
                              <div>{assignment.roleName}</div>
                              <div className="muted mono">
                                {assignment.roleKey}
                              </div>
                            </td>
                            <td>{scopeName(assignment)}</td>
                            <td>
                              {assignment.expiresAt
                                ? formatTime(assignment.expiresAt)
                                : "Never"}
                            </td>
                            <td>
                              <span className={assignmentStatusChip(status)}>
                                {status}
                              </span>
                            </td>
                            <td>
                              {self && status !== "revoked" ? (
                                <span className="muted">You</span>
                              ) : (
                                canManageRoles &&
                                status !== "revoked" && (
                                  <button
                                    type="button"
                                    className="button button-quiet button-small"
                                    onClick={() => handleRevokeRole(assignment)}
                                    disabled={busy}
                                  >
                                    Revoke
                                  </button>
                                )
                              )}
                            </td>
                          </tr>
                        )
                      })}
                    </tbody>
                  </table>
                </div>
              )}
            </section>
          </div>
        )}

        {knownPath && section === "cases" && !canReadCases && (
          <section className="panel">
            <h2>Cases</h2>
            <p className="muted">
              Your governance role does not include case access.
            </p>
          </section>
        )}

        {knownPath && section === "cases" && canReadCases && (
          <div className="dash-stack">
            {canWorkCases && (
              <section className="panel">
                <h2>Open a case</h2>
                <form className="form" onSubmit={handleCreateCase}>
                  <div className="form-row">
                    <label className="field">
                      <span>Type</span>
                      <select
                        name="caseType"
                        defaultValue="support"
                        disabled={busy}
                      >
                        <option value="support">Support</option>
                        <option value="complaint">Complaint</option>
                        <option value="dispute">Dispute</option>
                        <option value="investigation">Investigation</option>
                        <option value="incident">Incident</option>
                        <option value="verification_review">
                          Verification review
                        </option>
                        <option value="financial_exception">
                          Financial exception
                        </option>
                        <option value="security_incident">
                          Security incident
                        </option>
                        <option value="staff_conduct">Staff conduct</option>
                        <option value="partner_conduct">Partner conduct</option>
                      </select>
                    </label>
                    <label className="field">
                      <span>Title</span>
                      <input name="title" required disabled={busy} />
                    </label>
                    <label className="field">
                      <span>Priority</span>
                      <select
                        name="priority"
                        defaultValue="normal"
                        disabled={busy}
                      >
                        <option value="low">Low</option>
                        <option value="normal">Normal</option>
                        <option value="high">High</option>
                        <option value="urgent">Urgent</option>
                      </select>
                    </label>
                    <label className="field">
                      <span>Severity</span>
                      <select
                        name="severity"
                        defaultValue="medium"
                        disabled={busy}
                      >
                        <option value="low">Low</option>
                        <option value="medium">Medium</option>
                        <option value="high">High</option>
                        <option value="critical">Critical</option>
                      </select>
                    </label>
                    <label className="field">
                      <span>Queue</span>
                      <input name="queueKey" disabled={busy} />
                    </label>
                  </div>
                  <label className="field">
                    <span>Description</span>
                    <textarea name="description" rows={2} disabled={busy} />
                  </label>
                  <label className="field">
                    <span>Reason</span>
                    <input
                      name="reason"
                      minLength={3}
                      maxLength={500}
                      required
                      disabled={busy}
                    />
                  </label>
                  <button className="button" type="submit" disabled={busy}>
                    Open case
                  </button>
                </form>
              </section>
            )}

            <section className="panel">
              <div className="panel-head">
                <h2>Cases</h2>
                <span className="muted">
                  {cases === null ? "Loading…" : `${cases.length} shown`}
                </span>
              </div>
              <form
                className="user-toolbar"
                onSubmit={(event) => event.preventDefault()}
              >
                <input
                  className="search-input"
                  type="search"
                  placeholder="Search reference or title"
                  value={caseQuery}
                  onChange={(event) => setCaseQuery(event.target.value)}
                  aria-label="Search cases"
                />
                <select
                  className="filter-select"
                  value={caseStatusFilter}
                  onChange={(event) => setCaseStatusFilter(event.target.value)}
                  aria-label="Filter by status"
                >
                  <option value="">All statuses</option>
                  {[
                    "RECEIVED",
                    "TRIAGED",
                    "OPEN",
                    "INVESTIGATING",
                    "PENDING_INFORMATION",
                    "ESCALATED",
                    "REVIEW",
                    "DECIDED",
                    "ACTION_PENDING",
                    "CLOSED",
                    "REOPENED",
                    "ARCHIVED",
                  ].map((status) => (
                    <option key={status} value={status}>
                      {status}
                    </option>
                  ))}
                </select>
                <select
                  className="filter-select"
                  value={caseTypeFilter}
                  onChange={(event) => setCaseTypeFilter(event.target.value)}
                  aria-label="Filter by type"
                >
                  <option value="">All types</option>
                  {[
                    "support",
                    "complaint",
                    "dispute",
                    "investigation",
                    "incident",
                    "verification_review",
                    "financial_exception",
                    "security_incident",
                    "staff_conduct",
                    "partner_conduct",
                  ].map((type) => (
                    <option key={type} value={type}>
                      {type}
                    </option>
                  ))}
                </select>
              </form>

              {cases && cases.length === 0 && (
                <p className="muted">No cases match this view.</p>
              )}
              {cases && cases.length > 0 && (
                <div className="table-wrap">
                  <table className="table">
                    <thead>
                      <tr>
                        <th>Reference</th>
                        <th>Case</th>
                        <th>Priority</th>
                        <th>Status</th>
                        <th>Assignee</th>
                        <th />
                      </tr>
                    </thead>
                    <tbody>
                      {cases.map((entry) => (
                        <tr key={entry.id}>
                          <td className="mono">{entry.reference}</td>
                          <td>
                            <div>{entry.title}</div>
                            <div className="muted">{entry.caseType}</div>
                          </td>
                          <td>{entry.priority}</td>
                          <td>
                            <span className="chip">{entry.status}</span>
                          </td>
                          <td>
                            {entry.assigneeName ?? entry.assigneeEmail ?? "—"}
                          </td>
                          <td>
                            <button
                              type="button"
                              className="button button-quiet button-small"
                              onClick={() => setSelectedCase(entry)}
                            >
                              View
                            </button>
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              )}
            </section>

            {selectedCase && (
              <section className="panel">
                <div className="panel-head">
                  <h2>
                    {selectedCase.reference} · {selectedCase.title}
                  </h2>
                  <button
                    type="button"
                    className="button button-quiet button-small"
                    onClick={() => setSelectedCase(null)}
                  >
                    Close
                  </button>
                </div>
                <dl className="details">
                  <div>
                    <dt>Type</dt>
                    <dd>{selectedCase.caseType}</dd>
                  </div>
                  <div>
                    <dt>Status</dt>
                    <dd>{selectedCase.status}</dd>
                  </div>
                  <div>
                    <dt>Priority</dt>
                    <dd>
                      {selectedCase.priority} · {selectedCase.severity}
                    </dd>
                  </div>
                  <div>
                    <dt>Assignee</dt>
                    <dd>
                      {selectedCase.assigneeName ??
                        selectedCase.assigneeEmail ??
                        "Unassigned"}
                    </dd>
                  </div>
                </dl>
                {selectedCase.description && (
                  <p className="muted">{selectedCase.description}</p>
                )}

                {canWorkCases && (
                  <div className="account-actions">
                    <button
                      type="button"
                      className="button button-quiet button-small"
                      onClick={() => handleAssignCase(selectedCase)}
                      disabled={busy}
                    >
                      Assign
                    </button>
                    <button
                      type="button"
                      className="button button-quiet button-small"
                      onClick={() => handleCaseStatus(selectedCase)}
                      disabled={busy}
                    >
                      Change status
                    </button>
                    {selectedCase.status !== "DECIDED" && (
                      <button
                        type="button"
                        className="button button-small"
                        onClick={() => handleRequestCaseDecision(selectedCase)}
                        disabled={busy}
                      >
                        Request decision
                      </button>
                    )}
                  </div>
                )}

                <h3 className="section-title">Evidence</h3>
                <p className="muted">
                  Objects live in private storage. Only metadata and its hash
                  are recorded here; every access is written to the timeline.
                </p>
                {caseEvidence.length === 0 && (
                  <p className="muted">No evidence recorded.</p>
                )}
                {caseEvidence.length > 0 && (
                  <ul className="plain-list">
                    {caseEvidence.map((evidence) => (
                      <li key={evidence.id}>
                        <div>
                          {evidence.fileName}
                          <span className="muted">
                            {" "}
                            · {evidence.classification} · {evidence.status}
                          </span>
                        </div>
                        <div className="muted mono">
                          {evidence.sha256
                            ? evidence.sha256.slice(0, 16)
                            : "no hash"}
                        </div>
                        <div className="account-actions">
                          <button
                            type="button"
                            className="button button-quiet button-small"
                            onClick={() =>
                              handleEvidenceAccess(selectedCase, evidence)
                            }
                            disabled={busy}
                          >
                            Record access
                          </button>
                          {canWorkCases && evidence.status === "active" && (
                            <button
                              type="button"
                              className="button button-quiet button-small"
                              onClick={() =>
                                handleSupersedeEvidence(selectedCase, evidence)
                              }
                              disabled={busy}
                            >
                              Supersede
                            </button>
                          )}
                        </div>
                      </li>
                    ))}
                  </ul>
                )}
                {canWorkCases && (
                  <form
                    className="form"
                    onSubmit={(event) => handleAddEvidence(event, selectedCase)}
                  >
                    <div className="form-row">
                      <label className="field">
                        <span>Storage key</span>
                        <input name="storageKey" required disabled={busy} />
                      </label>
                      <label className="field">
                        <span>File name</span>
                        <input name="fileName" required disabled={busy} />
                      </label>
                      <label className="field">
                        <span>SHA-256 (optional)</span>
                        <input
                          name="sha256"
                          pattern="[0-9a-f]{64}"
                          disabled={busy}
                        />
                      </label>
                    </div>
                    <label className="field">
                      <span>Reason</span>
                      <input
                        name="reason"
                        minLength={3}
                        maxLength={500}
                        required
                        disabled={busy}
                      />
                    </label>
                    <button
                      className="button button-small"
                      type="submit"
                      disabled={busy}
                    >
                      Register evidence
                    </button>
                  </form>
                )}

                <h3 className="section-title">Timeline</h3>
                {caseEvents.length === 0 && (
                  <p className="muted">No events yet.</p>
                )}
                <ul className="plain-list">
                  {caseEvents.map((event) => (
                    <li key={event.id}>
                      <div>
                        <span className="mono">{event.eventType}</span> —{" "}
                        {event.summary}
                      </div>
                      <div className="muted">
                        {formatTime(event.occurredAt)} ·{" "}
                        {event.actorName ?? event.actorEmail ?? "system"}
                      </div>
                    </li>
                  ))}
                </ul>

                {canWorkCases && (
                  <form
                    className="form"
                    onSubmit={(event) => handleAddCaseNote(event, selectedCase)}
                  >
                    <label className="field">
                      <span>Add a note</span>
                      <textarea
                        name="summary"
                        rows={2}
                        minLength={3}
                        required
                        disabled={busy}
                      />
                    </label>
                    <button
                      className="button button-small"
                      type="submit"
                      disabled={busy}
                    >
                      Append note
                    </button>
                  </form>
                )}
              </section>
            )}
          </div>
        )}

        {knownPath && section === "verification" && !canReviewVerification && (
          <section className="panel">
            <h2>Verification</h2>
            <p className="muted">
              Your governance role does not include verification review.
            </p>
          </section>
        )}

        {knownPath && section === "verification" && canReviewVerification && (
          <section className="panel">
            <div className="panel-head">
              <h2>Verification queue</h2>
              <select
                className="filter-select"
                value={verificationStatus}
                onChange={(event) => setVerificationStatus(event.target.value)}
                aria-label="Filter verification reviews"
              >
                <option value="">All reviews</option>
                <option value="pending">Pending</option>
                <option value="information_requested">
                  Information requested
                </option>
                <option value="approved">Approved</option>
                <option value="rejected">Rejected</option>
              </select>
            </div>
            <p className="muted">
              Approval requires at least one active evidence record on the case.
              Every decision is recorded on the case timeline and audited.
            </p>
            {verification === null && <p className="muted">Loading…</p>}
            {verification && verification.length === 0 && (
              <p className="muted">No verification cases in this view.</p>
            )}
            {verification && verification.length > 0 && (
              <div className="table-wrap">
                <table className="table">
                  <thead>
                    <tr>
                      <th>Reference</th>
                      <th>Case</th>
                      <th>Lane</th>
                      <th>Review</th>
                      <th>Evidence</th>
                      <th />
                    </tr>
                  </thead>
                  <tbody>
                    {verification.map((entry) => (
                      <tr key={entry.caseId}>
                        <td className="mono">{entry.reference}</td>
                        <td>{entry.title}</td>
                        <td>{entry.lane}</td>
                        <td>
                          <span className="chip">{entry.reviewStatus}</span>
                        </td>
                        <td>{entry.evidenceCount}</td>
                        <td>
                          <div className="account-actions">
                            <button
                              type="button"
                              className="button button-small"
                              onClick={() =>
                                handleVerificationDecision(entry, "approve")
                              }
                              disabled={busy}
                            >
                              Approve
                            </button>
                            <button
                              type="button"
                              className="button button-quiet button-small"
                              onClick={() =>
                                handleVerificationDecision(
                                  entry,
                                  "request_information",
                                )
                              }
                              disabled={busy}
                            >
                              Request info
                            </button>
                            <button
                              type="button"
                              className="button button-danger button-small"
                              onClick={() =>
                                handleVerificationDecision(entry, "reject")
                              }
                              disabled={busy}
                            >
                              Reject
                            </button>
                          </div>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
          </section>
        )}

        {knownPath && section === "partners" && !canReadPartners && (
          <section className="panel">
            <h2>Partners</h2>
            <p className="muted">
              Your governance role does not include partner administration.
            </p>
          </section>
        )}

        {knownPath && section === "partners" && canReadPartners && (
          <div className="dash-stack">
            {canManagePartners && (
              <section className="panel">
                <h2>Register a partner</h2>
                <form className="form" onSubmit={handleCreatePartner}>
                  <div className="form-row">
                    <label className="field">
                      <span>Legal name</span>
                      <input name="legalName" required disabled={busy} />
                    </label>
                    <label className="field">
                      <span>Trading name</span>
                      <input name="tradingName" disabled={busy} />
                    </label>
                    <label className="field">
                      <span>Category</span>
                      <input name="category" disabled={busy} />
                    </label>
                    <label className="field">
                      <span>Country</span>
                      <input name="country" disabled={busy} />
                    </label>
                  </div>
                  <label className="field">
                    <span>Reason</span>
                    <input
                      name="reason"
                      minLength={3}
                      maxLength={500}
                      required
                      disabled={busy}
                    />
                  </label>
                  <button className="button" type="submit" disabled={busy}>
                    Register
                  </button>
                </form>
              </section>
            )}

            <section className="panel">
              <div className="panel-head">
                <h2>Partner organisations</h2>
                <span className="muted">
                  {partners === null
                    ? "Loading…"
                    : `${partners.length} registered`}
                </span>
              </div>
              {partners && partners.length === 0 && (
                <p className="muted">No partner organisations yet.</p>
              )}
              {partners && partners.length > 0 && (
                <div className="table-wrap">
                  <table className="table">
                    <thead>
                      <tr>
                        <th>Organisation</th>
                        <th>Status</th>
                        <th>Representatives</th>
                        <th>Agreements</th>
                        <th />
                      </tr>
                    </thead>
                    <tbody>
                      {partners.map((partner) => (
                        <tr key={partner.id}>
                          <td>
                            <div>{partner.legalName}</div>
                            <div className="muted">
                              {partner.tradingName ?? partner.category ?? "—"}
                            </div>
                          </td>
                          <td>
                            <span className="chip">{partner.status}</span>
                          </td>
                          <td>{partner.representatives}</td>
                          <td>{partner.agreements}</td>
                          <td>
                            <button
                              type="button"
                              className="button button-quiet button-small"
                              onClick={() => setSelectedPartner(partner)}
                            >
                              View
                            </button>
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              )}
            </section>

            {selectedPartner && (
              <section className="panel">
                <div className="panel-head">
                  <h2>{selectedPartner.legalName}</h2>
                  <button
                    type="button"
                    className="button button-quiet button-small"
                    onClick={() => setSelectedPartner(null)}
                  >
                    Close
                  </button>
                </div>
                <dl className="details">
                  <div>
                    <dt>Status</dt>
                    <dd>{selectedPartner.status}</dd>
                  </div>
                  <div>
                    <dt>Category</dt>
                    <dd>{selectedPartner.category ?? "—"}</dd>
                  </div>
                  <div>
                    <dt>Country</dt>
                    <dd>{selectedPartner.country ?? "—"}</dd>
                  </div>
                  <div>
                    <dt>Registered</dt>
                    <dd>{formatTime(selectedPartner.createdAt)}</dd>
                  </div>
                </dl>

                {canManagePartners && (
                  <div className="account-actions">
                    {selectedPartner.status !== "active" &&
                      selectedPartner.status !== "terminated" && (
                        <button
                          type="button"
                          className="button button-small"
                          onClick={() =>
                            handlePartnerStatus(selectedPartner, "active")
                          }
                          disabled={busy}
                        >
                          Activate
                        </button>
                      )}
                    {selectedPartner.status === "active" && (
                      <button
                        type="button"
                        className="button button-quiet button-small"
                        onClick={() =>
                          handlePartnerStatus(selectedPartner, "suspended")
                        }
                        disabled={busy}
                      >
                        Suspend
                      </button>
                    )}
                    {selectedPartner.status !== "terminated" && (
                      <button
                        type="button"
                        className="button button-danger button-small"
                        onClick={() =>
                          handlePartnerStatus(selectedPartner, "terminated")
                        }
                        disabled={busy}
                      >
                        Terminate
                      </button>
                    )}
                  </div>
                )}

                <h3 className="section-title">Representatives</h3>
                {partnerReps.length === 0 && (
                  <p className="muted">No representatives yet.</p>
                )}
                {partnerReps.length > 0 && (
                  <ul className="plain-list">
                    {partnerReps.map((rep) => (
                      <li key={rep.id}>
                        <div>
                          {rep.displayName ?? rep.email}
                          {rep.effectiveTo ? " (ended)" : ""}
                        </div>
                        <div className="muted">
                          {rep.email} · {rep.role}
                        </div>
                      </li>
                    ))}
                  </ul>
                )}
                {canManagePartners &&
                  selectedPartner.status !== "terminated" && (
                    <form
                      className="form"
                      onSubmit={(event) =>
                        handleAddPartnerRepresentative(event, selectedPartner)
                      }
                    >
                      <div className="form-row">
                        <label className="field">
                          <span>Account email</span>
                          <input
                            name="email"
                            type="email"
                            required
                            disabled={busy}
                          />
                        </label>
                        <label className="field">
                          <span>Role</span>
                          <select
                            name="role"
                            defaultValue="member"
                            disabled={busy}
                          >
                            <option value="owner">Owner</option>
                            <option value="admin">Admin</option>
                            <option value="member">Member</option>
                            <option value="viewer">Viewer</option>
                          </select>
                        </label>
                      </div>
                      <label className="field">
                        <span>Reason</span>
                        <input
                          name="reason"
                          minLength={3}
                          maxLength={500}
                          required
                          disabled={busy}
                        />
                      </label>
                      <button
                        className="button button-small"
                        type="submit"
                        disabled={busy}
                      >
                        Add representative
                      </button>
                    </form>
                  )}
              </section>
            )}
          </div>
        )}

        {knownPath && section === "approvals" && !canReadApprovals && (
          <section className="panel">
            <h2>Approvals</h2>
            <p className="muted">
              Your governance role does not include approvals.
            </p>
          </section>
        )}

        {knownPath && section === "approvals" && canReadApprovals && (
          <section className="panel">
            <div className="panel-head">
              <h2>Approvals</h2>
              <span className="muted">
                {approvals === null
                  ? "Loading…"
                  : `${approvals.filter((entry) => entry.status === "pending").length} pending`}
              </span>
            </div>
            <p className="muted">
              A request is decided by someone other than the person who raised
              it.
            </p>
            {approvals && approvals.length === 0 && (
              <p className="muted">No approval requests.</p>
            )}
            {approvals && approvals.length > 0 && (
              <div className="table-wrap">
                <table className="table">
                  <thead>
                    <tr>
                      <th>Reference</th>
                      <th>Action</th>
                      <th>Target</th>
                      <th>Requested by</th>
                      <th>Reason</th>
                      <th>Status</th>
                      <th />
                    </tr>
                  </thead>
                  <tbody>
                    {approvals.map((entry) => (
                      <tr key={entry.id}>
                        <td className="mono">{entry.reference}</td>
                        <td>{entry.actionType}</td>
                        <td className="mono">{entry.targetId.slice(0, 8)}</td>
                        <td>
                          <div>{entry.requesterName ?? "—"}</div>
                          <div className="muted">{entry.requesterEmail}</div>
                        </td>
                        <td>{entry.reason}</td>
                        <td>
                          <span className={approvalStatusChip(entry.status)}>
                            {entry.status}
                          </span>
                        </td>
                        <td>
                          {entry.requesterUserId === session.userId ? (
                            <span className="muted">You</span>
                          ) : (
                            canDecideApprovals &&
                            entry.status === "pending" && (
                              <div className="account-actions">
                                <button
                                  type="button"
                                  className="button button-small"
                                  onClick={() =>
                                    handleDecideApproval(entry, "approve")
                                  }
                                  disabled={busy}
                                >
                                  Approve
                                </button>
                                <button
                                  type="button"
                                  className="button button-quiet button-small"
                                  onClick={() =>
                                    handleDecideApproval(entry, "reject")
                                  }
                                  disabled={busy}
                                >
                                  Reject
                                </button>
                              </div>
                            )
                          )}
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
          </section>
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
