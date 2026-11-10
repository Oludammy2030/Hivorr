import type { ReactNode } from "react"
import { BrowserRouter, Route, Routes } from "react-router"

import { NotFound } from "./not-found"
import { SLICE_ROUTES, type SliceRouteId } from "./route-manifest"

export type SliceScreens = Readonly<Partial<Record<SliceRouteId, ReactNode>>>

/**
 * The only reachable route table for the EP-01 slice. A slice route without a
 * screen is deliberately not registered, so it resolves to the 404 instead of
 * rendering a blank page. Every other approved route family is absent and
 * therefore unreachable until its own phase.
 */
export function SliceRoutes({ screens }: { readonly screens: SliceScreens }) {
  return (
    <Routes>
      {SLICE_ROUTES.map((route) => {
        const screen = screens[(route.id as SliceRouteId)]
        return screen ? (
          <Route key={route.id} path={route.path} element={screen} />
        ) : null
      })}
      <Route path="*" element={<NotFound />} />
    </Routes>
  )
}

export function SliceBrowserRouter({
  screens,
}: {
  readonly screens: SliceScreens
}) {
  return (
    <BrowserRouter>
      <SliceRoutes screens={screens} />
    </BrowserRouter>
  )
}
