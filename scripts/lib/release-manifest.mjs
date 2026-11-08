/**
 * Release manifest construction and verification.
 *
 * A release is defined by one commit, four application bundles, one backend
 * source tree, and one migration set. The manifest records a SHA-256 digest for
 * each so that production can prove it is promoting exactly the artifact that
 * staging tested, without rebuilding anything.
 *
 * Paths in the manifest are repository-relative and use forward slashes. The
 * digest of a tree is computed over the sorted relative path and per-file
 * digest of every file, so an added, removed, renamed, or edited file changes
 * the tree digest.
 */

import { createHash } from "node:crypto"
import { readdirSync, readFileSync, statSync } from "node:fs"
import path from "node:path"

export const MANIFEST_SCHEMA_VERSION = 1
export const RELEASE_SHA_PATTERN = /^[0-9a-f]{40}$/
export const RELEASE_REFS = ["staging", "main"]

/**
 * The four bundles and where the build places them. `main` is the root Vite
 * build; the privileged portals build into nested directories, so they are
 * excluded from the main bundle digest.
 */
export const BUNDLE_LAYOUT = [
  { name: "main", path: "dist", relativeToDist: ".", exclude: ["portals"] },
  {
    name: "control",
    path: "dist/portals/control",
    relativeToDist: "portals/control",
  },
  {
    name: "staff",
    path: "dist/portals/staff",
    relativeToDist: "portals/staff",
  },
  {
    name: "partner",
    path: "dist/portals/partner",
    relativeToDist: "portals/partner",
  },
]

export const BACKEND_PATH = "server/src"
export const API_ENTRY_PATH = "server/src/main.ts"
export const WORKER_ENTRY_PATH = "server/src/worker.ts"
export const MIGRATIONS_PATH = "supabase/migrations"

function isExcluded(relativePath, exclude) {
  return exclude.some(
    (entry) => relativePath === entry || relativePath.startsWith(`${entry}/`),
  )
}

/**
 * Every file under `directory`, as sorted forward-slash relative paths.
 * Throws when the directory does not exist, because a missing bundle is a
 * failed release, never an empty one.
 */
export function listFiles(directory, options = {}) {
  const exclude = options.exclude ?? []
  const files = []

  function walk(current, prefix) {
    for (const entry of readdirSync(current).sort()) {
      const full = path.join(current, entry)
      const relative = prefix ? `${prefix}/${entry}` : entry
      if (isExcluded(relative, exclude)) continue
      const stat = statSync(full)
      if (stat.isDirectory()) {
        walk(full, relative)
      } else if (stat.isFile()) {
        files.push(relative)
      }
    }
  }

  const stat = statSync(directory)
  if (!stat.isDirectory()) {
    throw new Error(`${directory} is not a directory`)
  }
  walk(directory, "")
  return files
}

export function digestOf(contents) {
  return `sha256:${createHash("sha256").update(contents).digest("hex")}`
}

export function fileDigest(file) {
  return digestOf(readFileSync(file))
}

/**
 * Deterministic digest of a directory tree.
 *
 * @returns {{ digest: string, files: number, bytes: number }}
 */
export function treeDigest(directory, options = {}) {
  const files = listFiles(directory, options)
  const hash = createHash("sha256")
  let bytes = 0

  for (const file of files) {
    const contents = readFileSync(path.join(directory, file))
    bytes += contents.length
    hash.update(file)
    hash.update("\0")
    hash.update(createHash("sha256").update(contents).digest("hex"))
    hash.update("\n")
  }

  return {
    digest: `sha256:${hash.digest("hex")}`,
    files: files.length,
    bytes,
  }
}

/**
 * Build the manifest for a commit.
 *
 * @throws when a bundle directory is missing or the release identity is
 * malformed. A release manifest is never partial.
 */
export function createReleaseManifest(options) {
  const {
    releaseSha,
    releaseRef,
    distDir = "dist",
    serverDir = BACKEND_PATH,
    migrationsDir = MIGRATIONS_PATH,
    generatedAt = new Date().toISOString(),
  } = options ?? {}

  if (!RELEASE_SHA_PATTERN.test(releaseSha ?? "")) {
    throw new Error(
      "releaseSha must be a 40-character lowercase hex commit SHA",
    )
  }
  if (!RELEASE_REFS.includes(releaseRef)) {
    throw new Error(`releaseRef must be one of: ${RELEASE_REFS.join(", ")}`)
  }

  const bundles = {}
  for (const bundle of BUNDLE_LAYOUT) {
    const directory = path.resolve(distDir, bundle.relativeToDist)
    const entry = treeDigest(directory, { exclude: bundle.exclude ?? [] })
    bundles[bundle.name] = {
      path: bundle.path,
      digest: entry.digest,
      files: entry.files,
      bytes: entry.bytes,
    }
  }

  const resolvedServer = path.resolve(serverDir)
  const apiEntry = fileDigest(path.join(resolvedServer, "main.ts"))
  const workerEntry = fileDigest(path.join(resolvedServer, "worker.ts"))
  const backend = treeDigest(resolvedServer)
  const migrations = treeDigest(path.resolve(migrationsDir))

  return {
    schemaVersion: MANIFEST_SCHEMA_VERSION,
    releaseSha,
    releaseRef,
    generatedAt,
    bundles,
    backend: {
      path: BACKEND_PATH,
      digest: backend.digest,
      files: backend.files,
      bytes: backend.bytes,
      apiEntry: { path: API_ENTRY_PATH, digest: apiEntry },
      workerEntry: { path: WORKER_ENTRY_PATH, digest: workerEntry },
    },
    migrations: {
      path: MIGRATIONS_PATH,
      digest: migrations.digest,
      files: migrations.files,
      bytes: migrations.bytes,
    },
  }
}

/**
 * Recompute every digest from the artifacts and source on disk and compare it
 * with the manifest. Any difference is a refusal: production must never deploy
 * bytes that do not match the staging-verified manifest.
 *
 * @returns {{ ok: boolean, issues: string[], summary: object }}
 */
export function verifyReleaseManifest(manifest, options = {}) {
  const {
    releaseSha,
    releaseRef,
    distDir = "dist",
    serverDir = BACKEND_PATH,
    migrationsDir = MIGRATIONS_PATH,
  } = options
  const issues = []

  if (!manifest || typeof manifest !== "object") {
    return { ok: false, issues: ["manifest is missing"], summary: {} }
  }
  if (manifest.schemaVersion !== MANIFEST_SCHEMA_VERSION) {
    issues.push(`unsupported manifest schemaVersion: ${manifest.schemaVersion}`)
  }
  if (!RELEASE_SHA_PATTERN.test(manifest.releaseSha ?? "")) {
    issues.push("manifest releaseSha is not a 40-character hex commit SHA")
  } else if (releaseSha && manifest.releaseSha !== releaseSha) {
    issues.push(
      `manifest releaseSha ${manifest.releaseSha} does not match requested ${releaseSha}`,
    )
  }
  if (!RELEASE_REFS.includes(manifest.releaseRef)) {
    issues.push(`manifest releaseRef is not one of: ${RELEASE_REFS.join(", ")}`)
  } else if (releaseRef && manifest.releaseRef !== releaseRef) {
    issues.push(
      `manifest releaseRef ${manifest.releaseRef} does not match expected ${releaseRef}`,
    )
  }

  for (const bundle of BUNDLE_LAYOUT) {
    const recorded = manifest.bundles?.[bundle.name]
    if (!recorded) {
      issues.push(`manifest is missing the ${bundle.name} bundle`)
      continue
    }
    if (recorded.path !== bundle.path) {
      issues.push(
        `manifest ${bundle.name} path ${recorded.path} is not ${bundle.path}`,
      )
    }
    try {
      const actual = treeDigest(path.resolve(distDir, bundle.relativeToDist), {
        exclude: bundle.exclude ?? [],
      })
      if (actual.digest !== recorded.digest) {
        issues.push(
          `${bundle.name} bundle digest mismatch (manifest ${recorded.digest}, artifact ${actual.digest})`,
        )
      } else if (actual.files !== recorded.files) {
        issues.push(
          `${bundle.name} bundle file count mismatch (manifest ${recorded.files}, artifact ${actual.files})`,
        )
      }
    } catch (error) {
      issues.push(
        `${bundle.name} bundle is unreadable: ${
          error instanceof Error ? error.message : String(error)
        }`,
      )
    }
  }

  if (!manifest.backend) {
    issues.push("manifest is missing the backend source record")
  } else {
    if (manifest.backend.path !== BACKEND_PATH) {
      issues.push(
        `manifest backend path ${manifest.backend.path} is not ${BACKEND_PATH}`,
      )
    }
    try {
      const resolvedServer = path.resolve(serverDir)
      const actual = treeDigest(resolvedServer)
      if (actual.digest !== manifest.backend.digest) {
        issues.push(
          `backend source digest mismatch (manifest ${manifest.backend.digest}, checkout ${actual.digest})`,
        )
      }
      const apiEntry = fileDigest(path.join(resolvedServer, "main.ts"))
      if (apiEntry !== manifest.backend.apiEntry?.digest) {
        issues.push("API entry point digest mismatch")
      }
      const workerEntry = fileDigest(path.join(resolvedServer, "worker.ts"))
      if (workerEntry !== manifest.backend.workerEntry?.digest) {
        issues.push("worker entry point digest mismatch")
      }
    } catch (error) {
      issues.push(
        `backend source is unreadable: ${
          error instanceof Error ? error.message : String(error)
        }`,
      )
    }
  }

  if (!manifest.migrations) {
    issues.push("manifest is missing the migration record")
  } else {
    if (manifest.migrations.path !== MIGRATIONS_PATH) {
      issues.push(
        `manifest migrations path ${manifest.migrations.path} is not ${MIGRATIONS_PATH}`,
      )
    }
    try {
      const actual = treeDigest(path.resolve(migrationsDir))
      if (actual.digest !== manifest.migrations.digest) {
        issues.push(
          `migration set digest mismatch (manifest ${manifest.migrations.digest}, checkout ${actual.digest})`,
        )
      }
      if (actual.files !== manifest.migrations.files) {
        issues.push(
          `migration count mismatch (manifest ${manifest.migrations.files}, checkout ${actual.files})`,
        )
      }
    } catch (error) {
      issues.push(
        `migration set is unreadable: ${
          error instanceof Error ? error.message : String(error)
        }`,
      )
    }
  }

  return {
    ok: issues.length === 0,
    issues,
    summary: {
      releaseSha: manifest.releaseSha,
      releaseRef: manifest.releaseRef,
      bundles: Object.keys(manifest.bundles ?? {}),
    },
  }
}
