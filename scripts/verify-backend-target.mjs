#!/usr/bin/env node
// Verify that a deployment is pointed at its own Supabase project before any
// backend deployment. Never prints DATABASE_URL or any credential.

import { verifyBackendTarget } from "./lib/backend-target-policy.mjs"

const result = verifyBackendTarget(process.env)

if (!result.ok) {
  console.error("verify-backend-target: REFUSED")
  for (const issue of result.issues) console.error(`- ${issue}`)
  process.exit(1)
}

console.log(
  `verify-backend-target: OK — environment=${result.environment} projectRef=${result.projectRef}`,
)
