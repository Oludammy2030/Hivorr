#!/usr/bin/env node
// Verify that a deployment is pointed at its own Supabase project before any
// backend deployment. Never prints DATABASE_URL or any credential.

import { readFileSync } from "node:fs"
import path from "node:path"

import { verifyBackendTarget } from "./lib/backend-target-policy.mjs"

const manifestPath = path.join(process.cwd(), "config", "backend-projects.json")
const manifest = JSON.parse(readFileSync(manifestPath, "utf8"))

const result = verifyBackendTarget(process.env, {
  staging: manifest.staging?.projectRef,
  production: manifest.production?.projectRef,
})

if (!result.ok) {
  console.error("verify-backend-target: REFUSED")
  for (const issue of result.issues) console.error(`- ${issue}`)
  process.exit(1)
}

console.log(
  `verify-backend-target: OK — environment=${result.environment} projectRef=${result.projectRef}`,
)
