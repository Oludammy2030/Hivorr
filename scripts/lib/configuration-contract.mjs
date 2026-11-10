// Configuration contract policy (EP-01-043).
//
// Pure functions so the same rules run in `pnpm config:check` and in the
// seeded-failure gate. It validates the committed inventory, the local template
// and the environment topology against each other; it never reads a secret
// value, because none is committed.

export const CONFIG_SOURCES = ["config", "tooling", "deployment"]
export const CLASSIFICATIONS = ["public", "secret"]
export const DEPLOYMENT_ENVIRONMENTS = [
  "development",
  "test",
  "staging",
  "production",
]

const NAME_PATTERN = /^[A-Z][A-Z0-9_]*$/

/** Parse a dotenv-style template into name -> raw value. Comments are skipped. */
export function parseEnvTemplate(contents) {
  const entries = new Map()
  for (const line of contents.split(/\r?\n/)) {
    const trimmed = line.trim()
    if (!trimmed || trimmed.startsWith("#")) continue
    const separator = trimmed.indexOf("=")
    if (separator < 0) continue
    const name = trimmed.slice(0, separator).trim()
    if (!entries.has(name)) {
      entries.set(name, trimmed.slice(separator + 1).trim())
    }
  }
  return entries
}

/**
 * Validate the contract against the template, the topology manifest and the
 * client source.
 *
 * @param {{
 *   contract: unknown,
 *   envExample: string,
 *   environments: unknown,
 *   clientSource?: string,
 * }} input
 */
export function verifyConfigurationContract({
  contract,
  envExample,
  environments,
  clientSource = "",
}) {
  const issues = []

  if (!contract || typeof contract !== "object") {
    return { ok: false, issues: ["contract is missing or not an object"] }
  }
  if (contract.schemaVersion !== 1) {
    issues.push(`contract schemaVersion must be 1`)
  }
  if (!Array.isArray(contract.keys) || contract.keys.length === 0) {
    return {
      ok: false,
      issues: [...issues, "contract.keys must be a non-empty array"],
    }
  }

  const keys = contract.keys
  const seen = new Set()
  const byName = new Map()

  for (const entry of keys) {
    if (!entry || typeof entry !== "object") {
      issues.push("contract.keys contains a non-object entry")
      continue
    }
    const name = entry.name
    if (typeof name !== "string" || !NAME_PATTERN.test(name)) {
      issues.push(`invalid key name: ${JSON.stringify(name)}`)
      continue
    }
    if (seen.has(name)) issues.push(`${name}: declared more than once`)
    seen.add(name)
    byName.set(name, entry)

    if (!CONFIG_SOURCES.includes(entry.source)) {
      issues.push(`${name}: source must be one of ${CONFIG_SOURCES.join(", ")}`)
    }
    if (!CLASSIFICATIONS.includes(entry.classification)) {
      issues.push(`${name}: classification must be public or secret`)
    }
    if (!Array.isArray(entry.requiredIn)) {
      issues.push(`${name}: requiredIn must be an array`)
    } else {
      if (new Set(entry.requiredIn).size !== entry.requiredIn.length) {
        issues.push(`${name}: requiredIn contains a duplicate`)
      }
      for (const environment of entry.requiredIn) {
        if (!DEPLOYMENT_ENVIRONMENTS.includes(environment)) {
          issues.push(
            `${name}: unknown environment ${JSON.stringify(environment)}`,
          )
        }
      }
    }
    if (
      typeof entry.description !== "string" ||
      entry.description.length < 10
    ) {
      issues.push(`${name}: a description is required`)
    }
    // A contract carries names and rules, never values. A default would be a
    // value that silently survives a missing injection.
    if ("value" in entry || "default" in entry) {
      issues.push(`${name}: the contract must not carry a value or default`)
    }
  }

  const template = parseEnvTemplate(envExample)

  for (const [name, entry] of byName) {
    if (entry.source === "deployment") {
      if (template.has(name)) {
        issues.push(
          `${name}: a deployment-only key must not appear in .env.example`,
        )
      }
      continue
    }
    if (!template.has(name)) {
      issues.push(`${name}: missing from .env.example`)
      continue
    }
    if (entry.classification === "secret" && template.get(name) !== "") {
      issues.push(`${name}: a secret placeholder must be empty in .env.example`)
    }
  }

  for (const name of template.keys()) {
    if (!byName.has(name)) {
      issues.push(
        `${name}: present in .env.example but absent from the contract`,
      )
    }
  }

  const secretNames = [...byName.values()]
    .filter((entry) => entry.classification === "secret")
    .map((entry) => entry.name)
  const runtimeSecretNames = [...byName.values()]
    .filter(
      (entry) =>
        entry.classification === "secret" && entry.source !== "deployment",
    )
    .map((entry) => entry.name)

  for (const name of secretNames) {
    // A secret name in client code means the value could be injected into a
    // bundle. The API keeps them server-only.
    if (clientSource.includes(name)) {
      issues.push(`${name}: a secret name appears in client source`)
    }
  }

  const environmentEntries =
    environments && typeof environments === "object"
      ? environments.environments
      : undefined
  if (!environmentEntries || typeof environmentEntries !== "object") {
    issues.push("environments manifest is missing an environments object")
  } else {
    for (const [environment, definition] of Object.entries(
      environmentEntries,
    )) {
      const requiredSecrets =
        definition && typeof definition === "object"
          ? definition.requiredSecrets
          : undefined
      if (requiredSecrets === undefined) continue
      if (!Array.isArray(requiredSecrets)) {
        issues.push(`${environment}.requiredSecrets must be an array`)
        continue
      }
      for (const name of requiredSecrets) {
        if (!byName.has(name)) {
          issues.push(
            `${environment}.requiredSecrets references ${name}, which is absent from the contract`,
          )
        } else if (byName.get(name).classification !== "secret") {
          issues.push(
            `${environment}.requiredSecrets references ${name}, which is not classified secret`,
          )
        }
      }
    }
  }

  const requiredRuntime = [...byName.values()]
    .filter(
      (entry) =>
        entry.source === "config" &&
        entry.classification === "secret" &&
        Array.isArray(entry.requiredIn) &&
        entry.requiredIn.length > 0,
    )
    .map((entry) => entry.name)

  return {
    ok: issues.length === 0,
    issues,
    summary: {
      keys: byName.size,
      secrets: secretNames.length,
      runtimeSecrets: runtimeSecretNames.length,
      requiredRuntime,
    },
  }
}
