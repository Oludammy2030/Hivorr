#!/usr/bin/env node
// Tests for the environment-topology policy.
//
// Uses the committed topology as the valid baseline, then injects one defect at
// a time and asserts that it is refused. No provider is called.

import { readFileSync } from "node:fs"
import path from "node:path"

import { verifyEnvironmentTopology } from "./lib/environment-topology-policy.mjs"

const root = process.cwd()
const baseline = JSON.parse(
  readFileSync(path.join(root, "config", "environments.json"), "utf8"),
)
const backendProjects = JSON.parse(
  readFileSync(path.join(root, "config", "backend-projects.json"), "utf8"),
)
const failures = []

function check(name, condition, detail = "") {
  if (condition) {
    console.log(`PASS  ${name}`)
  } else {
    console.log(`FAIL  ${name}${detail ? `\n${detail}` : ""}`)
    failures.push(name)
  }
}

function mutate(change) {
  const copy = structuredClone(baseline)
  change(copy)
  return verifyEnvironmentTopology(copy, { backendProjects })
}

const valid = verifyEnvironmentTopology(baseline, { backendProjects })
check("the committed topology is valid", valid.ok, valid.issues.join("\n"))
check("eight hosts are declared", valid.summary.hosts.length === 8)
check(
  "staging is not claimed as verified",
  valid.summary.stagingStatus === "planned",
)
check("production is reserved", valid.summary.productionStatus === "reserved")

const plural = mutate((topology) => {
  topology.environments.production.hosts.partner = "partners.hivorr.com"
})
check(
  "partners. is refused",
  !plural.ok && plural.issues.some((issue) => issue.includes("singular")),
  plural.issues.join("\n"),
)

const sharedRef = mutate((topology) => {
  topology.environments.production.supabaseProjectRef =
    topology.environments.staging.supabaseProjectRef
})
check(
  "a shared Supabase project is refused",
  !sharedRef.ok &&
    sharedRef.issues.some((issue) => issue.includes("must not share")),
  sharedRef.issues.join("\n"),
)

const wrongRef = mutate((topology) => {
  topology.environments.staging.supabaseProjectRef = "zyxwvutsrqponmlkjihg"
})
check(
  "a project ref that contradicts the backend manifest is refused",
  !wrongRef.ok &&
    wrongRef.issues.some((issue) => issue.includes("backend-projects.json")),
  wrongRef.issues.join("\n"),
)

const wildcard = mutate((topology) => {
  topology.environments.staging.hosts.control = "*.staging.hivorr.com"
})
check(
  "wildcard hosts are refused",
  !wildcard.ok && wildcard.issues.some((issue) => issue.includes("wildcard")),
  wildcard.issues.join("\n"),
)

const wrongDomain = mutate((topology) => {
  topology.environments.staging.hosts.main = "hivorr.com"
})
check(
  "a staging host outside the staging domain is refused",
  !wrongDomain.ok &&
    wrongDomain.issues.some((issue) => issue.includes("does not belong")),
  wrongDomain.issues.join("\n"),
)

const publicApi = mutate((topology) => {
  topology.environments.staging.apiOrigin = "api.staging.hivorr.com"
})
check(
  "a public API origin is refused",
  !publicApi.ok &&
    publicApi.issues.some((issue) => issue.includes("internal-only")),
  publicApi.issues.join("\n"),
)

const unprotected = mutate((topology) => {
  topology.environments.staging.accessProtected = ["control"]
})
check(
  "missing Access protection is refused",
  !unprotected.ok &&
    unprotected.issues.some((issue) => issue.includes("Access must protect")),
  unprotected.issues.join("\n"),
)

const sharedBucket = mutate((topology) => {
  topology.environments.production.storage.bucketPrefix = "hivorr-staging"
})
check(
  "a storage prefix not scoped to its environment is refused",
  !sharedBucket.ok &&
    sharedBucket.issues.some((issue) => issue.includes("environment-scoped")),
  sharedBucket.issues.join("\n"),
)

const prematureProduction = mutate((topology) => {
  topology.environments.production.status = "verified"
})
check(
  "production cannot be verified before staging",
  !prematureProduction.ok &&
    prematureProduction.issues.some((issue) =>
      issue.includes("before staging"),
    ),
  prematureProduction.issues.join("\n"),
)

const verifiedWithBlocker = mutate((topology) => {
  topology.environments.staging.status = "verified"
})
check(
  "staging cannot be verified while a blocker is open",
  !verifiedWithBlocker.ok &&
    verifiedWithBlocker.issues.some((issue) => issue.includes("TEC-12")),
  verifiedWithBlocker.issues.join("\n"),
)

const badRegion = mutate((topology) => {
  topology.environments.staging.flyRegion = "Johannesburg"
})
check(
  "a malformed Fly.io region is refused",
  !badRegion.ok &&
    badRegion.issues.some((issue) => issue.includes("three-letter")),
  badRegion.issues.join("\n"),
)

const unknownApp = mutate((topology) => {
  topology.environments.staging.hosts.admin = "admin.staging.hivorr.com"
})
check(
  "an undeclared fifth host is refused",
  !unknownApp.ok &&
    unknownApp.issues.some((issue) => issue.includes("unknown application")),
  unknownApp.issues.join("\n"),
)

if (failures.length) {
  console.error(`\n${failures.length} topology check(s) failed.`)
  process.exit(1)
}

console.log("\nAll environment-topology checks passed.")
