import { useEffect, useState } from "react"
import {
  Award,
  Navigation,
  ShoppingBag,
  Store,
  Truck,
  Users,
  Zap,
} from "lucide-react"

import { ApiClientError } from "@hivorr/api-client"
import { Button, Pill, colorTokens, fontTokens } from "@hivorr/design"
import { useQuery, useQueryClient } from "@tanstack/react-query"

import { apiClient } from "../identity/client"

const ACTIVITIES = [
  {
    id: "market.buy",
    title: "I Want to Buy",
    sub: "Discover products and shop for what you need.",
    action: "Start Shopping",
    icon: ShoppingBag,
    color: colorTokens.brand,
    bg: colorTokens.brandTint,
    section: "Explore with Hivorr",
  },
  {
    id: "services.hire",
    title: "I Want to Hire",
    sub: "Find trusted professionals, post jobs, review applications, and manage your hires.",
    action: "Open Client Dashboard",
    icon: Users,
    color: colorTokens.seller,
    bg: colorTokens.sellerTint,
    section: "Explore with Hivorr",
  },
  {
    id: "errands.request",
    title: "Send an Errand",
    sub: "Request an errand and connect with an eligible logistics provider.",
    action: "Create an Errand",
    icon: Navigation,
    color: colorTokens.attention,
    bg: colorTokens.attentionTint,
    section: "Explore with Hivorr",
  },
  {
    id: "market.sell",
    title: "I Want to Sell",
    sub: "List your products, manage your shop, and grow your sales.",
    action: "Open Seller Dashboard",
    icon: Store,
    color: colorTokens.seller,
    bg: colorTokens.sellerTint,
    section: "Earn with Hivorr",
  },
  {
    id: "services.offer",
    title: "I Want to Offer My Services",
    sub: "Showcase your expertise, find jobs, submit applications, and manage your professional work.",
    action: "Open Professional Dashboard",
    icon: Award,
    color: colorTokens.success,
    bg: colorTokens.successTint,
    section: "Earn with Hivorr",
  },
  {
    id: "logistics.provide",
    title: "I Want to Provide Logistics",
    sub: "Find available delivery and errand requests, fulfil assignments, and earn from completed deliveries.",
    action: "Open Logistics Dashboard",
    icon: Truck,
    color: colorTokens.attention,
    bg: colorTokens.attentionTint,
    section: "Earn with Hivorr",
  },
] as const

type Activity = typeof ACTIVITIES[number]

function useViewport() {
  const [width, setWidth] = useState(() =>
    typeof window === "undefined" ? 1280 : window.innerWidth,
  )
  useEffect(() => {
    const onResize = () => setWidth(window.innerWidth)
    window.addEventListener("resize", onResize)
    return () => window.removeEventListener("resize", onResize)
  }, [])
  return { isMobile: width < 768, isDesktop: width >= 1024 }
}

export function ActivitySwitcher() {
  const { isMobile, isDesktop } = useViewport()
  const queryClient = useQueryClient()
  const activities = useQuery({
    queryKey: ["activities"],
    queryFn: () => apiClient.listActivities(),
    retry: false,
  })
  const [notice, setNotice] = useState<string | null>(null)
  const [denial, setDenial] = useState<string | null>(null)
  const [busy, setBusy] = useState<string | null>(null)

  const stateFor = (id: string) =>
    activities.data?.find((entry) => entry.id === id)?.state

  async function open(activity: Activity) {
    setNotice(null)
    setDenial(null)
    if (stateFor(activity.id) === "ACTIVE") {
      setNotice(`${activity.title} is already active.`)
      return
    }
    setBusy(activity.id)
    try {
      await apiClient.activateActivity({ id: activity.id })
      await queryClient.invalidateQueries({ queryKey: ["activities"] })
      setNotice(`${activity.title} is now active.`)
    } catch (error) {
      if (error instanceof ApiClientError && error.status === 403) {
        setDenial(
          "You do not have permission to activate this activity. Ask support to review your account.",
        )
      } else if (error instanceof ApiClientError && error.status === 401) {
        setDenial("Your session expired. Sign in again to continue.")
      } else {
        setDenial("The activity could not be activated. Try again.")
      }
    } finally {
      setBusy(null)
    }
  }

  const sections = ["Explore with Hivorr", "Earn with Hivorr"]

  return (
    <div
      style={{
        minHeight: "100vh",
        background: colorTokens.surface,
        display: "flex",
        flexDirection: "column",
      }}
    >
      <div
        style={{
          height: 72,
          background: colorTokens.surface,
          borderBottom: `1px solid ${colorTokens.border}`,
          display: "flex",
          alignItems: "center",
          justifyContent: "space-between",
          padding: isMobile ? "0 20px" : "0 48px",
          position: "sticky",
          top: 0,
          zIndex: 10,
        }}
      >
        <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
          <div
            style={{
              width: 36,
              height: 36,
              background: colorTokens.brand,
              borderRadius: 10,
              display: "flex",
              alignItems: "center",
              justifyContent: "center",
            }}
          >
            <Zap
              size={19}
              color={colorTokens.surface}
              fill={colorTokens.surface}
            />
          </div>
          <span
            style={{
              fontFamily: fontTokens.display,
              fontWeight: 800,
              fontSize: 19,
              color: colorTokens.ink,
            }}
          >
            Hivorr
          </span>
        </div>
        <Pill tone="brand">One account · Many activities</Pill>
      </div>

      <main
        style={{
          width: "100%",
          maxWidth: 1080,
          margin: "0 auto",
          padding: isMobile ? "32px 18px 48px" : "48px 32px 64px",
        }}
      >
        <div style={{ maxWidth: 680, marginBottom: 34 }}>
          <p
            style={{
              color: colorTokens.brand,
              fontSize: 12,
              fontWeight: 800,
              letterSpacing: 1.5,
              marginBottom: 8,
            }}
          >
            WELCOME TO YOUR HIVORR
          </p>
          <h1
            style={{
              fontFamily: fontTokens.display,
              fontWeight: 800,
              fontSize: isMobile ? 30 : 40,
              color: colorTokens.ink,
              lineHeight: 1.15,
              letterSpacing: -1.2,
            }}
          >
            How do you want to use Hivorr today?
          </h1>
          <p
            style={{
              fontSize: 15,
              lineHeight: 1.7,
              color: colorTokens.gray,
              marginTop: 12,
            }}
          >
            One account gives you access to multiple distinct Hivorr activities.
            Choose a workspace to continue.
          </p>
        </div>

        {activities.isPending ? (
          <p role="status" style={{ color: colorTokens.gray }}>
            Loading your activities…
          </p>
        ) : activities.isError ? (
          <p role="alert" style={{ color: colorTokens.danger }}>
            Your activities could not be loaded. Refresh to try again.
          </p>
        ) : (
          <div style={{ display: "flex", flexDirection: "column", gap: 26 }}>
            {sections.map((section) => (
              <section key={section}>
                <h2
                  style={{
                    fontFamily: fontTokens.display,
                    fontSize: 21,
                    color: colorTokens.ink,
                    fontWeight: 800,
                  }}
                >
                  {section}
                </h2>
                <p
                  style={{
                    color: colorTokens.gray,
                    fontSize: 13,
                    lineHeight: 1.5,
                    marginTop: 4,
                    marginBottom: 14,
                  }}
                >
                  {section === "Explore with Hivorr"
                    ? "Shop, hire trusted professionals, or request help with a local errand."
                    : "Earn through product sales, professional services, or logistics fulfilment."}
                </p>
                <div
                  style={{
                    display: "grid",
                    gridTemplateColumns: isDesktop ? "repeat(3,1fr)" : "1fr",
                    gap: 14,
                  }}
                >
                  {ACTIVITIES.filter((item) => item.section === section).map(
                    (activity) => {
                      const state = stateFor(activity.id)
                      return (
                        <button
                          key={activity.id}
                          type="button"
                          onClick={() => void open(activity)}
                          disabled={busy === activity.id}
                          style={{
                            background: colorTokens.surface,
                            border: `1px solid ${colorTokens.border}`,
                            borderRadius: 20,
                            padding: isMobile ? 18 : 22,
                            textAlign: "left",
                            boxShadow: "0 3px 14px rgba(15,22,38,0.06)",
                            display: "flex",
                            flexDirection: "column",
                            alignItems: "flex-start",
                            minHeight: 210,
                            cursor: "pointer",
                          }}
                        >
                          <div
                            style={{
                              width: 52,
                              height: 52,
                              borderRadius: 16,
                              background: activity.bg,
                              display: "flex",
                              alignItems: "center",
                              justifyContent: "center",
                            }}
                          >
                            <activity.icon size={24} color={activity.color} />
                          </div>
                          <h3
                            style={{
                              fontFamily: fontTokens.display,
                              fontSize: 18,
                              fontWeight: 800,
                              color: colorTokens.ink,
                              marginTop: 16,
                            }}
                          >
                            {activity.title}
                          </h3>
                          <p
                            style={{
                              fontSize: 13,
                              lineHeight: 1.6,
                              color: colorTokens.gray,
                              marginTop: 7,
                              flex: 1,
                            }}
                          >
                            {activity.sub}
                          </p>
                          <span
                            style={{
                              color: activity.color,
                              fontSize: 13,
                              fontWeight: 800,
                              display: "flex",
                              alignItems: "center",
                              gap: 5,
                              marginTop: 16,
                            }}
                          >
                            {busy === activity.id
                              ? "Activating…"
                              : activity.action}{" "}
                            <span aria-hidden="true">›</span>
                          </span>
                          {state ? (
                            <span
                              style={{
                                fontSize: 11,
                                color:
                                  state === "ACTIVE"
                                    ? colorTokens.success
                                    : colorTokens.gray,
                                fontWeight: 700,
                                marginTop: 8,
                              }}
                            >
                              {state}
                            </span>
                          ) : null}
                        </button>
                      )
                    },
                  )}
                </div>
              </section>
            ))}
          </div>
        )}

        <div aria-live="polite" style={{ marginTop: 24 }}>
          {notice ? (
            <p
              role="status"
              style={{ color: colorTokens.success, fontWeight: 700 }}
            >
              {notice}
            </p>
          ) : null}
          {denial ? (
            <p
              role="alert"
              style={{ color: colorTokens.danger, fontWeight: 700 }}
            >
              {denial}
            </p>
          ) : null}
        </div>

        <div style={{ marginTop: 24 }}>
          <Button
            variant="ghost"
            size="sm"
            onClick={() => void activities.refetch()}
          >
            Refresh activities
          </Button>
        </div>
      </main>
    </div>
  )
}
