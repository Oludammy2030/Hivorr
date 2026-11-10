#!/usr/bin/env node
// Playwright E2E for the deployed slice (EP-01-063).
//
// Reproduces the unauthenticated exit-gate path against the deployed artifact:
//   - the slice entry is served;
//   - the login screen renders;
//   - an invalid sign-in shows a labelled error (not a 5xx);
//   - an unknown route renders the real 404;
//   - an anonymous visit to `/` lands on `/login`.
//
// If E2E_EMAIL and E2E_PASSWORD are set, it also signs in, loads the activity
// switcher and activates one activity. Those values are never printed.
//
// Usage:
//   node scripts/e2e-slice.mjs --base https://staging.hivorr.com

import { mkdirSync } from "node:fs"
import path from "node:path"

import { chromium } from "@playwright/test"

const args = process.argv.slice(2)
const index = args.indexOf("--base")
const base = (
  index >= 0 && args[index + 1] ? args[index + 1] : "https://staging.hivorr.com"
).replace(/\/+$/, "")
const email = process.env.E2E_EMAIL
const password = process.env.E2E_PASSWORD

const browser = await chromium.launch()
const page = await browser.newPage({ viewport: { width: 1280, height: 900 } })
const failures = []

function check(condition, message) {
  if (condition) console.log(`PASS  ${message}`)
  else {
    failures.push(message)
    console.error(`FAIL  ${message}`)
  }
}

async function go(route) {
  await page.evaluate((next) => {
    window.history.pushState({}, "", next)
    window.dispatchEvent(new PopStateEvent("popstate"))
  }, route)
}

try {
  const entry = await page.goto(`${base}/slice.html`, {
    waitUntil: "domcontentloaded",
  })
  const entryHtml = (await entry?.text()) ?? ""
  const served = entry?.status() === 200 && entryHtml.includes("/assets/slice-")
  check(served, "slice entry is served from the slice bundle")
  if (!served) {
    throw new Error(
      "slice.html is not deployed with its own bundle (F-50); the host served a fallback",
    )
  }

  await page.addInitScript(() => {
    window.history.replaceState({}, "", "/login")
  })
  await page.goto(`${base}/slice.html`, { waitUntil: "load" })
  await page.getByText("Welcome back").waitFor({ timeout: 20_000 })
  check(true, "login screen renders")

  const emailField = page.getByLabel("Email")
  const passwordField = page.getByLabel("Password")
  await emailField.fill(`e2e-${Date.now()}@example.test`)
  await passwordField.fill("not-the-password")
  await page.getByRole("button", { name: "Sign In" }).click()
  const alert = page.getByRole("alert")
  await alert.waitFor({ timeout: 15_000 })
  check(
    (await alert.textContent())?.includes("incorrect"),
    "invalid sign-in is labelled",
  )

  await go("/not-a-route")
  await page.getByText("Page not found").waitFor({ timeout: 10_000 })
  check(true, "unknown route renders the 404")

  await go("/")
  await page.waitForURL("**/login", { timeout: 15_000 })
  check(
    new URL(page.url()).pathname === "/login",
    "anonymous bootstrap redirects to login",
  )

  if (email && password) {
    await emailField.fill(email)
    await passwordField.fill(password)
    await page.getByRole("button", { name: "Sign In" }).click()
    await page
      .getByText("How do you want to use Hivorr today?")
      .waitFor({ timeout: 20_000 })
    check(true, "authenticated session reaches the activity switcher")
    await page.getByRole("button", { name: /I Want to Hire/ }).click()
    await page
      .getByText(/is now active|already active|permission|session expired/i)
      .first()
      .waitFor({ timeout: 20_000 })
    check(true, "activity activation answers")
  } else {
    console.log(
      "NOTE  E2E_EMAIL/E2E_PASSWORD are not set; authenticated checks skipped",
    )
  }
} catch (error) {
  failures.push(error instanceof Error ? error.message : String(error))
  mkdirSync(path.join("artifacts", "e2e"), { recursive: true })
  await page.screenshot({ path: path.join("artifacts", "e2e", "failure.png") })
  console.error(`FAIL  ${failures.at(-1)}`)
} finally {
  await browser.close()
}

if (failures.length) {
  console.error(`\ne2e:slice: FAILED — ${failures.length} check(s)`)
  process.exit(1)
}
console.log("\ne2e:slice: OK")
