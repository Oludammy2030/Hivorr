import { renderToStaticMarkup } from "react-dom/server"
import { StaticRouter } from "react-router"
import { describe, expect, it } from "vitest"

import {
  ApiClientError,
  type SessionResponse,
} from "../packages/api-client/src/index"
import {
  ANONYMOUS_SESSION,
  AppProviders,
  APPROVED_ROUTE_IDS,
  SLICE_ROUTE_IDS,
  SLICE_ROUTES,
  SESSION_QUERY_KEY,
  SliceRoutes,
  createQueryClient,
  isApprovedButUnreachable,
  matchSlicePath,
  sessionQueryOptions,
  sessionStateFrom,
  useSession,
} from "../packages/app-shell/src/index"
import { ROUTE_IDS } from "../packages/shared/src/index"

const screens = {
  home: <p>Home screen</p>,
  login: <p>Login screen</p>,
  signup: <p>Signup screen</p>,
  onboarding: <p>Onboarding screen</p>,
  activities: <p>Activities screen</p>,
}

function renderAt(path: string, supplied = screens): string {
  return renderToStaticMarkup(
    <StaticRouter location={path}>
      <SliceRoutes screens={supplied} />
    </StaticRouter>,
  )
}

describe("route manifest", () => {
  it("declares every approved route family", () => {
    expect([...APPROVED_ROUTE_IDS]).toEqual([...ROUTE_IDS])
  })

  it("registers only the slice paths", () => {
    expect(SLICE_ROUTE_IDS).toEqual([
      "home",
      "login",
      "signup",
      "onboarding",
      "forgot-password",
      "reset-password",
      "verify-email",
      "activities",
    ])
    expect(SLICE_ROUTES.map((route) => route.path)).toEqual([
      "/",
      "/login",
      "/signup",
      "/onboarding",
      "/forgot-password",
      "/reset-password",
      "/verify-email",
      "/activities",
    ])
  })

  it("matches slice paths and rejects everything else", () => {
    expect(matchSlicePath("/login")?.id).toBe("login")
    expect(matchSlicePath("/login/")?.id).toBe("login")
    expect(matchSlicePath("/")?.id).toBe("home")
    expect(matchSlicePath("/wallet")).toBeUndefined()
    expect(matchSlicePath("/p/example")).toBeUndefined()
    expect(matchSlicePath("/login/extra")).toBeUndefined()
  })

  it("distinguishes approved-but-unreachable from unknown", () => {
    expect(isApprovedButUnreachable("/wallet")).toBe(true)
    expect(isApprovedButUnreachable("/p/example")).toBe(true)
    expect(isApprovedButUnreachable("/login")).toBe(false)
    expect(isApprovedButUnreachable("/not-a-route")).toBe(false)
  })
})

describe("slice routes", () => {
  it("renders each slice screen at its path", () => {
    expect(renderAt("/")).toContain("Home screen")
    expect(renderAt("/login")).toContain("Login screen")
    expect(renderAt("/signup")).toContain("Signup screen")
    expect(renderAt("/onboarding")).toContain("Onboarding screen")
    expect(renderAt("/activities")).toContain("Activities screen")
  })

  it("renders a real 404 for an unknown path", () => {
    const html = renderAt("/not-a-route")
    expect(html).toContain("Page not found")
    expect(html).toContain("404")
    expect(html).toContain("does not match a Hivorr route")
  })

  it("renders a 404 for an approved route outside the slice", () => {
    for (const path of [
      "/wallet",
      "/messages",
      "/profile",
      "/explore/market",
    ]) {
      expect(renderAt(path)).toContain("Page not found")
    }
  })

  it("renders a 404 when a slice screen is not supplied", () => {
    const html = renderAt("/login", { home: <p>Home screen</p> })
    expect(html).toContain("Page not found")
    expect(html).not.toContain("Login screen")
  })
})

function session(overrides: Partial<SessionResponse> = {}): SessionResponse {
  return {
    sessionId: "session-1",
    accountId: "account-1",
    userId: "user-1",
    email: "person@example.test",
    audience: "app",
    environment: "staging",
    expiresAt: "2026-11-11T00:00:00.000Z",
    idleExpiresAt: "2026-11-10T12:00:00.000Z",
    account: {
      id: "account-1",
      email: "person@example.test",
      displayName: "Person",
      status: "active",
    },
    activities: [{ id: "market.buy", state: "ACTIVE" }],
    capabilities: ["session.read", "profile.read.self"],
    ...overrides,
  }
}

describe("session presentation state", () => {
  it("reads GET /v1/session as the only source", async () => {
    let calls = 0
    const data = session()
    const options = sessionQueryOptions({
      session: async () => {
        calls += 1
        return data
      },
    })
    expect(options.queryKey).toEqual(SESSION_QUERY_KEY)
    await options.queryFn()
    expect(calls).toBe(1)
  })

  it("starts loading without presenting a capability", () => {
    const state = sessionStateFrom({
      isPending: true,
      isError: false,
      data: undefined,
      error: null,
    })
    expect(state.status).toBe("loading")
    expect(state.canPresent("session.read")).toBe(false)
  })

  it("treats a 401 as anonymous", () => {
    const state = sessionStateFrom({
      isPending: false,
      isError: true,
      data: undefined,
      error: new ApiClientError(401, {
        error: { code: "UNAUTHENTICATED", message: "Sign in." },
      }),
    })
    expect(state.status).toBe("anonymous")
    expect(state.session).toBeNull()
    expect(state.presentedCapabilities).toEqual([])
  })

  it("surfaces a non-401 failure as an error state", () => {
    const state = sessionStateFrom({
      isPending: false,
      isError: true,
      data: undefined,
      error: new Error("network"),
    })
    expect(state.status).toBe("error")
    expect(state.canPresent("session.read")).toBe(false)
  })

  it("presents the session capabilities without treating them as authority", () => {
    const data = session()
    const state = sessionStateFrom({
      isPending: false,
      isError: false,
      data,
      error: null,
    })
    expect(state.status).toBe("authenticated")
    expect(state.presentedCapabilities).toEqual([
      "session.read",
      "profile.read.self",
    ])
    expect(state.canPresent("session.read")).toBe(true)
    expect(state.canPresent("admin.grant.manage")).toBe(false)
    expect(Object.isFrozen(state.presentedCapabilities)).toBe(true)
  })

  it("reads the session through the provider and exposes it to children", () => {
    const data = session()
    const queryClient = createQueryClient()
    queryClient.setQueryData(SESSION_QUERY_KEY, data)

    function Probe() {
      const state = useSession()
      return (
        <span>
          {state.status}:{String(state.canPresent("session.read"))}:
          {state.session?.account.email ?? "none"}
        </span>
      )
    }

    const html = renderToStaticMarkup(
      <AppProviders
        client={{ session: async () => data }}
        queryClient={queryClient}
      >
        <Probe />
      </AppProviders>,
    )
    expect(html).toContain("authenticated:true:person@example.test")
  })

  it("does not treat a missing session as authenticated", () => {
    expect(
      sessionStateFrom({
        isPending: false,
        isError: false,
        data: undefined,
        error: null,
      }),
    ).toBe(ANONYMOUS_SESSION)
  })
})
