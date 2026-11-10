#!/usr/bin/env node
// Process-level smoke test for the worker entry point (EP-01-014).
//
// Proves:
//   1. `server/dist/worker.js` starts and serves liveness.
//   2. Queue health fails closed (503), not falsely healthy, with no database.
//   3. Missing worker configuration exits non-zero before doing work.
//   4. SIGTERM stops the process where the platform delivers it.
//
// It needs no Postgres: the worker health server is independent of the queue,
// and a refused connection is the expected unavailable state. The database
// behaviour is covered by the integration suite in CI.
//
// Usage:
//   node scripts/smoke-worker.mjs   (run `pnpm build:server` first)

import { spawn } from "node:child_process"
import { existsSync } from "node:fs"
import net from "node:net"
import path from "node:path"

const root = process.cwd()
const entry = path.join(root, "server", "dist", "worker.js")
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
      // A refused connection is fast and deterministic; the worker must stay
      // alive and report the queue as unavailable.
      DATABASE_URL: "postgres://postgres:postgres@127.0.0.1:1/postgres",
      WORKER_HEALTH_HOST: "127.0.0.1",
      WORKER_HEALTH_PORT: String(port),
      WORKER_POLL_INTERVAL_MS: "60000",
      LOG_LEVEL: "error",
    }),
    stdio: ["ignore", "pipe", "pipe"],
  })

  let stderr = ""
  child.stderr.on("data", (chunk) => {
    stderr += String(chunk)
  })

  const url = `http://127.0.0.1:${port}/health/live`
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
      "the worker process starts and answers /health/live",
      stderr.trim() || "no response before the 20 s deadline",
    )
    return
  }

  const body = await response.json()
  if (body.status !== "ok" || body.environment !== "test") {
    fail("liveness identifies the worker", JSON.stringify(body))
  } else {
    pass("the worker process starts and answers /health/live")
  }

  const queue = await fetch(`http://127.0.0.1:${port}/health/queue`)
  if (queue.status !== 503) {
    fail(
      "queue health fails closed without a database",
      `status ${queue.status}`,
    )
  } else {
    pass("queue health fails closed without a database")
  }

  child.kill("SIGTERM")
  const exit = await waitForExit(child, 15_000)
  if (exit.timedOut) {
    child.kill("SIGKILL")
    fail("SIGTERM stops the worker process")
    return
  }

  if (process.platform === "win32") {
    pass(
      "SIGTERM stops the worker process (Windows terminates unconditionally)",
    )
    return
  }
  if (exit.code === 0 || exit.signal === "SIGTERM") {
    pass("SIGTERM performs a graceful shutdown")
  } else {
    fail(
      "SIGTERM performs a graceful shutdown",
      `exit code ${exit.code}, signal ${exit.signal}`,
    )
  }
}

async function smokeInvalidConfiguration() {
  const child = spawn(process.execPath, [entry], {
    cwd: root,
    env: baseEnvironment({ HIVORR_ENV: "test" }),
    stdio: ["ignore", "pipe", "pipe"],
  })

  const result = await runToCompletion(child, 15_000)
  const output = `${result.stdout}${result.stderr}`

  if (result.timedOut) {
    fail("missing worker configuration stops startup")
    return
  }
  if (result.code !== 1 || !output.includes("failed to start")) {
    fail(
      "missing worker configuration exits with code 1",
      `code ${result.code}; ${output.trim()}`,
    )
    return
  }
  pass("missing worker configuration exits with code 1")

  if (!output.includes("WORKER_DATABASE_URL")) {
    fail("the failure names the missing worker setting", output.trim())
  } else {
    pass("the failure names the missing worker setting")
  }
}

if (!existsSync(entry)) {
  console.error(
    "smoke:worker: server/dist/worker.js is missing; run `pnpm build:server` first",
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
  console.error(
    `smoke:worker: FAILED — ${failures.length} check(s) did not pass`,
  )
  process.exit(1)
}
console.log("smoke:worker: OK — the compiled worker starts, reports and stops")
