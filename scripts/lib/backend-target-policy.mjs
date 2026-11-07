/**
 * Deployment-time backend isolation policy.
 *
 * This module contains no secret values and must never receive a printed
 * connection string. It verifies that the selected deployment, the declared
 * backend environment, the Supabase project reference, and the database URL all
 * belong together.
 */

function databaseUrlMatchesProjectRef(databaseUrl, projectRef) {
  try {
    const url = new URL(databaseUrl)
    const ref = projectRef.toLowerCase()
    const host = url.hostname.toLowerCase()
    const username = decodeURIComponent(url.username).toLowerCase()
    return host === `db.${ref}.supabase.co` || username.includes(ref)
  } catch {
    return false
  }
}

export function verifyBackendTarget(env) {
  const issues = []
  const deployment = env.HIVORR_ENV

  if (deployment !== "staging" && deployment !== "production") {
    issues.push("HIVORR_ENV must be staging or production")
  }

  if (!env.BACKEND_ENVIRONMENT) {
    issues.push("BACKEND_ENVIRONMENT is required")
  } else if (env.BACKEND_ENVIRONMENT !== deployment) {
    issues.push("BACKEND_ENVIRONMENT must match HIVORR_ENV")
  }

  const projectRef = env.SUPABASE_PROJECT_REF
  if (!projectRef) {
    issues.push("SUPABASE_PROJECT_REF is required")
  }

  const expectedRef = env.EXPECTED_SUPABASE_PROJECT_REF
  if (!expectedRef) {
    issues.push("EXPECTED_SUPABASE_PROJECT_REF is required")
  } else if (projectRef && projectRef !== expectedRef) {
    issues.push(
      "SUPABASE_PROJECT_REF does not match EXPECTED_SUPABASE_PROJECT_REF",
    )
  }

  if (!env.DATABASE_URL) {
    issues.push("DATABASE_URL is required")
  } else if (
    projectRef &&
    !databaseUrlMatchesProjectRef(env.DATABASE_URL, projectRef)
  ) {
    issues.push("DATABASE_URL does not belong to SUPABASE_PROJECT_REF")
  }

  const stagingRef = env.STAGING_SUPABASE_PROJECT_REF
  const productionRef = env.PRODUCTION_SUPABASE_PROJECT_REF
  if (stagingRef && productionRef && stagingRef === productionRef) {
    issues.push("staging and production must not share a Supabase project")
  }

  const otherRef = deployment === "staging" ? productionRef : stagingRef
  if (projectRef && otherRef && projectRef === otherRef) {
    issues.push("the deployment is pointed at the other environment's backend")
  }

  return {
    ok: issues.length === 0,
    environment: deployment,
    projectRef: projectRef || null,
    issues,
  }
}
