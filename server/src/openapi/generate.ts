import { mkdirSync, writeFileSync } from "node:fs"
import path from "node:path"

import { buildDocument } from "./build"
import { buildClient } from "./client"

/**
 * Write the committed contract and the generated client.
 *
 * Both outputs are deterministic. `pnpm openapi:check` regenerates them and
 * fails on a diff; the contract test compares them in-process.
 */
const root = process.cwd()
const document = buildDocument()
const client = buildClient(document)

mkdirSync(path.join(root, "openapi"), { recursive: true })
writeFileSync(
  path.join(root, "openapi", "openapi.json"),
  `${JSON.stringify(document, null, 2)}\n`,
)
writeFileSync(
  path.join(root, "packages", "api-client", "src", "index.ts"),
  client,
)

console.log(
  `openapi:generate: wrote openapi/openapi.json (${Object.keys(document.paths).length} paths) and packages/api-client/src/index.ts`,
)
