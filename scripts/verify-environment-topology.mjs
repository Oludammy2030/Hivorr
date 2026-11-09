#!/usr/bin/env node
// Validate the committed environment topology.
//
// This is a record check, not a provisioning action: it makes no DNS query, no
// provider call, and reads no credential. It fails when the topology drift
// would create a shared backend, a non-canonical host, or a premature
// production claim.

import { readFileSync } from "node:fs"
import path from "node:path"

import { verifyEnvironmentTopology } from "./lib/environment-topology-policy.mjs"

const root = process.cwd()

function readJson(relative) {
  return JSON.parse(readFileSync(path.join(root, relative), "utf8"))
}

let topology
let backendProjects
try {
  topology = readJson(path.join("config", "environments.json"))
  backendProjects = readJson(path.join("config", "backend-projects.json"))
} catch (error) {
  console.error(
    `verify-environment-topology: FAILED — ${
      error instanceof Error ? error.message : String(error)
    }`,
  )
  process.exit(2)
}

const result = verifyEnvironmentTopology(topology, { backendProjects })

if (!result.ok) {
  console.error("verify-environment-topology: REFUSED")
  for (const issue of result.issues) console.error(`- ${issue}`)
  process.exit(1)
}

console.log(
  `verify-environment-topology: OK — ${result.summary.hosts.length} host(s), staging=${result.summary.stagingStatus}, production=${result.summary.productionStatus}`,
)
for (const host of result.summary.hosts) console.log(`  ${host}`)
if (result.summary.openBlockers.length > 0) {
  console.log(
    `  open blocker(s): ${result.summary.openBlockers.join(", ")} — provisioning remains gated`,
  )
}
