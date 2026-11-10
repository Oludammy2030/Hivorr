#!/usr/bin/env node
// Primitive parity against the prototype (EP-01-051).
//
// Renders the extracted primitives in `visual/primitives/` and compares each
// one, at 375 / 768 / 1280, with the corresponding element in the running
// prototype. Each pair is moved to the same fixed, integer-aligned wrapper
// before measurement, so a difference is a style difference and never a
// subpixel placement artefact. Computed styles and the element screenshot must
// both match exactly.
//
// The gallery uses the Vite dev server only for this check; it is never part of
// a production build.

import { mkdirSync, writeFileSync } from "node:fs"
import path from "node:path"

import { createServer } from "vite"
import { chromium } from "@playwright/test"

import { decodePng } from "./lib/png.mjs"

const PORT = 5199
const BASE_URL = `http://127.0.0.1:${PORT}`
const WIDTHS = [375, 768, 1280]
const HEIGHT = 900

// Values that must match exactly. `fontFamily` is normalised to its first
// family because the theme token carries fallbacks the prototype spells
// differently, while the rendered family is identical.
const STYLE_PROPERTIES = [
  "color",
  "backgroundColor",
  "borderTopWidth",
  "borderTopStyle",
  "borderTopColor",
  "borderRadius",
  "paddingTop",
  "paddingRight",
  "paddingBottom",
  "paddingLeft",
  "fontSize",
  "fontWeight",
  "display",
  "alignItems",
  "justifyContent",
  "gap",
  "letterSpacing",
  "lineHeight",
  "opacity",
  "whiteSpace",
  "verticalAlign",
  "overflow",
  "textOverflow",
  "maxWidth",
  "width",
]

const server = await createServer({
  logLevel: "silent",
  server: { host: "127.0.0.1", port: PORT, strictPort: true },
})

await server.listen()

const browser = await chromium.launch()
const context = await browser.newContext({
  viewport: { width: WIDTHS[0], height: HEIGHT },
  deviceScaleFactor: 1,
  colorScheme: "light",
  locale: "en-GB",
  timezoneId: "UTC",
  reducedMotion: "reduce",
})

const failures = []
let checks = 0

try {
  for (const width of WIDTHS) {
    const gallery = await context.newPage()
    await gallery.setViewportSize({ width, height: HEIGHT })
    await gallery.goto(`${BASE_URL}/visual/primitives/index.html`, {
      waitUntil: "load",
    })
    await settle(gallery)

    const login = await openLogin(width)
    await compare(
      `button (${width}px)`,
      login.getByRole("button", { name: "Sign In" }),
      gallery.locator('[data-parity="button-primary-lg"] button'),
      "button",
    )
    await compare(
      `text field (${width}px)`,
      login.locator('input[placeholder="you@example.com"]'),
      gallery.locator('[data-parity="text-field"] input'),
      "text-field",
    )
    await login.close()

    const activities = await openActivities(width)
    await compare(
      `pill (${width}px)`,
      activities.locator('span[title="One account · Many activities"]'),
      gallery.locator('[data-parity="pill-brand"] span'),
      "pill",
    )
    await activities.close()
    await gallery.close()
  }
} finally {
  await browser.close()
  await server.close()
}

if (failures.length) {
  console.error(`design:parity: FAILED — ${failures.length} mismatch(es)`)
  for (const failure of failures) console.error(`- ${failure}`)
  process.exit(1)
}

console.log(
  `design:parity: OK — ${checks} exact comparison(s) across ${WIDTHS.join("/")} px`,
)

async function openLogin(width) {
  const page = await context.newPage()
  await page.setViewportSize({ width, height: HEIGHT })
  await page.goto(`${BASE_URL}/`, { waitUntil: "load" })
  await page.getByText("Skip intro").waitFor({ timeout: 20_000 })
  await page.getByText("Skip intro").click()
  await page.getByText("Welcome back").waitFor({ timeout: 10_000 })
  await settle(page)
  await page.mouse.move(0, 0)
  return page
}

async function openActivities(width) {
  const page = await openLogin(width)
  await page.getByRole("button", { name: "Sign In" }).click()
  await page
    .getByText("How do you want to use Hivorr today?")
    .waitFor({ timeout: 10_000 })
  await settle(page)
  await page.mouse.move(0, 0)
  return page
}

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
      document.fonts.check('700 16px "Plus Jakarta Sans"'),
  )
  if (!loaded) throw new Error("the prototype webfonts did not load")
}

async function compare(label, prototypeElement, galleryElement, mode) {
  const naturalPrototypeBox = await prototypeElement.boundingBox()
  if (!naturalPrototypeBox) {
    failures.push(`${label}: missing bounding box`)
    return
  }
  const width = Math.ceil(naturalPrototypeBox.width)

  await normalise(prototypeElement, mode, width)
  await normalise(galleryElement, mode, width)

  const prototypeBox = await prototypeElement.boundingBox()
  const galleryBox = await galleryElement.boundingBox()
  if (!prototypeBox || !galleryBox) {
    failures.push(`${label}: missing bounding box`)
    return
  }
  for (const dimension of ["width", "height"]) {
    if (Math.abs(prototypeBox[dimension] - galleryBox[dimension]) > 0.01) {
      failures.push(
        `${label}: ${dimension} ${prototypeBox[dimension]} vs ${galleryBox[dimension]}`,
      )
    }
  }

  const prototypeStyles = await stylesOf(prototypeElement)
  const galleryStyles = await stylesOf(galleryElement)
  for (const property of STYLE_PROPERTIES) {
    if (prototypeStyles[property] !== galleryStyles[property]) {
      failures.push(
        `${label}: ${property} "${prototypeStyles[property]}" vs "${galleryStyles[property]}"`,
      )
    }
  }
  checks += 1

  const prototypePngBytes = await prototypeElement.screenshot()
  const galleryPngBytes = await galleryElement.screenshot()
  const prototypePng = decodePng(prototypePngBytes)
  const galleryPng = decodePng(galleryPngBytes)
  if (
    prototypePng.width !== galleryPng.width ||
    prototypePng.height !== galleryPng.height ||
    prototypePng.channels !== galleryPng.channels
  ) {
    saveArtifacts(label, prototypePngBytes, galleryPngBytes)
    failures.push(
      `${label}: screenshot ${prototypePng.width}x${prototypePng.height} vs ${galleryPng.width}x${galleryPng.height}`,
    )
  } else if (!imagesEqual(prototypePng.data, galleryPng.data)) {
    saveArtifacts(label, prototypePngBytes, galleryPngBytes)
    failures.push(`${label}: the element screenshots differ`)
  }

  await park(prototypeElement, mode)
  await park(galleryElement, mode)
}

/**
 * Move the control into a fixed wrapper at (0, 0) at the measured width. Both
 * sides then start from the same integer origin, which removes subpixel
 * placement differences from the comparison.
 */
async function normalise(element, mode, width) {
  await element.evaluate(
    (node, options) => {
      const host = options.mode === "text-field" ? node.parentElement : node
      if (!host?.parentElement) throw new Error("parity host has no parent")
      const wrapper = document.createElement("div")
      wrapper.dataset.parityWrapper = "true"
      wrapper.style.cssText = [
        "position:fixed",
        "left:0",
        "top:0",
        "margin:0",
        "padding:0",
        `width:${options.width}px`,
        "background:var(--hivorr-surface)",
        "z-index:2147483647",
        "box-sizing:border-box",
        options.mode === "pill"
          ? "display:flex;align-items:center"
          : "display:block",
      ].join(";")
      host.parentElement.insertBefore(wrapper, host)
      wrapper.appendChild(host)
      if (options.mode === "button") node.style.width = "100%"
    },
    { mode, width },
  )
}

async function park(element, mode) {
  await element.evaluate((node, controlMode) => {
    const host = controlMode === "text-field" ? node.parentElement : node
    const wrapper = host?.parentElement
    if (wrapper?.dataset.parityWrapper) wrapper.style.left = "-10000px"
  }, mode)
}

async function stylesOf(element) {
  return element.evaluate((node, properties) => {
    const style = window.getComputedStyle(node)
    const result = {}
    for (const property of properties) {
      const value = style[property]
      result[property] =
        property === "fontFamily"
          ? String(value)
              .split(",")[0]
              .trim()
              .replace(/^["']|["']$/g, "")
          : value
    }
    return result
  }, STYLE_PROPERTIES)
}

function imagesEqual(left, right) {
  if (left.length !== right.length) return false
  for (let index = 0; index < left.length; index += 1) {
    if (left[index] !== right[index]) return false
  }
  return true
}

function saveArtifacts(label, prototype, gallery) {
  const directory = path.join("artifacts", "design-parity")
  mkdirSync(directory, { recursive: true })
  const name = label.replace(/[^a-z0-9]+/gi, "-").toLowerCase()
  writeFileSync(path.join(directory, `${name}-prototype.png`), prototype)
  writeFileSync(path.join(directory, `${name}-gallery.png`), gallery)
}
