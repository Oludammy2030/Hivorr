#!/usr/bin/env node
// Remove the previous server build before compiling.
//
// `tsc` does not delete outputs for files that no longer exist, so a module
// move leaves stale JavaScript in `server/dist`. The Docker build starts from
// a clean image, but a local build must match it. EP-01-012 moved grants into
// identity and health out of `modules/`, which is exactly the case this
// guards.

import { rmSync } from "node:fs"
import path from "node:path"
import { fileURLToPath } from "node:url"

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..")
rmSync(path.join(root, "server", "dist"), { recursive: true, force: true })
