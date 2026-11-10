import { readFileSync } from "node:fs"

import { describe, expect, it } from "vitest"

import {
  CONFIG_ENV_KEYS,
  ConfigurationError,
  parseConfig,
} from "../server/src/config"
import {
  parseEnvTemplate,
  verifyConfigurationContract,
} from "../scripts/lib/configuration-contract.mjs"

function readJson(relative: string): unknown {
  return JSON.parse(
    readFileSync(new URL(`../${relative}`, import.meta.url), "utf8"),
  )
}

interface ContractKey {
  name: string
  source: string
  classification: string
}

interface ConfigurationContract {
  keys: ContractKey[]
}

const contract = readJson(
  "config/configuration-contract.json",
) as ConfigurationContract
const environments = readJson("config/environments.json")
const envExample = readFileSync(
  new URL("../.env.example", import.meta.url),
  "utf8",
)

const validStaging = {
  HIVORR_ENV: "staging",
  BACKEND_ENVIRONMENT: "staging",
  SUPABASE_PROJECT_REF: "abcdefghijklmnopqrst",
  DATABASE_URL:
    "postgresql://postgres:fake@db.abcdefghijklmnopqrst.supabase.co:5432/postgres",
  SESSION_ISSUER: "hivorr-staging",
  MFA_ENCRYPTION_KEY: "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=",
} as Record<string, string>

function keysOf(source: string) {
  return contract.keys
    .filter((entry) => entry.source === source)
    .map((entry) => entry.name)
}

describe("configuration contract", () => {
  it("declares every key the API schema reads, and no other", () => {
    expect([...keysOf("config")].sort()).toEqual([...CONFIG_ENV_KEYS].sort())
  })

  it("passes the committed contract against the template and topology", () => {
    const result = verifyConfigurationContract({
      contract,
      envExample,
      environments,
      clientSource: readFileSync(
        new URL("../src/app/App.tsx", import.meta.url),
        "utf8",
      ),
    })
    expect(result.issues).toEqual([])
    expect(result.ok).toBe(true)
  })

  it("leaves every secret placeholder empty", () => {
    const template = parseEnvTemplate(envExample)
    for (const entry of contract.keys) {
      if (entry.classification === "secret" && template.has(entry.name)) {
        expect(template.get(entry.name)).toBe("")
      }
    }
  })

  it("starts up with a complete staging configuration", () => {
    expect(() => parseConfig(validStaging)).not.toThrow()
  })

  it("fails startup when a staging secret is missing", () => {
    for (const name of ["DATABASE_URL", "MFA_ENCRYPTION_KEY"]) {
      const incomplete = { ...validStaging }
      delete incomplete[name]
      expect(() => parseConfig(incomplete)).toThrow(ConfigurationError)
      try {
        parseConfig(incomplete)
      } catch (error) {
        expect(String(error)).toContain(name)
        expect(String(error)).not.toContain(validStaging.DATABASE_URL)
      }
    }
  })

  it("rejects drift in the contract fixtures", () => {
    expect(
      verifyConfigurationContract({
        contract,
        envExample: envExample.replace(/^API_PORT=.*$/m, ""),
        environments,
      }).issues,
    ).toContain("API_PORT: missing from .env.example")

    expect(
      verifyConfigurationContract({
        contract,
        envExample: envExample.replace(
          /^MFA_ENCRYPTION_KEY=.*$/m,
          "MFA_ENCRYPTION_KEY=not-empty",
        ),
        environments,
      }).issues,
    ).toContain(
      "MFA_ENCRYPTION_KEY: a secret placeholder must be empty in .env.example",
    )

    expect(
      verifyConfigurationContract({
        contract,
        envExample,
        environments,
        clientSource: "const key = 'DATABASE_URL'",
      }).issues,
    ).toContain("DATABASE_URL: a secret name appears in client source")

    expect(
      verifyConfigurationContract({
        contract,
        envExample,
        environments: {
          environments: { staging: { requiredSecrets: ["UNKNOWN_KEY"] } },
        },
      }).issues,
    ).toContain(
      "staging.requiredSecrets references UNKNOWN_KEY, which is absent from the contract",
    )
  })
})
