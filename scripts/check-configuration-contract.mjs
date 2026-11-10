#!/usr/bin/env node
// Validate the configuration contract (EP-01-043).
//
// Checks that every declared key is documented in `.env.example`, that no
// secret carries a value or is referenced by client source, and that the
// environment topology only names secret keys the contract knows. It reads no
// credential and prints no value.
//
// Usage:
//   node scripts/check-configuration-contract.mjs
//   node scripts/check-configuration-contract.mjs --root <dir>

import { readFileSync, readdirSync, statSync } from "node:fs"
import path from "node:path"

import { verifyConfigurationContract } from "./lib/configuration-contract.mjs"

function argument(name) {
  const index = process.argv.indexOf(name)
  return index >= 0 ? process.argv[index + 1] : undefined
}

const root = path.resolve(argument("--root") ?? process.cwd())

function read(relative) {
  return readFileSync(path.join(root, relative), "utf8")
}

function readClientSource(directory) {
  let contents = ""
  const walk = (current) => {
    let entries
    try {
      entries = readdirSync(current)
    } catch {
      return
    }
    for (const entry of entries) {
      const full = path.join(current, entry)
      const stat = statSync(full)
      if (stat.isDirectory()) walk(full)
      else if (/\.(?:ts|tsx|js|jsx|html)$/.test(entry)) {
        contents += readFileSync(full, "utf8")
      }
    }
  }
  walk(directory)
  return contents
}

let contract
let environments
let envExample
try {
  contract = JSON.parse(
    read(path.join("config", "configuration-contract.json")),
  )
  envExample = read(".env.example")
  environments = JSON.parse(read(path.join("config", "environments.json")))
} catch (error) {
  console.error(
    `config:check: FAILED — ${
      error instanceof Error ? error.message : String(error)
    }`,
  )
  process.exit(2)
}

const clientSource = readClientSource(path.join(root, "src"))
const result = verifyConfigurationContract({
  contract,
  envExample,
  environments,
  clientSource,
})

if (!result.ok) {
  console.error("config:check: REFUSED")
  for (const issue of result.issues) console.error(`- ${issue}`)
  process.exit(1)
}

console.log(
  `config:check: OK — ${result.summary.keys} key(s), ${result.summary.secrets} secret(s), ` +
    `startup-required: ${result.summary.requiredRuntime.join(", ") || "none"}`,
)
