# Hivorr design system

The single design-system boundary for the four application bundles.

**Current state (EP-01-051):** tokens and the three primitives the EP-01 slice uses —
`Button`, `TextField`, `Pill`. The prototype remains the visual authority:
`src/app/App.tsx` and `src/styles/theme.css`.

## Rules

- `src/styles/theme.css` is the only place that defines a colour value. Tokens here are
  `var(--hivorr-*)` references; this package must contain no hex, `rgb()`, `hsl()` or second palette.
- Only primitives the slice actually uses belong here. Add one when a screen needs it, not before.
- A primitive is extracted from the prototype as-is: same paddings, sizes, radii, weights and
  colours. Literals become token references; nothing is restyled.
- The shadcn kit under `src/app/components/ui` stays dormant. It is not a design source, and this
  package must not import it.
- No dark mode, no second icon set, no CSS-in-JS library, no component library.

## Evidence

| Check | Command | What it proves |
| --- | --- | --- |
| Token discipline | `pnpm test -- tests/design-primitives.test.tsx` | No raw colour; every `var(--…)` exists in `theme.css` |
| Primitive parity | `pnpm test:design-parity` | Each primitive matches the prototype exactly at 375 / 768 / 1280 (computed styles and pixels) |
| Screen baseline | `pnpm visual:check` | Extracted screens do not move the approved baseline |

`test:design-parity` loads `visual/primitives/`, a test-only gallery. It is not part of a production
build.
