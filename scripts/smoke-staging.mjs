#!/usr/bin/env node
// Post-deploy staging smoke (EP-01-063).
//
// Proves the deployed artifact, not the local build:
//   - the API answers health and reports the expected release;
//   - readiness answers (503 is the current honest state);
//   - the session and activity routes exist and deny anonymously;
//   - sign-in exists and rejects an invalid body without a 5xx;
//   - all four hosts serve, with Access on the privileged three.
//
// It never sends a credential and never prints a token. Run it from the
// promotion workflow or by hand:
//   node scripts/smoke-staging.mjs --base https://staging.hivorr.com \
//     --expect-sha <40-hex>

import { readFileSync } from "node:fs"
import path from "node:path"

const args = process.argv.slice(2)
function flag(name, fallback) {
  const index = args.indexOf(name)
  return index >= 0 && args[index + 1] ? args[index + 1] : fallback
}

const base = flag("--base", "https://staging.hivorr.com").replace(/\/+$/, "")
const expectSha = flag("--expect-sha", "")
const topology = JSON.parse(
  readFileSync(path.resolve("config/environments.json"), "utf8"),
)
const hosts = topology.environments.staging.hosts
const protectedApplications = ["control", "staff", "partner"]
const failures = []

function pass(message) {
  console.log(`PASS  ${message}`)
}
function fail(message) {
  failures.push(message)
  console.error(`FAIL  ${message}`)
}

async function request(url, init) {
  let lastError
  for (let attempt = 1; attempt <= 3; attempt += 1) {
    try {
      const response = await fetch(url, {
        redirect: "manual",
        ...init,
        headers: {
          "user-agent": "hivorr-staging-smoke",
          ...(init?.headers ?? {}),
        },
      })
      let body = null
      const type = response.headers.get("content-type") ?? ""
      if (type.includes("application/json"))
        body = await response.json().catch(() => null)
      return { response, body }
    } catch (error) {
      lastError = error
      if (attempt < 3)
        await new Promise((resolve) => setTimeout(resolve, 1_500))
    }
  }
  throw lastError
}

// Health and release identity.
try {
  const { response, body } = await request(`${base}/api/v1/health/live`)
  if (response.status !== 200) fail(`health/live returned ${response.status}`)
  else if (body?.environment !== "staging") fail("health/live is not staging")
  else if (expectSha && body?.releaseSha !== expectSha)
    fail(
      `health/live reports ${body?.releaseSha ?? "no release"}, expected ${expectSha}`,
    )
  else pass(`health/live 200 (release ${body?.releaseSha ?? "unrecorded"})`)
} catch (error) {
  fail(`health/live failed: ${error instanceof Error ? error.message : error}`)
}

// Readiness: 503 is honest until the database probe lands; anything else must be 200.
try {
  const { response, body } = await request(`${base}/api/v1/health/ready`)
  if (response.status === 200 && body?.status === "ok") pass("health/ready 200")
  else if (response.status === 503 && body?.status === "not_ready")
    pass("health/ready 503 (database probe not implemented)")
  else fail(`health/ready returned ${response.status}`)
} catch (error) {
  fail(`health/ready failed: ${error instanceof Error ? error.message : error}`)
}

// Anonymous denials prove the routes exist.
for (const route of ["/api/v1/session", "/api/v1/activities"]) {
  try {
    const { response } = await request(`${base}${route}`)
    if ([401, 403].includes(response.status))
      pass(`${route} denies anonymously`)
    else fail(`${route} returned ${response.status}, expected 401 or 403`)
  } catch (error) {
    fail(`${route} failed: ${error instanceof Error ? error.message : error}`)
  }
}

// Sign-in exists and validates.
try {
  const { response } = await request(`${base}/api/v1/auth/sign-in`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: "{}",
  })
  if ([400, 401, 422].includes(response.status))
    pass("sign-in validates an empty body")
  else fail(`sign-in returned ${response.status}, expected 400/401/422`)
} catch (error) {
  fail(`sign-in failed: ${error instanceof Error ? error.message : error}`)
}

// Hosts and Access.
for (const [application, host] of Object.entries(hosts)) {
  try {
    const { response } = await request(`https://${host}/`)
    if (protectedApplications.includes(application)) {
      const location = response.headers.get("location") ?? ""
      const challenged =
        (response.status >= 300 && response.status < 400) ||
        response.status === 403
      if (challenged && location.includes("cloudflareaccess.com"))
        pass(`${host} challenges through Access`)
      else
        fail(`${host} did not produce an Access challenge (${response.status})`)
    } else if (response.status === 200) {
      pass(`${host} serves`)
    } else {
      fail(`${host} returned ${response.status}`)
    }
  } catch (error) {
    fail(`${host} failed: ${error instanceof Error ? error.message : error}`)
  }
}

if (failures.length) {
  console.error(`\nsmoke:staging: FAILED — ${failures.length} check(s)`)
  process.exit(1)
}
console.log("\nsmoke:staging: OK")
