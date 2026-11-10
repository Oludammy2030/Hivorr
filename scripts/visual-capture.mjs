#!/usr/bin/env node
// Deterministic screenshot capture for the prototype (EP-01-050).
//
// Serves the built prototype, drives the entry flow, and captures the approved
// screens at 375 / 768 / 1280. The same command produces the baseline and the
// current run, so both always share a browser build and viewport.
//
// Determinism controls:
//   - one pinned Playwright Chromium and one pinned runner platform (see
//     `.github/workflows/ci.yml`); the manifest records both;
//   - deviceScaleFactor 1, light colour scheme, UTC, reduced motion;
//   - animations and transitions disabled by injected CSS;
//   - only same-origin and Google Fonts requests are allowed;
//   - capture fails if Inter or Plus Jakarta Sans did not load, so a system
//     fallback can never enter a baseline silently.
//
// Usage:
//   pnpm build
//   node scripts/visual-capture.mjs --out visual/current
//   node scripts/visual-capture.mjs --out visual/baseline

import { spawn } from "node:child_process"
import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs"
import path from "node:path"

import { chromium } from "@playwright/test"

const WIDTHS = [375, 768, 1280]
const HEIGHT = 900
const PORT = 4173
const BASE_URL = `http://127.0.0.1:${PORT}`

const args = process.argv.slice(2)
const outIndex = args.indexOf("--out")
const out =
  outIndex >= 0 && args[outIndex + 1]
    ? path.resolve(args[outIndex + 1])
    : path.resolve("visual", "current")

if (!existsSync(path.join("dist", "index.html"))) {
  console.error(
    "visual:capture: dist/index.html is missing. Run `pnpm build` first.",
  )
  process.exit(2)
}

function waitForServer(url, timeoutMs = 30_000) {
  const started = Date.now()
  return new Promise((resolve, reject) => {
    const poll = async () => {
      try {
        const response = await fetch(url)
        if (response.ok) return resolve()
      } catch {
        // not listening yet
      }
      if (Date.now() - started > timeoutMs) {
        return reject(new Error(`preview server did not start at ${url}`))
      }
      setTimeout(poll, 150)
    }
    void poll()
  })
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

let exitCode = 0

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
    if (local || fonts) return route.continue()
    return route.abort()
  })

  mkdirSync(out, { recursive: true })

  for (const width of WIDTHS) {
    const page = await context.newPage()
    await page.setViewportSize({ width, height: HEIGHT })

    await page.goto(`${BASE_URL}/`, { waitUntil: "load" })
    await page.addStyleTag({
      content:
        "*,*::before,*::after{animation:none!important;transition:none!important;caret-color:transparent!important}html{scroll-behavior:auto!important}",
    })

    await page.getByText("Skip intro").waitFor({ timeout: 20_000 })
    await settle(page)
    await screenshot(page, `onboarding-${width}`)

    await page.getByText("Skip intro").click()
    await page.getByText("Welcome back").waitFor({ timeout: 10_000 })
    await settle(page)
    await screenshot(page, `login-${width}`)

    await page.getByRole("button", { name: "Sign In" }).click()
    await page
      .getByText("How do you want to use Hivorr today?")
      .waitFor({ timeout: 10_000 })
    await settle(page)
    await screenshot(page, `activity-select-${width}`)

    await page.close()
  }

  const browserVersion = browser.version()
  await browser.close()

  writeFileSync(
    path.join(out, "manifest.json"),
    `${JSON.stringify(
      {
        platform: process.platform,
        playwright: JSON.parse(
          readFileSync(
            path.join("node_modules", "@playwright", "test", "package.json"),
            "utf8",
          ),
        ).version,
        chromium: browserVersion,
        viewportHeights: HEIGHT,
        widths: WIDTHS,
        screens: ["onboarding", "login", "activity-select"],
        capturedAt: new Date().toISOString(),
      },
      null,
      2,
    )}\n`,
  )

  console.log(
    `visual:capture: wrote ${WIDTHS.length * 3} image(s) to ${path.relative(process.cwd(), out)}`,
  )
} catch (error) {
  exitCode = 1
  console.error(
    `visual:capture: FAILED — ${
      error instanceof Error ? error.message : String(error)
    }`,
  )
} finally {
  vite.kill()
}

process.exit(exitCode)

async function settle(page) {
  await page.evaluate(async () => {
    await document.fonts.ready
    await new Promise((resolve) =>
      requestAnimationFrame(() => requestAnimationFrame(resolve)),
    )
  })
  const loaded = await page.evaluate(
    () =>
      document.fonts.check('400 16px "Inter"') &&
      document.fonts.check('600 16px "Inter"') &&
      document.fonts.check('700 16px "Plus Jakarta Sans"') &&
      document.fonts.check('800 16px "Plus Jakarta Sans"'),
  )
  if (!loaded) {
    throw new Error(
      "the Inter and Plus Jakarta Sans webfonts did not load; refusing to capture a fallback",
    )
  }
}

async function screenshot(page, name) {
  await page.screenshot({
    path: path.join(out, `${name}.png`),
    animations: "disabled",
    caret: "hide",
    fullPage: false,
  })
}
