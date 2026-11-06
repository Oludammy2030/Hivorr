#!/usr/bin/env node
// Verify that a protected-branch push is associated with a merged pull request.
//
// This is a CI-side detection control. GitHub Free does not allow server-side
// branch protection on a private repository, so a direct push can still land.
// This job fails such a push and blocks every deployment job that depends on it.
//
// Required environment:
//   GITHUB_REPOSITORY, GITHUB_SHA, GITHUB_REF_NAME, GITHUB_TOKEN

const repository = process.env.GITHUB_REPOSITORY
const sha = process.env.GITHUB_SHA
const branch = process.env.GITHUB_REF_NAME
const token = process.env.GITHUB_TOKEN

if (!repository || !sha || !branch || !token) {
  console.error(
    "verify-pr-merge: missing GITHUB_REPOSITORY, GITHUB_SHA, GITHUB_REF_NAME or GITHUB_TOKEN",
  )
  process.exit(2)
}

const api = `https://api.github.com/repos/${repository}`

async function getJson(path) {
  const response = await fetch(`${api}${path}`, {
    headers: {
      Authorization: `Bearer ${token}`,
      Accept: "application/vnd.github+json",
      "User-Agent": "hivorr-branch-guard",
      "X-GitHub-Api-Version": "2022-11-28",
    },
  })
  if (!response.ok) {
    throw new Error(`${path}: HTTP ${response.status} ${await response.text()}`)
  }
  return response.json()
}

function isMergedIntoBranch(pr) {
  return Boolean(pr.merged_at) && pr.base?.ref === branch
}

try {
  // Check the pushed commit itself. Do not walk parents: a new direct commit
  // on top of a merged PR would otherwise inherit that PR's association.
  const pulls = await getJson(`/commits/${sha}/pulls`)
  const merged = (pulls || []).find(isMergedIntoBranch)
  if (merged) {
    console.log(
      `verify-pr-merge: OK - ${branch} push ${sha.slice(0, 7)} is linked to merged PR #${merged.number}`,
    )
    console.log(`verify-pr-merge: ${merged.html_url}`)
    process.exit(0)
  }

  console.error(
    `verify-pr-merge: BLOCKED - ${branch} push ${sha.slice(0, 7)} has no merged pull request into ${branch}.`,
  )
  console.error(
    "Protected branches accept changes through pull requests only. See documents/Engineering-Execution/BRANCH_PROTECTION.md.",
  )
  process.exit(1)
} catch (error) {
  console.error(
    `verify-pr-merge: ERROR - ${
      error instanceof Error ? error.message : String(error)
    }`,
  )
  process.exit(2)
}
