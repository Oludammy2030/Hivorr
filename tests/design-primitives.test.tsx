import { readFileSync, readdirSync } from "node:fs"
import path from "node:path"

import type { ReactElement } from "react"
import { renderToStaticMarkup } from "react-dom/server"
import { describe, expect, it } from "vitest"

import {
  Button,
  Pill,
  TextField,
  colorTokens,
  fontTokens,
  radiusTokens,
} from "../packages/design/src/index"

const designRoot = path.resolve("packages/design/src")
const theme = readFileSync(path.resolve("src/styles/theme.css"), "utf8")

function designSources(directory = designRoot): string[] {
  return readdirSync(directory, { withFileTypes: true }).flatMap((entry) => {
    const full = path.join(directory, entry.name)
    if (entry.isDirectory()) return designSources(full)
    return /\.(?:ts|tsx)$/.test(entry.name) ? [readFileSync(full, "utf8")] : []
  })
}

function declaredTokens(): Set<string> {
  return new Set(
    [...theme.matchAll(/^\s*(--[a-z0-9-]+)\s*:/gim)].map(
      (match) => match[1] as string,
    ),
  )
}

function referencedTokens(): Set<string> {
  const references = new Set<string>()
  for (const source of designSources()) {
    for (const match of source.matchAll(/var\((--[a-z0-9-]+)\)/g)) {
      references.add(match[1] as string)
    }
  }
  return references
}

function withoutComments(source: string): string {
  return source.replace(/\/\*[\s\S]*?\*\//g, "").replace(/^\s*\/\/.*$/gm, "")
}

function markup(element: ReactElement): string {
  return renderToStaticMarkup(element)
}

describe("design token discipline", () => {
  it("adds no raw colour outside the theme layer", () => {
    for (const source of designSources()) {
      const code = withoutComments(source)
      expect(code).not.toMatch(/#[0-9a-f]{3,8}\b/i)
      expect(code).not.toMatch(/\brgba?\(/i)
      expect(code).not.toMatch(/\bhsla?\(/i)
    }
  })

  it("references only tokens the theme declares", () => {
    const declared = declaredTokens()
    const missing = [...referencedTokens()].filter(
      (token) => !declared.has(token),
    )
    expect(missing).toEqual([])
  })

  it("resolves the primitive palette to theme references", () => {
    expect(colorTokens.brand).toBe("var(--hivorr-blue)")
    expect(colorTokens.surface).toBe("var(--hivorr-surface)")
    expect(fontTokens.display).toBe("var(--hivorr-font-display)")
    expect(radiusTokens.control).toBe("var(--radius)")
  })
})

describe("Button", () => {
  it("renders the prototype's primary large button", () => {
    const html = markup(<Button size="lg">Sign In</Button>)
    expect(html).toContain("Sign In")
    expect(html).toContain("background:var(--hivorr-blue)")
    expect(html).toContain("color:var(--hivorr-surface)")
    expect(html).toContain("padding:15px 24px")
    expect(html).toContain("font-size:16px")
    expect(html).toContain("border-radius:var(--radius)")
    expect(html).toContain('type="button"')
  })

  it("keeps every variant and size", () => {
    expect(markup(<Button variant="secondary">A</Button>)).toContain(
      "background:var(--hivorr-blue-tint)",
    )
    expect(markup(<Button variant="ghost">A</Button>)).toContain(
      "background:var(--hivorr-surface-subtle)",
    )
    expect(markup(<Button variant="danger">A</Button>)).toContain(
      "background:var(--hivorr-red-tint)",
    )
    expect(markup(<Button size="sm">A</Button>)).toContain("padding:7px 14px")
    expect(markup(<Button size="md">A</Button>)).toContain("padding:12px 20px")
  })

  it("renders the disabled state", () => {
    const html = markup(<Button disabled>A</Button>)
    expect(html).toContain("disabled")
    expect(html).toContain("opacity:0.65")
  })
})

describe("TextField", () => {
  it("renders the prototype's field and associates the label", () => {
    const html = markup(
      <TextField label="Email" placeholder="you@example.com" />,
    )
    expect(html).toContain(">Email</label>")
    expect(html).toContain('placeholder="you@example.com"')
    expect(html).toContain("background:var(--hivorr-surface-subtle)")
    expect(html).toContain("padding:13px 14px")
    expect(html).toContain("border:1.5px solid transparent")
    expect(html).toContain('for="')
    expect(html).toContain('id="')
  })
})

describe("Pill", () => {
  it("renders a brand pill with the label as its title", () => {
    const html = markup(<Pill tone="brand">One account</Pill>)
    expect(html).toContain("One account")
    expect(html).toContain('title="One account"')
    expect(html).toContain("background:var(--hivorr-blue-tint)")
    expect(html).toContain("color:var(--hivorr-blue)")
    expect(html).toContain("border-radius:20px")
  })

  it("defaults to the neutral tone", () => {
    expect(markup(<Pill>Queued</Pill>)).toContain(
      "background:var(--hivorr-surface-subtle)",
    )
  })
})
