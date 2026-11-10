#!/usr/bin/env node
// Live staging topology probe (EP-01-060).
//
// Verifies the four staging hosts resolve, serve a valid certificate for their
// own name, and apply the recorded access rule: the main host is public, the
// three privileged hosts challenge through Cloudflare Access. It also checks
// that `/api/v1/health/live` reaches the staging API.
//
// It reads no credential, follows no redirect, and prints no Access token.
// Run it manually or from the staging runbook; it is not part of PR CI because
// it depends on a live environment.

import { readFileSync } from "node:fs"
import https from "node:https"
import path from "node:path"

const topology = JSON.parse(
  readFileSync(path.resolve("config/environments.json"), "utf8"),
)
const staging = topology.environments?.staging
if (!staging) {
  console.error("staging-hosts: config/environments.json has no staging entry")
  process.exit(2)
}

const hosts = staging.hosts
const PROTECTED = ["control", "staff", "partner"]
const issues = []
const summary = []

function request(host, requestPath, method = "GET") {
  return new Promise((resolve) => {
    const req = https.request(
      {
        host,
        port: 443,
        path: requestPath,
        method,
        timeout: 15_000,
        headers: { "user-agent": "hivorr-staging-probe" },
      },
      (response) => {
        const certificate = response.socket.getPeerCertificate()
        let body = ""
        response.setEncoding("utf8")
        response.on("data", (chunk) => {
          if (body.length < 4000) body += chunk
        })
        response.on("end", () =>
          resolve({
            status: response.statusCode,
            locationHost: response.headers.location
              ? new URL(response.headers.location).hostname
              : null,
            certificate,
            body,
          }),
        )
      },
    )
    req.on("timeout", () => req.destroy(new Error("timeout")))
    req.on("error", (error) => resolve({ error: error.message }))
    req.end()
  })
}

for (const [application, host] of Object.entries(hosts)) {
  const result = await request(host, "/")
  if (result.error) {
    issues.push(`${host}: ${result.error}`)
    continue
  }

  const san = result.certificate?.subjectaltname ?? ""
  if (!san.split(", ").includes(`DNS:${host}`)) {
    issues.push(`${host}: certificate does not cover ${host} (${san})`)
  }
  if (!result.certificate?.valid_to) {
    issues.push(`${host}: no certificate validity date`)
  }

  const protectedApplication = PROTECTED.includes(application)
  if (protectedApplication) {
    const challenged =
      (result.status >= 300 && result.status < 400) || result.status === 403
    if (
      !challenged ||
      !result.locationHost?.endsWith(".cloudflareaccess.com")
    ) {
      issues.push(
        `${host}: expected a Cloudflare Access challenge, got ${result.status}`,
      )
    }
  } else if (result.status !== 200) {
    issues.push(`${host}: expected 200, got ${result.status}`)
  }

  summary.push({
    application,
    host,
    status: result.status,
    access: protectedApplication,
    tls: san,
    validTo: result.certificate?.valid_to,
  })
}

const api = await request(hosts.main, "/api/v1/health/live")
if (api.error) {
  issues.push(`staging API health: ${api.error}`)
} else if (api.status !== 200 || !/"environment":"staging"/.test(api.body)) {
  issues.push(
    `staging API health: expected 200 with environment=staging, got ${api.status}`,
  )
} else {
  summary.push({
    application: "api",
    host: `${hosts.main} (edge /api)`,
    status: api.status,
    access: false,
    tls: "edge",
    validTo: "",
  })
}

if (issues.length) {
  console.error("staging-hosts: FAILED")
  for (const issue of issues) console.error(`- ${issue}`)
  process.exit(1)
}

console.log(`staging-hosts: OK — ${summary.length} live check(s)`)
for (const entry of summary) {
  console.log(
    `  ${entry.application.padEnd(8)} ${entry.host.padEnd(34)} ${entry.status}  access=${entry.access}  tls=${entry.tls}`,
  )
}
