#!/usr/bin/env node
// Remove the previous OpenAPI generator build before compiling.

import { rmSync } from "node:fs"
import path from "node:path"
import { fileURLToPath } from "node:url"

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..")
rmSync(path.join(root, "server", "dist-openapi"), {
  recursive: true,
  force: true,
})
