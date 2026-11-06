// Pure push-policy helpers.
//
// Kept free of git and process access so the decision logic can be unit-tested
// and reused by the local pre-push hook.

const ZERO_SHA = /^0+$/

export function parsePushInput(text) {
  const entries = []
  for (const rawLine of String(text).split(/\r?\n/)) {
    const line = rawLine.trim()
    if (!line) continue
    const [localRef, localSha, remoteRef, remoteSha] = line.split(/\s+/)
    if (!localRef || !localSha || !remoteRef || remoteSha === undefined) {
      throw new Error(`Malformed pre-push input line: ${line}`)
    }
    entries.push({ localRef, localSha, remoteRef, remoteSha })
  }
  return entries
}

export function protectedBranchOf(remoteRef, protectedBranches) {
  if (!remoteRef || !remoteRef.startsWith("refs/heads/")) return null
  const branch = remoteRef.slice("refs/heads/".length)
  return protectedBranches.includes(branch) ? branch : null
}

export function evaluatePush(entries, protectedBranches, isAncestor) {
  const violations = []

  for (const entry of entries) {
    const branch = protectedBranchOf(entry.remoteRef, protectedBranches)
    if (!branch) continue

    if (ZERO_SHA.test(entry.localSha)) {
      violations.push({ branch, kind: "delete", entry })
      continue
    }

    if (ZERO_SHA.test(entry.remoteSha)) {
      violations.push({ branch, kind: "create", entry })
      continue
    }

    if (!isAncestor(entry.remoteSha, entry.localSha)) {
      violations.push({ branch, kind: "non-fast-forward", entry })
      continue
    }

    violations.push({ branch, kind: "direct-push", entry })
  }

  return violations
}

export function formatViolations(violations, config) {
  const lines = ["pre-push: BLOCKED - direct update to a protected branch.", ""]
  for (const violation of violations) {
    lines.push(`  ${violation.branch}: ${violation.kind}`)
  }
  lines.push(
    "",
    "Protected branches are updated through pull requests only:",
    `  ${config.flow}`,
    "",
    "Push your work to a feature branch instead:",
    "  git push origin HEAD:refs/heads/feature/<short-name>",
    "",
    "If you believe this is an emergency, do not bypass the hook. Ask the",
    "founder/architect to record the exception and use the GitHub UI merge path.",
    "See documents/Engineering-Execution/BRANCH_PROTECTION.md.",
  )
  return lines.join("\n")
}
