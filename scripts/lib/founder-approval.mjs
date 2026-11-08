/**
 * Founder release-approval policy.
 *
 * Production promotion is authorised by one thing only: a comment on an Issue
 * labelled `release-candidate` from the configured founder account, containing
 * exactly `/approve-release <release-sha>` on its own first line. A different
 * SHA, another author, edit-only approval, or an unlabelled issue is a refusal.
 *
 * Kept free of network and process access so the decision logic can be tested.
 */

export const RELEASE_CANDIDATE_LABEL = "release-candidate"
export const APPROVAL_COMMAND = "/approve-release"
const APPROVAL_PATTERN = /^\/approve-release\s+([0-9a-f]{40})$/
const SHA_PATTERN = /^[0-9a-f]{40}$/

/** The approval SHA from a comment body, or null when it is not the command. */
export function parseApprovalCommand(body) {
  if (typeof body !== "string") return null
  const firstLine = body.trim().split(/\r?\n/, 1)[0].trim()
  const match = APPROVAL_PATTERN.exec(firstLine)
  return match ? match[1] : null
}

function labelNames(issue) {
  return (issue?.labels ?? []).map((label) =>
    (typeof label === "string" ? label : (label?.name ?? "")).toLowerCase(),
  )
}

function commentTime(comment) {
  const time = Date.parse(comment?.created_at ?? "")
  return Number.isFinite(time) ? time : 0
}

/**
 * Decide whether an issue and its comments authorise this exact release.
 *
 * The latest founder approval command wins. A founder commenting a new SHA
 * therefore supersedes an earlier approval, and a later approval for a
 * different SHA blocks promotion of the requested one.
 *
 * @returns {{ ok: boolean, issues: string[], approval: object | null }}
 */
export function evaluateFounderApproval(input) {
  const { issue, comments, founderLogin, releaseSha } = input ?? {}
  const issues = []

  if (!SHA_PATTERN.test(releaseSha ?? "")) {
    issues.push("releaseSha must be a 40-character lowercase hex commit SHA")
  }
  if (!founderLogin) {
    issues.push("the founder GitHub login is not configured")
  }
  if (!issue) {
    issues.push(
      `no issue labelled ${RELEASE_CANDIDATE_LABEL} was found for this release`,
    )
    return { ok: false, issues, approval: null }
  }
  if (issue.pull_request) {
    issues.push("the release candidate is a pull request, not a release issue")
  }

  const labels = labelNames(issue)
  if (!labels.includes(RELEASE_CANDIDATE_LABEL)) {
    issues.push(`the issue does not carry the ${RELEASE_CANDIDATE_LABEL} label`)
  }
  if (!String(issue.body ?? "").includes(releaseSha ?? "")) {
    issues.push("the issue body does not reference the requested release SHA")
  }

  const founder = String(founderLogin ?? "").toLowerCase()
  const founderComments = (comments ?? [])
    .filter(
      (comment) => String(comment?.user?.login ?? "").toLowerCase() === founder,
    )
    .sort((a, b) => {
      const delta = commentTime(a) - commentTime(b)
      if (delta !== 0) return delta
      return Number(a?.id ?? 0) - Number(b?.id ?? 0)
    })

  const commands = founderComments
    .map((comment) => ({
      comment,
      sha: parseApprovalCommand(comment.body),
    }))
    .filter((entry) => entry.sha !== null)

  const latest = commands.at(-1)
  if (!latest) {
    issues.push(
      `the founder has not commented ${APPROVAL_COMMAND} <release-sha> on this issue`,
    )
    return { ok: false, issues, approval: null }
  }

  const approval = {
    issueNumber: issue.number,
    commentId: latest.comment.id,
    login: latest.comment.user?.login ?? null,
    sha: latest.sha,
    createdAt: latest.comment.created_at ?? null,
  }

  if (latest.sha !== releaseSha) {
    issues.push(
      `the latest founder approval is for ${latest.sha}, not the requested ${releaseSha}`,
    )
  }

  return { ok: issues.length === 0, issues, approval }
}
