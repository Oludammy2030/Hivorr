#!/usr/bin/env node
// Scope the OpenAPI generator build to CommonJS. The workspace package is ESM,
// but the generated compiler output uses extensionless is not valid Node ESM.

import { mkdirSync, writeFileSync } from "node:fs"
import path from "node:path"
import { fileURLToPath } from "node:url"

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..")
const output = path.join(root, "server", "dist-openapi")
mkdirSync(output, { recursive: true })
writeFileSync(
  path.join(output, "package.json"),
  `${JSON.stringify({ type: "commonjs" }, null, 2)}\n`,
)
