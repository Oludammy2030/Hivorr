/**
 * Design-system boundary for the four portal bundles.
 *
 * The prototype remains the visual authority. `src/app/App.tsx` and
 * `src/styles/theme.css` are still the source of the design language; the
 * extracted primitives and token exports move here in EP-01-051, guarded by
 * visual regression.
 *
 * This package deliberately contains no UI yet. It exists from EP-01-002 so
 * that imports have a stable boundary and the shadcn kit cannot become a
 * second design source.
 */

export const DESIGN_PACKAGE_NAME = "@hivorr/design" as const
