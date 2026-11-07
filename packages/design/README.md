# Hivorr design system

The single design-system boundary for the four application bundles.

**Current state:** boundary only. The prototype remains the visual authority:
`src/app/App.tsx` and `src/styles/theme.css`. Extracted primitives and token
exports move here in EP-01-051, guarded by visual regression.

Do not add a second palette, a second icon set, a CSS-in-JS library, or a
component kit here. The dormant shadcn kit is not a design source.
