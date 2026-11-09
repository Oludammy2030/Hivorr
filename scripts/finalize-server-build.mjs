#!/usr/bin/env node
// Finalize the compiled server output.
//
// The workspace package is ESM ("type": "module"), but NestJS relies on
// decorator metadata and the imports are extensionless, so the server is
// compiled to CommonJS. A local package.json scopes that module type to the
// build output without changing the workspace package.

import { mkdirSync, writeFileSync } from "node:fs"
import path from "node:path"

const output = path.join(process.cwd(), "server", "dist")
mkdirSync(output, { recursive: true })
writeFileSync(
  path.join(output, "package.json"),
  `${JSON.stringify({ type: "commonjs" }, null, 2)}\n`,
)

console.log("build:server: wrote server/dist/package.json (commonjs)")
