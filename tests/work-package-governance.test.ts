import { execFileSync } from "node:child_process"
import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs"
import { tmpdir } from "node:os"
import path from "node:path"
import { afterAll, describe, expect, it } from "vitest"

const root = process.cwd()
const script = path.join(root, "scripts/check-work-packages.mjs")
const planDirectory = "documents/Engineering-Execution/Engineering-Phase-Plan"
const taskDirectory = "documents/Task-Implementation"
const temporaryDirectories: string[] = []

function fixture(files: Record<string, string>): string {
  const directory = mkdtempSync(path.join(tmpdir(), "hivorr-work-packages-"))
  temporaryDirectories.push(directory)

  for (const [name, content] of Object.entries(files)) {
    const file = path.join(directory, name)
    mkdirSync(path.dirname(file), { recursive: true })
    writeFileSync(file, content, "utf8")
  }

  return directory
}

function run(directory: string) {
  try {
    const stdout = execFileSync(
      process.execPath,
      [script, "--root", directory],
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

describe("work-package governance", () => {
  it("passes on the repository's phase plans and task folders", () => {
    const result = run(root)

    expect(result.status).toBe(0)
    expect(result.stdout).toContain("work-package governance: PASS")
  })

  it("blocks a contiguous phase plan with a missing identifier", () => {
    const directory = fixture({
      [`${planDirectory}/EP-99 - Fixture.md`]: [
        "# Fixture",
        "#### EP-99-001 - One",
        "#### EP-99-003 - Three",
      ].join("\n"),
      [`${taskDirectory}/EP-99/.keep`]: "",
    })

    const result = run(directory)

    expect(result.status).toBe(1)
    expect(result.stderr).toContain("EP-99 is contiguous but missing 002")
  })

  it("blocks an EP-01 identifier in the wrong stage block", () => {
    const directory = fixture({
      [`${planDirectory}/EP-01 - Fixture.md`]: [
        "# Fixture",
        "### Stage A - Entry",
        "#### EP-01-010 - Wrong block",
      ].join("\n"),
      [`${taskDirectory}/EP-01/.keep`]: "",
    })

    const result = run(directory)

    expect(result.status).toBe(1)
    expect(result.stderr).toContain("is in Stage A but belongs to block 010")
  })

  it("blocks a task document whose identifier is not in the plan", () => {
    const directory = fixture({
      [`${planDirectory}/EP-99 - Fixture.md`]: [
        "# Fixture",
        "#### EP-99-001 - One",
      ].join("\n"),
      [`${taskDirectory}/EP-99/EP-99-002 - Orphan.md`]: "# Orphan",
    })

    const result = run(directory)

    expect(result.status).toBe(1)
    expect(result.stderr).toContain(
      "EP-99-002 has no heading in its phase plan",
    )
  })

  it("blocks the same identifier appearing twice", () => {
    const directory = fixture({
      [`${planDirectory}/EP-99 - Fixture.md`]: [
        "# Fixture",
        "#### EP-99-001 - One",
        "#### EP-99-001 - Again",
      ].join("\n"),
      [`${taskDirectory}/EP-99/.keep`]: "",
    })

    const result = run(directory)

    expect(result.status).toBe(1)
    expect(result.stderr).toContain("duplicate EP-99-001")
  })
})
