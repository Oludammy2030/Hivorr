import { useEffect, useState, type FormEvent } from "react"

import {
  api,
  errorMessage,
  type Department,
  type StaffInvite,
  type StaffMember,
} from "./api"
import { staffInviteLink } from "./portal-links"

interface StaffPageProps {
  canManage: boolean
}

function statusClass(status: string): string {
  if (status === "active") return "chip chip-ok"
  if (status === "suspended" || status === "offboarded") {
    return "chip chip-danger"
  }
  return "chip"
}

export function StaffPage({ canManage }: StaffPageProps) {
  const [members, setMembers] = useState<readonly StaffMember[] | null>(null)
  const [departments, setDepartments] = useState<readonly Department[]>([])
  const [search, setSearch] = useState("")
  const [query, setQuery] = useState("")
  const [status, setStatus] = useState("")
  const [selected, setSelected] = useState<StaffMember | null>(null)
  const [reason, setReason] = useState("")
  const [departmentKey, setDepartmentKey] = useState("")
  const [invite, setInvite] = useState<StaffInvite | null>(null)
  const [inviteEmail, setInviteEmail] = useState("")
  const [inviteDepartment, setInviteDepartment] = useState("")
  const [inviteJobTitle, setInviteJobTitle] = useState("")
  const [inviteReason, setInviteReason] = useState("")
  const [attachEmail, setAttachEmail] = useState("")
  const [attachDepartment, setAttachDepartment] = useState("")
  const [attachJobTitle, setAttachJobTitle] = useState("")
  const [attachReason, setAttachReason] = useState("")
  const [attached, setAttached] = useState<string | null>(null)
  const [error, setError] = useState<string | undefined>()
  const [busy, setBusy] = useState(false)

  useEffect(() => {
    let active = true
    api
      .listDepartments()
      .then((value) => {
        if (active) setDepartments(value)
      })
      .catch((value: unknown) => {
        if (active) setError(errorMessage(value))
      })
    return () => {
      active = false
    }
  }, [])

  useEffect(() => {
    let active = true
    setBusy(true)
    api
      .listStaff(query, status)
      .then((value) => {
        if (!active) return
        setMembers(value)
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
  }, [query, status])

  async function reload(selectUserId?: string) {
    const value = await api.listStaff(query, status)
    setMembers(value)
    if (selectUserId) {
      setSelected(
        value.find((member) => member.userId === selectUserId) ?? null,
      )
    }
  }

  async function handleSearch(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    setSelected(null)
    setQuery(search)
  }

  async function handleInvite(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    setError(undefined)
    setBusy(true)
    try {
      const created = await api.inviteStaff({
        email: inviteEmail,
        ...(inviteDepartment ? { departmentKey: inviteDepartment } : {}),
        ...(inviteJobTitle.trim() ? { jobTitle: inviteJobTitle.trim() } : {}),
        reason: inviteReason,
      })
      setInvite(created)
      setInviteEmail("")
      setInviteDepartment("")
      setInviteJobTitle("")
      setInviteReason("")
    } catch (value) {
      setError(errorMessage(value))
    } finally {
      setBusy(false)
    }
  }

  async function handleAttach(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    setError(undefined)
    setAttached(null)
    setBusy(true)
    try {
      const created = await api.attachStaffProfile({
        email: attachEmail,
        ...(attachDepartment ? { departmentKey: attachDepartment } : {}),
        ...(attachJobTitle.trim() ? { jobTitle: attachJobTitle.trim() } : {}),
        reason: attachReason,
      })
      setAttached(`${created.email} is now a staff member.`)
      setAttachEmail("")
      setAttachDepartment("")
      setAttachJobTitle("")
      setAttachReason("")
      await reload(created.userId)
    } catch (value) {
      setError(errorMessage(value))
    } finally {
      setBusy(false)
    }
  }

  async function handleAction(action: "suspend" | "reactivate" | "offboard") {
    if (!selected) return
    if (reason.trim().length < 5) {
      setError("Enter a reason of at least 5 characters.")
      return
    }
    setError(undefined)
    setBusy(true)
    try {
      await api.setStaffStatus(selected.userId, action, reason.trim())
      setReason("")
      await reload(selected.userId)
    } catch (value) {
      setError(errorMessage(value))
    } finally {
      setBusy(false)
    }
  }

  async function handleDepartment() {
    if (!selected || !departmentKey) return
    if (reason.trim().length < 5) {
      setError("Enter a reason of at least 5 characters.")
      return
    }
    setError(undefined)
    setBusy(true)
    try {
      await api.setStaffDepartment(
        selected.userId,
        departmentKey,
        reason.trim(),
      )
      setReason("")
      await reload(selected.userId)
    } catch (value) {
      setError(errorMessage(value))
    } finally {
      setBusy(false)
    }
  }

  const inviteLink = invite
    ? staffInviteLink(window.location, invite.token)
    : null

  return (
    <div className="dash-stack">
      {error && (
        <p className="error" role="alert">
          {error}
        </p>
      )}

      <section className="panel">
        <form className="user-toolbar" onSubmit={handleSearch}>
          <input
            className="search-input"
            type="search"
            placeholder="Search by email, name or job title"
            value={search}
            onChange={(event) => setSearch(event.target.value)}
            aria-label="Search staff"
          />
          <select
            className="filter-select"
            value={status}
            onChange={(event) => {
              setSelected(null)
              setStatus(event.target.value)
            }}
            aria-label="Filter staff by engagement status"
          >
            <option value="">All statuses</option>
            <option value="active">Active</option>
            <option value="invited">Invited</option>
            <option value="suspended">Suspended</option>
            <option value="leave">On leave</option>
            <option value="offboarded">Offboarded</option>
          </select>
          <button className="button button-small" type="submit" disabled={busy}>
            Search
          </button>
        </form>
      </section>

      {canManage && (
        <section className="panel">
          <h2>Invite a staff member</h2>
          <form className="form" onSubmit={handleInvite}>
            <div className="form-row">
              <label className="field">
                <span>Work email</span>
                <input
                  type="email"
                  required
                  value={inviteEmail}
                  onChange={(event) => setInviteEmail(event.target.value)}
                  disabled={busy}
                />
              </label>
              <label className="field">
                <span>Department</span>
                <select
                  value={inviteDepartment}
                  onChange={(event) => setInviteDepartment(event.target.value)}
                  disabled={busy}
                >
                  <option value="">Unassigned</option>
                  {departments.map((department) => (
                    <option key={department.key} value={department.key}>
                      {department.name}
                    </option>
                  ))}
                </select>
              </label>
              <label className="field">
                <span>Job title</span>
                <input
                  type="text"
                  value={inviteJobTitle}
                  onChange={(event) => setInviteJobTitle(event.target.value)}
                  disabled={busy}
                />
              </label>
            </div>
            <label className="field">
              <span>Reason</span>
              <input
                type="text"
                required
                minLength={5}
                value={inviteReason}
                onChange={(event) => setInviteReason(event.target.value)}
                placeholder="Why this person is joining"
                disabled={busy}
              />
            </label>
            <button className="button" type="submit" disabled={busy}>
              {busy ? "Creating…" : "Create invitation"}
            </button>
          </form>

          {invite && inviteLink && (
            <div className="invite-result">
              <p className="ok">
                {invite.emailSent
                  ? `Invitation email sent to ${invite.email}.`
                  : `Invitation created for ${invite.email}. Email delivery is not configured, so send this single-use link within 7 days:`}
              </p>
              <p className="invite-link mono">{inviteLink}</p>
              <button
                type="button"
                className="button button-quiet button-small"
                onClick={() => navigator.clipboard?.writeText(inviteLink)}
              >
                Copy link
              </button>
            </div>
          )}
        </section>
      )}

      {canManage && (
        <details className="panel">
          <summary>Add an existing account as staff</summary>
          <p className="muted attach-intro">
            Use this when the person already signed up at the main portal and
            should not receive a new-account invitation.
          </p>
          <form className="form" onSubmit={handleAttach}>
            <div className="form-row">
              <label className="field">
                <span>Account email</span>
                <input
                  type="email"
                  required
                  value={attachEmail}
                  onChange={(event) => setAttachEmail(event.target.value)}
                  disabled={busy}
                />
              </label>
              <label className="field">
                <span>Department</span>
                <select
                  value={attachDepartment}
                  onChange={(event) => setAttachDepartment(event.target.value)}
                  disabled={busy}
                >
                  <option value="">Unassigned</option>
                  {departments.map((department) => (
                    <option key={department.key} value={department.key}>
                      {department.name}
                    </option>
                  ))}
                </select>
              </label>
              <label className="field">
                <span>Job title</span>
                <input
                  type="text"
                  value={attachJobTitle}
                  onChange={(event) => setAttachJobTitle(event.target.value)}
                  disabled={busy}
                />
              </label>
            </div>
            <label className="field">
              <span>Reason</span>
              <input
                type="text"
                required
                minLength={5}
                value={attachReason}
                onChange={(event) => setAttachReason(event.target.value)}
                placeholder="Why this account is joining staff"
                disabled={busy}
              />
            </label>
            <button className="button" type="submit" disabled={busy}>
              {busy ? "Adding…" : "Add as staff"}
            </button>
          </form>

          {attached && <p className="ok attach-result">{attached}</p>}
        </details>
      )}

      <section className="panel">
        <div className="panel-head">
          <h2>Staff</h2>
          <span className="muted">
            {members === null ? "Loading…" : `${members.length} shown`}
          </span>
        </div>

        {members && members.length === 0 && (
          <p className="muted">
            No staff records match this filter. Invite someone new, or add an
            existing account as staff.
          </p>
        )}

        {members && members.length > 0 && (
          <div className="table-wrap">
            <table className="table">
              <thead>
                <tr>
                  <th>Email</th>
                  <th>Name</th>
                  <th>Job title</th>
                  <th>Department</th>
                  <th>Status</th>
                  <th>Authenticator</th>
                </tr>
              </thead>
              <tbody>
                {members.map((member) => (
                  <tr
                    key={member.id}
                    className={selected?.id === member.id ? "is-selected" : ""}
                    onClick={() => {
                      setSelected(member)
                      setDepartmentKey(member.departmentKey ?? "")
                      setReason("")
                    }}
                  >
                    <td>{member.email}</td>
                    <td>{member.displayName ?? "—"}</td>
                    <td>{member.jobTitle ?? "—"}</td>
                    <td>{member.departmentName ?? "Unassigned"}</td>
                    <td>
                      <span className={statusClass(member.engagementStatus)}>
                        {member.engagementStatus}
                      </span>
                    </td>
                    <td>
                      {member.confirmedFactors > 0 ? "Enabled" : "Not set"}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </section>

      {selected && (
        <section className="panel">
          <div className="panel-head">
            <h2>{selected.email}</h2>
            <button
              type="button"
              className="button button-quiet button-small"
              onClick={() => setSelected(null)}
            >
              Close
            </button>
          </div>

          <dl className="details">
            <div>
              <dt>Name</dt>
              <dd>{selected.displayName ?? "—"}</dd>
            </div>
            <div>
              <dt>Status</dt>
              <dd>{selected.engagementStatus}</dd>
            </div>
            <div>
              <dt>Department</dt>
              <dd>{selected.departmentName ?? "Unassigned"}</dd>
            </div>
            <div>
              <dt>Started</dt>
              <dd>{selected.startedOn ?? "—"}</dd>
            </div>
            <div>
              <dt>Authenticator</dt>
              <dd>{selected.confirmedFactors} confirmed</dd>
            </div>
          </dl>

          {canManage && (
            <div className="staff-actions">
              <label className="field">
                <span>Reason for this change</span>
                <input
                  type="text"
                  minLength={5}
                  value={reason}
                  onChange={(event) => setReason(event.target.value)}
                  placeholder="Required, at least 5 characters"
                  disabled={busy}
                />
              </label>

              <div className="staff-action-buttons">
                {selected.engagementStatus === "active" && (
                  <button
                    type="button"
                    className="button button-quiet button-small"
                    onClick={() => handleAction("suspend")}
                    disabled={busy}
                  >
                    Suspend
                  </button>
                )}
                {(selected.engagementStatus === "suspended" ||
                  selected.engagementStatus === "leave") && (
                  <button
                    type="button"
                    className="button button-small"
                    onClick={() => handleAction("reactivate")}
                    disabled={busy}
                  >
                    Reactivate
                  </button>
                )}
                {selected.engagementStatus !== "offboarded" && (
                  <button
                    type="button"
                    className="button button-danger button-small"
                    onClick={() => handleAction("offboard")}
                    disabled={busy}
                  >
                    Offboard
                  </button>
                )}
              </div>

              {selected.engagementStatus !== "offboarded" && (
                <div className="staff-department">
                  <label className="field">
                    <span>Move to department</span>
                    <select
                      value={departmentKey}
                      onChange={(event) => setDepartmentKey(event.target.value)}
                      disabled={busy}
                    >
                      <option value="">Unassigned</option>
                      {departments.map((department) => (
                        <option key={department.key} value={department.key}>
                          {department.name}
                        </option>
                      ))}
                    </select>
                  </label>
                  <button
                    type="button"
                    className="button button-quiet button-small"
                    onClick={handleDepartment}
                    disabled={busy || !departmentKey}
                  >
                    Assign department
                  </button>
                </div>
              )}

              <p className="hint">
                Offboarding revokes sessions, grants, role assignments and
                department membership immediately. The record and audit history
                are retained.
              </p>
            </div>
          )}
        </section>
      )}
    </div>
  )
}
