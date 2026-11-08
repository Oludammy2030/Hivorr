/**
 * Environment-topology policy.
 *
 * The topology is recorded as code so the eight deployments are reviewable
 * before any host exists. This module validates the record, not a live
 * environment: it never resolves DNS, calls a provider, or reads a credential.
 *
 * Rules enforced here:
 * - exactly four applications per hosted environment;
 * - canonical hostnames only, one host per environment, no wildcard and no
 *   `www.` variant;
 * - `partner.` singular, never `partners.`;
 * - staging hosts stay under the staging base domain and production hosts under
 *   the production base domain;
 * - the API has no public hostname;
 * - environment project refs match the committed backend manifest and never
 *   share a project;
 * - storage prefixes and secrets are environment-scoped;
 * - production stays `reserved` until staging is `verified`;
 * - a `verified` environment has no open blocker that names it.
 */

export const TOPOLOGY_SCHEMA_VERSION = 1
export const TOPOLOGY_APPLICATIONS = ["main", "control", "staff", "partner"]
export const ENVIRONMENT_STATUSES = ["planned", "verified", "reserved"]

function hostIssues(environmentName, application, host, baseDomain, issues) {
  const label = `${environmentName}/${application}`
  if (typeof host !== "string" || host.length === 0) {
    issues.push(`${label}: host is required`)
    return
  }
  if (host.includes("*")) {
    issues.push(`wildcard hostnames are forbidden: ${host}`)
  }
  if (host.startsWith("www.")) {
    issues.push(`${label}: no www. variant may exist`)
  }
  if (host.includes("/") || host.includes(":")) {
    issues.push(`${label}: a hostname must not carry a path, port, or scheme`)
  }
  if (host !== host.toLowerCase()) {
    issues.push(`${label}: hostnames are lowercase`)
  }
  if (!host.endsWith(baseDomain)) {
    issues.push(`${label}: host does not belong to ${baseDomain}`)
  }
  if (host.includes("partners.")) {
    issues.push(`${label}: the partner host is singular, not partners.`)
  }

  const escaped = baseDomain.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")
  if (environmentName === "staging") {
    const main = `staging.${baseDomain}`
    const flattened = new RegExp(`^[a-z0-9-]+-staging\\.${escaped}$`)
    if (host !== main && !flattened.test(host)) {
      issues.push(
        `${label}: staging host must be ${main} or a first-level *-staging host`,
      )
    }
  }
  if (environmentName === "production") {
    const firstLevel = new RegExp(`^[a-z0-9-]+\\.${escaped}$`)
    if (host !== baseDomain && !firstLevel.test(host)) {
      issues.push(
        `${label}: production host must be ${baseDomain} or a first-level subdomain`,
      )
    }
    if (host.includes("staging")) {
      issues.push(`${label}: a production host must not contain staging`)
    }
  }
}

export function verifyEnvironmentTopology(topology, options = {}) {
  const issues = []
  const backendProjects = options.backendProjects ?? {}

  if (!topology || typeof topology !== "object") {
    return { ok: false, issues: ["topology is missing"], summary: {} }
  }
  if (topology.schemaVersion !== TOPOLOGY_SCHEMA_VERSION) {
    issues.push(`unsupported topology schemaVersion: ${topology.schemaVersion}`)
  }

  const applications = topology.applications ?? []
  if (
    applications.length !== TOPOLOGY_APPLICATIONS.length ||
    !TOPOLOGY_APPLICATIONS.every((name) => applications.includes(name))
  ) {
    issues.push(
      `applications must be exactly: ${TOPOLOGY_APPLICATIONS.join(", ")}`,
    )
  }

  const environments = topology.environments ?? {}
  const names = Object.keys(environments)
  if (
    names.length !== 2 ||
    !["staging", "production"].every((n) => names.includes(n))
  ) {
    issues.push("topology must define staging and production exactly once")
  }

  const blockers = Array.isArray(topology.blockers) ? topology.blockers : []
  for (const blocker of blockers) {
    if (!blocker.id || !blocker.summary || !Array.isArray(blocker.blocks)) {
      issues.push("each blocker needs id, summary, and a blocks array")
    }
  }

  const allHosts = new Map()
  const projectRefs = new Map()

  for (const name of names) {
    const environment = environments[name] ?? {}
    if (!ENVIRONMENT_STATUSES.includes(environment.status)) {
      issues.push(
        `${name}: status must be one of ${ENVIRONMENT_STATUSES.join(", ")}`,
      )
    }
    if (!environment.baseDomain) {
      issues.push(`${name}: baseDomain is required`)
    }

    const hosts = environment.hosts ?? {}
    for (const application of TOPOLOGY_APPLICATIONS) {
      if (!(application in hosts)) {
        issues.push(`${name}: missing the ${application} host`)
      }
    }
    for (const [application, host] of Object.entries(hosts)) {
      if (!TOPOLOGY_APPLICATIONS.includes(application)) {
        issues.push(`${name}: unknown application host ${application}`)
      }
      if (typeof host === "string" && allHosts.has(host)) {
        issues.push(
          `${host} is assigned to both ${allHosts.get(host)} and ${name}`,
        )
      }
      allHosts.set(host, name)
      hostIssues(name, application, host, environment.baseDomain, issues)
    }

    if (environment.flyRegion !== undefined) {
      if (!/^[a-z]{3}$/.test(environment.flyRegion)) {
        issues.push(
          `${name}: flyRegion must be a three-letter Fly.io region code`,
        )
      }
    } else if (environment.status === "verified") {
      issues.push(
        `${name}: a verified environment must record its Fly.io region`,
      )
    }

    if (environment.apiOrigin !== "internal-only") {
      issues.push(
        `${name}: the API has no public hostname; apiOrigin must be internal-only`,
      )
    }
    if (environment.edgeRewrite !== "/api/*") {
      issues.push(`${name}: the edge must rewrite /api/* same-origin`)
    }

    if (!environment.supabaseProjectRef) {
      issues.push(`${name}: supabaseProjectRef is required`)
    } else {
      if (projectRefs.has(environment.supabaseProjectRef)) {
        issues.push("staging and production must not share a Supabase project")
      }
      projectRefs.set(environment.supabaseProjectRef, name)

      const expected = backendProjects[name]?.projectRef
      if (expected && environment.supabaseProjectRef !== expected) {
        issues.push(
          `${name}: supabaseProjectRef does not match config/backend-projects.json`,
        )
      }
    }

    if (environment.storage?.provider !== "cloudflare-r2") {
      issues.push(`${name}: storage provider must be cloudflare-r2`)
    }
    if (
      !environment.storage?.bucketPrefix ||
      !environment.storage.bucketPrefix.includes(name)
    ) {
      issues.push(`${name}: the R2 bucket prefix must be environment-scoped`)
    }

    const protectedApps = environment.accessProtected ?? []
    for (const application of ["control", "staff", "partner"]) {
      if (!protectedApps.includes(application)) {
        issues.push(`${name}: Cloudflare Access must protect ${application}`)
      }
    }

    const secrets = environment.requiredSecrets ?? []
    for (const secret of [
      "DATABASE_URL",
      "MFA_ENCRYPTION_KEY",
      "WORKER_DATABASE_URL",
    ]) {
      if (!secrets.includes(secret)) {
        issues.push(`${name}: requiredSecrets is missing ${secret}`)
      }
    }

    if (environment.status === "verified") {
      for (const blocker of blockers) {
        if (blocker.blocks?.includes(name)) {
          issues.push(
            `${name}: cannot be verified while blocker ${blocker.id} is open`,
          )
        }
      }
    }
  }

  if (
    environments.production?.status === "verified" &&
    environments.staging?.status !== "verified"
  ) {
    issues.push("production cannot be verified before staging")
  }

  if (
    environments.staging?.status === "planned" &&
    !blockers.some((blocker) => blocker.blocks?.includes("staging"))
  ) {
    issues.push("a planned staging environment must name its open blockers")
  }

  return {
    ok: issues.length === 0,
    issues,
    summary: {
      hosts: [...allHosts.keys()],
      stagingStatus: environments.staging?.status ?? null,
      productionStatus: environments.production?.status ?? null,
      openBlockers: blockers.map((blocker) => blocker.id),
    },
  }
}
