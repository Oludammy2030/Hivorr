#!/usr/bin/env node
// Build the three privileged portal bundles. The main web bundle stays on the
// root Vite/Figma Make configuration and is built by `pnpm build`.

import path from "node:path"
import { build } from "vite"

const root = process.cwd()
const apps = ["control", "staff", "partner"]

for (const app of apps) {
  const configFile = path.join(root, "apps", app, "vite.config.ts")
  console.log(`build:portals: building ${app}`)
  await build({ configFile, mode: "production" })
}

console.log("build:portals: built control, staff, partner")
