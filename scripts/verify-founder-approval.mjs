#!/usr/bin/env node
// Verify founder approval for a production release.
//
// Finds the open or closed Issue labelled `release-candidate` that references
// the requested commit, then requires a comment from the founder account whose
// first line is exactly `/approve-release <release-sha>`.
//
// Required environment:
//   GITHUB_TOKEN, GITHUB_REPOSITORY, RELEASE_SHA, FOUNDER_GITHUB_LOGIN
//
// Optional:
//   RELEASE_ISSUE_NUMBER — verify one issue instead of searching

import {
  RELEASE_CANDIDATE_LABEL,
  evaluateFounderApproval,
} from "./lib/founder-approval.mjs"

const token = process.env.GITHUB_TOKEN
const repository = process.env.GITHUB_REPOSITORY
const releaseSha = process.env.RELEASE_SHA
const founderLogin = process.env.FOUNDER_GITHUB_LOGIN
const issueNumber = process.env.RELEASE_ISSUE_NUMBER

if (!token || !repository || !releaseSha || !founderLogin) {
  console.error(
    "verify-founder-approval: missing GITHUB_TOKEN, GITHUB_REPOSITORY, RELEASE_SHA or FOUNDER_GITHUB_LOGIN",
  )
  process.exit(2)
}

const api = `https://api.github.com/repos/${repository}`

async function getJson(path) {
  const response = await fetch(`${api}${path}`, {
    headers: {
      Authorization: `Bearer ${token}`,
      Accept: "application/vnd.github+json",
      "User-Agent": "hivorr-release-approval",
      "X-GitHub-Api-Version": "2022-11-28",
    },
  })
  if (!response.ok) {
    throw new Error(`${path}: HTTP ${response.status} ${await response.text()}`)
  }
  return response.json()
}

try {
  let issue
  if (issueNumber) {
    issue = await getJson(`/issues/${issueNumber}`)
  } else {
    const issues = await getJson(
      `/issues?labels=${encodeURIComponent(RELEASE_CANDIDATE_LABEL)}&state=all&per_page=100`,
    )
    issue = (issues || []).find(
      (candidate) =>
        !candidate.pull_request &&
        String(candidate.body ?? "").includes(releaseSha),
    )
  }

  const comments = issue
    ? await getJson(`/issues/${issue.number}/comments?per_page=100`)
    : []

  const result = evaluateFounderApproval({
    issue,
    comments,
    founderLogin,
    releaseSha,
  })

  if (!result.ok) {
    console.error("verify-founder-approval: REFUSED")
    for (const issue of result.issues) console.error(`- ${issue}`)
    process.exit(1)
  }

  console.log(
    `verify-founder-approval: OK — issue #${result.approval.issueNumber}, founder ${result.approval.login}, release ${releaseSha}`,
  )
  console.log(
    `verify-founder-approval: comment ${result.approval.commentId} at ${result.approval.createdAt}`,
  )
} catch (error) {
  console.error(
    `verify-founder-approval: ERROR — ${
      error instanceof Error ? error.message : String(error)
    }`,
  )
  process.exit(2)
}
