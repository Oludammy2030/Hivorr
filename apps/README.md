# Portal applications

`apps/control`, `apps/staff`, and `apps/partner` are the build targets for the
three privilege-separated portals. The main `web` bundle remains at the
repository root because the Figma Make wrapper builds it.

**Current state:** foundation scaffolds only. Each app renders a plain
"not implemented" page with no product design tokens. They are not deployable
products yet. Product screens arrive after the design-system extraction
(`EP-01-051`), routing (`EP-01-052`), and portal implementation phases.

Rules:

- An app never imports another app.
- An app never imports `server/`.
- Shared contracts come from `@hivorr/shared`.
- Product UI comes from `@hivorr/design`; do not create a second design system.
- The root `web` app stays where it is while Figma Make is in use.
