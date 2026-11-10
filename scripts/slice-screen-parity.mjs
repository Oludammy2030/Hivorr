#!/usr/bin/env node
// Screen parity for the slice (EP-01-053).
//
// Compares the extracted sign-in screen with the approved prototype login
// screenshot at 375 / 768 / 1280. Both pages are served from the production
// build; the slice entry is `/slice.html` and is routed to `/login` before the
// app mounts. A mismatch fails.
//
// Usage:
//   pnpm build
//   node scripts/slice-screen-parity.mjs

import { spawn } from "node:child_process"
import { existsSync, mkdirSync, writeFileSync } from "node:fs"
import path from "node:path"

import { chromium } from "@playwright/test"

import { decodePng } from "./lib/png.mjs"

const PORT = 4174
const BASE_URL = `http://127.0.0.1:${PORT}`
const WIDTHS = [375, 768, 1280]
const HEIGHT = 900

if (!existsSync(path.join("dist", "slice.html"))) {
  console.error(
    "slice:parity: dist/slice.html is missing. Run `pnpm build` first.",
  )
  process.exit(2)
}

const vite = spawn(
  process.execPath,
  [
    path.join("node_modules", "vite", "bin", "vite.js"),
    "preview",
    "--host",
    "127.0.0.1",
    "--port",
    String(PORT),
    "--strictPort",
  ],
  { stdio: "ignore" },
)

async function waitForServer(url, timeoutMs = 30_000) {
  const started = Date.now()
  while (Date.now() - started < timeoutMs) {
    try {
      const response = await fetch(url)
      if (response.ok) return
    } catch {
      // not listening yet
    }
    await new Promise((resolve) => setTimeout(resolve, 150))
  }
  throw new Error(`preview server did not start at ${url}`)
}

const failures = []

try {
  await waitForServer(`${BASE_URL}/`)
  const browser = await chromium.launch()
  const context = await browser.newContext({
    viewport: { width: WIDTHS[0], height: HEIGHT },
    deviceScaleFactor: 1,
    colorScheme: "light",
    locale: "en-GB",
    timezoneId: "UTC",
    reducedMotion: "reduce",
  })

  await context.route("**/*", (route) => {
    const url = new URL(route.request().url())
    const local = url.origin === BASE_URL
    const fonts =
      url.hostname === "fonts.googleapis.com" ||
      url.hostname === "fonts.gstatic.com"
    return local || fonts ? route.continue() : route.abort()
  })

  for (const width of WIDTHS) {
    const prototype = await context.newPage()
    await prototype.setViewportSize({ width, height: HEIGHT })
    await prototype.goto(`${BASE_URL}/`, { waitUntil: "load" })
    await prototype.getByText("Skip intro").waitFor({ timeout: 20_000 })
    await prototype.getByText("Skip intro").click()
    await prototype.getByText("Welcome back").waitFor({ timeout: 10_000 })
    await prototype.mouse.move(0, 0)
    await settle(prototype)
    const expected = await prototype.screenshot({ caret: "hide" })

    const slice = await context.newPage()
    await slice.setViewportSize({ width, height: HEIGHT })
    await slice.addInitScript(() => {
      window.history.replaceState({}, "", "/login")
    })
    await slice.goto(`${BASE_URL}/slice.html`, { waitUntil: "load" })
    await slice.getByText("Welcome back").waitFor({ timeout: 15_000 })
    await slice.mouse.move(0, 0)
    await settle(slice)
    const actual = await slice.screenshot({ caret: "hide" })

    const left = decodePng(expected)
    const right = decodePng(actual)
    if (
      left.width !== right.width ||
      left.height !== right.height ||
      !buffersEqual(left.data, right.data)
    ) {
      save(width, expected, actual)
      failures.push(`login ${width}px differs from the approved baseline`)
    }

    await prototype.close()
    await slice.close()
  }

  await browser.close()
} finally {
  vite.kill()
}

if (failures.length) {
  console.error("slice:parity: FAILED")
  for (const failure of failures) console.error(`- ${failure}`)
  process.exit(1)
}

console.log(
  `slice:parity: OK — sign-in matches the prototype at ${WIDTHS.join("/")} px`,
)

async function settle(page) {
  await page.addStyleTag({
    content:
      "*,*::before,*::after{animation:none!important;transition:none!important;caret-color:transparent!important}",
  })
  await page.evaluate(async () => {
    await document.fonts.ready
    await new Promise((resolve) =>
      requestAnimationFrame(() => requestAnimationFrame(resolve)),
    )
  })
  const loaded = await page.evaluate(
    () =>
      document.fonts.check('400 16px "Inter"') &&
      document.fonts.check('800 16px "Plus Jakarta Sans"'),
  )
  if (!loaded) throw new Error("webfonts did not load")
}

function save(width, expected, actual) {
  const directory = path.join("artifacts", "slice-parity")
  mkdirSync(directory, { recursive: true })
  writeFileSync(path.join(directory, `login-${width}-prototype.png`), expected)
  writeFileSync(path.join(directory, `login-${width}-slice.png`), actual)
}

function buffersEqual(left, right) {
  if (left.length !== right.length) return false
  for (let index = 0; index < left.length; index += 1) {
    if (left[index] !== right[index]) return false
  }
  return true
}
