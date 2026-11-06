import { execFileSync } from "node:child_process"
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs"
import { tmpdir } from "node:os"
import path from "node:path"
import { afterAll, describe, expect, it } from "vitest"

const root = process.cwd()
const manifest = JSON.parse(
  readFileSync(path.join(root, "package.json"), "utf8"),
)

const temporaryDirectories: string[] = []

function temporaryFixture(name: string, content: string): string {
  const directory = mkdtempSync(path.join(tmpdir(), "hivorr-readiness-"))
  temporaryDirectories.push(directory)
  const file = path.join(directory, name)
  writeFileSync(file, content, "utf8")
  return file
}

function runSecretScan(file: string) {
  try {
    const stdout = execFileSync(
      process.execPath,
      ["scripts/secret-scan.mjs", file],
      {
        cwd: root,
        encoding: "utf8",
        stdio: ["ignore", "pipe", "pipe"],
      },
    )
    return { status: 0, stdout, stderr: "" }
  } catch (error) {
    const failure = error as {
      status?: number
      stdout?: string
      stderr?: string
    }
    return {
      status: failure.status ?? 1,
      stdout: failure.stdout ?? "",
      stderr: failure.stderr ?? "",
    }
  }
}

afterAll(() => {
  for (const directory of temporaryDirectories)
    rmSync(directory, { recursive: true, force: true })
})

describe("EP-00 repository contract", () => {
  it("pins the package manager and supported Node major", () => {
    expect(manifest.packageManager).toBe("pnpm@10.34.9")
    expect(manifest.engines?.node).toBe(">=22.0.0 <23")
    expect(manifest.engines?.pnpm).toBe("10.34.9")
  })

  it("exposes every gate the pipeline invokes", () => {
    for (const script of [
      "build",
      "dev",
      "lint",
      "format:check",
      "typecheck",
      "test",
      "check:toolchain",
    ]) {
      expect(
        manifest.scripts?.[script],
        `missing script: ${script}`,
      ).toBeTruthy()
    }
  })

  it("uses exact versions for every direct dependency", () => {
    const ranges = []
    for (const section of ["dependencies", "devDependencies"]) {
      for (const [name, specifier] of Object.entries(manifest[section] ?? {})) {
        if (!/^\d+\.\d+\.\d+(?:-[\w.]+)?$/.test(String(specifier))) {
          ranges.push(`${section}/${name}: ${specifier}`)
        }
      }
    }
    expect(ranges).toEqual([])
  })

  it("keeps the seven-day supply-chain policy and Linux reference architecture", () => {
    const workspace = readFileSync(
      path.join(root, "pnpm-workspace.yaml"),
      "utf8",
    )
    expect(workspace).toMatch(/minimumReleaseAge:\s*10080/)
    expect(workspace).toMatch(/os:\s*\n\s*-\s*linux/)
  })

  it("keeps the mise toolchain aligned with package.json", () => {
    const mise = readFileSync(path.join(root, ".mise.toml"), "utf8")
    expect(mise).toMatch(/node\s*=\s*"22"/)
    expect(mise).toMatch(/"npm:pnpm"\s*=\s*"10\.34\.9"/)
  })
})

describe("secret-scan control", () => {
  it("passes a clean file", () => {
    const fixture = temporaryFixture("clean.txt", "no credentials here\n")
    const result = runSecretScan(fixture)
    expect(result.status).toBe(0)
    expect(result.stdout).toContain("clean")
  })

  it("blocks a non-live GitHub-shaped token", () => {
    const fixture = temporaryFixture(
      "fake-token.txt",
      `token = ghp_${"0".repeat(36)}\n`,
    )
    const result = runSecretScan(fixture)
    expect(result.status).toBe(1)
    expect(result.stderr).toContain("github-token")
  })

  it("blocks a private-key header", () => {
    const fixture = temporaryFixture(
      "fake-key.txt",
      `${"-----BEGIN "}PRIVATE KEY-----\n`,
    )
    const result = runSecretScan(fixture)
    expect(result.status).toBe(1)
    expect(result.stderr).toContain("private-key-block")
  })
})
