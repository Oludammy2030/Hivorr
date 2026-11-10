import { readdirSync, readFileSync, statSync } from "node:fs"
import path from "node:path"

import { describe, expect, it } from "vitest"

const root = process.cwd()
const read = (relative: string) =>
  readFileSync(path.join(root, relative), "utf8").replace(/\r\n/g, "\n")

const dockerfile = read("Dockerfile")

/**
 * The runtime stage ships a pruned copy of the build stage. pnpm links each
 * workspace package's own dependencies into that package's node_modules, and
 * Node resolves bare imports from the importing file's directory upwards. So a
 * workspace package that has runtime dependencies must carry its node_modules
 * into the image, or the process dies with ERR_MODULE_NOT_FOUND at boot — which
 * no workspace-level CI job can see, because there every link already exists.
 *
 * This contract failed once: @hivorr/shared gained `zod` and the image still
 * shipped only its package.json and dist, so the staging API crash-looped
 * (Fly machine restarting on `Cannot find package 'zod' imported from
 * /app/packages/shared/dist/index.js`).
 */

function runtimeCopySources(): Set<string> {
  const stages = dockerfile.split(/^FROM /m)
  const runtime = stages.find((stage) => /AS runtime\b/.test(stage))
  if (!runtime) throw new Error("Dockerfile has no runtime stage")

  const sources = new Set<string>()
  for (const line of runtime.split("\n")) {
    const copy = /^\s*COPY\s+--from=build\s+(\S+)\s+(\S+)/.exec(line)
    if (!copy) continue
    sources.add(copy[1].replace(/^\/app\//, "").replace(/\/+$/, ""))
  }
  return sources
}

function filesUnder(directory: string): string[] {
  const files: string[] = []
  for (const name of readdirSync(directory)) {
    const file = path.join(directory, name)
    if (statSync(file).isDirectory()) files.push(...filesUnder(file))
    else files.push(file)
  }
  return files
}

interface WorkspacePackage {
  directory: string
  runtimeDependencies: string[]
}

// Declared as an interface, not an inline literal: oxfmt 0.2.0 drops the
// separator between optional members of an inline type literal, which turns
// this into a parse error.
interface PackageManifest {
  name?: string
  dependencies?: Record<string, string>
}

function workspacePackages(): Map<string, WorkspacePackage> {
  const packages = new Map<string, WorkspacePackage>()
  for (const name of readdirSync(path.join(root, "packages"))) {
    const manifestPath = path.join(root, "packages", name, "package.json")
    let manifest: PackageManifest
    try {
      manifest = JSON.parse(readFileSync(manifestPath, "utf8"))
    } catch {
      continue
    }
    if (!manifest.name?.startsWith("@hivorr/")) continue
    packages.set(manifest.name, {
      directory: `packages/${name}`,
      runtimeDependencies: Object.keys(manifest.dependencies ?? {}),
    })
  }
  return packages
}

function serverWorkspaceImports(): Set<string> {
  const imported = new Set<string>()
  for (const file of filesUnder(path.join(root, "server", "src"))) {
    if (!file.endsWith(".ts")) continue
    const source = readFileSync(file, "utf8")
    for (const match of source.matchAll(/["'](@hivorr\/[a-z-]+)["']/g))
      imported.add(match[1])
  }
  return imported
}

describe("container runtime image", () => {
  const sources = runtimeCopySources()
  const packages = workspacePackages()
  // Only packages under packages/ can be shipped into the image; the server
  // itself is shipped as server/dist and frontend packages are bundled by Vite.
  const imported = [...serverWorkspaceImports()].filter((name) =>
    packages.has(name),
  )

  it("finds the runtime stage and the server's workspace imports", () => {
    expect(sources.has("server/dist")).toBe(true)
    expect(sources.has("server/package.json")).toBe(true)
    expect(imported).toContain("@hivorr/shared")
  })

  it("ships every workspace package the server imports", () => {
    for (const name of imported) {
      const entry = packages.get(name)!
      expect(
        sources.has(`${entry.directory}/package.json`),
        `${name} package.json is not copied into the runtime stage`,
      ).toBe(true)
      expect(
        sources.has(`${entry.directory}/dist`),
        `${name} dist is not copied into the runtime stage`,
      ).toBe(true)
    }
  })

  it("ships node_modules for every shipped package with runtime dependencies", () => {
    for (const name of imported) {
      const entry = packages.get(name)!
      if (entry.runtimeDependencies.length === 0) continue
      expect(
        sources.has(`${entry.directory}/node_modules`),
        `${name} declares runtime dependencies (${entry.runtimeDependencies.join(
          ", ",
        )}) but ${entry.directory}/node_modules is not copied into the runtime stage`,
      ).toBe(true)
    }
  })
})
