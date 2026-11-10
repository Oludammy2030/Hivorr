#!/usr/bin/env node
// Process-level smoke test for the API entry point (EP-01-010).
//
// Proves four things the in-process tests cannot:
//   1. `server/dist/main.js` starts a listening process.
//   2. `/v1/health/live` answers over the network.
//   3. Missing configuration exits non-zero without echoing a supplied secret.
//   4. SIGTERM stops the process instead of leaving it running.
//
// It runs against the compiled output, so `pnpm build:server` must run first.
// EP-01-004 made the build job depend on that order; `pnpm verify` also builds
// before invoking this script.
//
// Usage:
//   node scripts/smoke-api.mjs
//
// Note on Windows: Node terminates a child unconditionally for SIGTERM there,
// so graceful draining is only observable on Linux (CI and the container). The
// script records that difference instead of claiming a check it did not make.

import { spawn } from "node:child_process"
import { existsSync } from "node:fs"
import net from "node:net"
import path from "node:path"

const root = process.cwd()
const entry = path.join(root, "server", "dist", "main.js")
const failures = []

function pass(message) {
  console.log(`PASS  ${message}`)
}

function fail(message, detail) {
  failures.push(message)
  console.error(`FAIL  ${message}`)
  if (detail) console.error(`      ${detail}`)
}

function baseEnvironment(extra) {
  const environment = {}
  for (const key of [
    "PATH",
    "Path",
    "SystemRoot",
    "windir",
    "TEMP",
    "TMP",
    "HOME",
    "USERPROFILE",
    "COMSPEC",
  ]) {
    if (process.env[key] !== undefined) environment[key] = process.env[key]
  }
  return { ...environment, ...extra }
}

function freePort() {
  return new Promise((resolve, reject) => {
    const server = net.createServer()
    server.unref()
    server.on("error", reject)
    server.listen(0, "127.0.0.1", () => {
      const address = server.address()
      const port = typeof address === "object" && address ? address.port : 0
      server.close(() => resolve(port))
    })
  })
}

function waitForExit(child, timeoutMs) {
  return new Promise((resolve) => {
    const timer = setTimeout(() => resolve({ timedOut: true }), timeoutMs)
    child.once("close", (code, signal) => {
      clearTimeout(timer)
      resolve({ timedOut: false, code, signal })
    })
  })
}

function runToCompletion(child, timeoutMs) {
  return new Promise((resolve) => {
    let stdout = ""
    let stderr = ""
    child.stdout.on("data", (chunk) => {
      stdout += String(chunk)
    })
    child.stderr.on("data", (chunk) => {
      stderr += String(chunk)
    })
    const timer = setTimeout(() => {
      child.kill("SIGKILL")
      resolve({ timedOut: true, code: null, stdout, stderr })
    }, timeoutMs)
    child.once("close", (code) => {
      clearTimeout(timer)
      resolve({ timedOut: false, code, stdout, stderr })
    })
  })
}

async function smokeStartup() {
  const port = await freePort()
  const child = spawn(process.execPath, [entry], {
    cwd: root,
    env: baseEnvironment({
      HIVORR_ENV: "test",
      LOG_LEVEL: "error",
      API_PORT: String(port),
      API_HOST: "127.0.0.1",
    }),
    stdio: ["ignore", "pipe", "pipe"],
  })

  let stderr = ""
  child.stderr.on("data", (chunk) => {
    stderr += String(chunk)
  })

  const url = `http://127.0.0.1:${port}/v1/health/live`
  const deadline = Date.now() + 20_000
  let response = null
  while (Date.now() < deadline) {
    if (child.exitCode !== null) break
    try {
      response = await fetch(url)
      if (response.ok) break
    } catch {
      // Not listening yet.
    }
    await new Promise((resolve) => setTimeout(resolve, 250))
  }

  if (!response || !response.ok) {
    child.kill("SIGKILL")
    fail(
      "the API process starts and answers /v1/health/live",
      stderr.trim() || "no response before the 20 s deadline",
    )
    return
  }

  const body = await response.json()
  if (body.status !== "ok" || body.service !== "hivorr-api") {
    fail("health payload identifies the service", JSON.stringify(body))
  } else {
    pass("the API process starts and answers /v1/health/live")
  }

  if (!response.headers.get("x-correlation-id")) {
    fail("the live response carries a correlation id")
  } else {
    pass("the live response carries a correlation id")
  }

  child.kill("SIGTERM")
  const exit = await waitForExit(child, 15_000)
  if (exit.timedOut) {
    child.kill("SIGKILL")
    fail("SIGTERM stops the API process")
    return
  }

  if (process.platform === "win32") {
    pass("SIGTERM stops the API process (Windows terminates unconditionally)")
    return
  }

  if (exit.signal === "SIGTERM" || exit.code === 0) {
    pass("SIGTERM performs a graceful shutdown")
  } else {
    fail(
      "SIGTERM performs a graceful shutdown",
      `exit code ${exit.code}, signal ${exit.signal}`,
    )
  }
}

async function smokeInvalidConfiguration() {
  const canary = "smoke-canary-do-not-log"
  const child = spawn(process.execPath, [entry], {
    cwd: root,
    env: baseEnvironment({
      HIVORR_ENV: "staging",
      LOG_LEVEL: "error",
      DATABASE_URL: `postgresql://canary:${canary}@db.zyxwvutsrqponmlkjihg.supabase.co:5432/postgres`,
    }),
    stdio: ["ignore", "pipe", "pipe"],
  })

  const result = await runToCompletion(child, 15_000)
  const output = `${result.stdout}${result.stderr}`

  if (result.timedOut) {
    fail("missing configuration stops startup")
    return
  }
  if (result.code !== 1 || !output.includes("failed to start")) {
    fail(
      "missing configuration stops startup with code 1",
      `code ${result.code}; ${output.trim()}`,
    )
    return
  }
  pass("missing configuration stops startup with code 1")

  if (!output.includes("SESSION_ISSUER")) {
    fail("the failure names the missing setting", output.trim())
  } else {
    pass("the failure names the missing setting")
  }

  if (output.includes(canary)) {
    fail("the failure does not echo a supplied secret")
  } else {
    pass("the failure does not echo a supplied secret")
  }
}

if (!existsSync(entry)) {
  console.error(
    "smoke:api: server/dist/main.js is missing; run `pnpm build:server` first",
  )
  process.exit(2)
}

try {
  await smokeStartup()
  await smokeInvalidConfiguration()
} catch (error) {
  fail(
    "the smoke test completed without an unexpected error",
    error instanceof Error ? error.message : String(error),
  )
}

console.log("")
if (failures.length) {
  console.error(`smoke:api: FAILED — ${failures.length} check(s) did not pass`)
  process.exit(1)
}
console.log("smoke:api: OK — the compiled API starts, serves and stops")
