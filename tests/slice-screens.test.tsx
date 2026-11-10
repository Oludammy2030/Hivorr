import type { ReactNode } from "react"
import { renderToStaticMarkup } from "react-dom/server"
import { StaticRouter } from "react-router"
import { describe, expect, it } from "vitest"

import {
  AppProviders,
  createQueryClient,
} from "../packages/app-shell/src/index"
import {
  ForgotPasswordScreen,
  RegisterScreen,
  ResetPasswordScreen,
  SignInScreen,
  VerifyEmailScreen,
} from "../src/features/identity/screens"
import { ActivitySwitcher } from "../src/features/profile/activity-switcher"

const client = {
  session: async () => {
    throw new Error("not called in a server render")
  },
}

function render(path: string, element: ReactNode): string {
  return renderToStaticMarkup(
    <StaticRouter location={path}>
      <AppProviders client={client} queryClient={createQueryClient()}>
        {element}
      </AppProviders>
    </StaticRouter>,
  )
}

describe("sign-in screen", () => {
  it("renders the prototype's sign-in anatomy", () => {
    const html = render("/login", <SignInScreen />)
    expect(html).toContain("Welcome back")
    expect(html).toContain("Sign In")
    expect(html).toContain("Forgot password?")
    expect(html).toContain("Create account")
    expect(html).toContain('placeholder="you@example.com"')
    expect(html).toContain('autoComplete="current-password"')
  })
})

describe("registration screen", () => {
  it("uses only the fields the API accepts", () => {
    const html = render("/signup", <RegisterScreen />)
    expect(html).toContain("Full name")
    expect(html).toContain("Email")
    expect(html).toContain("Password")
    expect(html).not.toContain("Phone")
    expect(html).not.toContain("Country")
  })
})

describe("recovery screens", () => {
  it("renders the reset request without revealing whether the account exists", () => {
    const html = render("/forgot-password", <ForgotPasswordScreen />)
    expect(html).toContain("Reset your password")
    expect(html).toContain("if the address belongs to an account")
  })

  it("refuses a reset link without a token", () => {
    const html = render("/reset-password", <ResetPasswordScreen />)
    expect(html).toContain("missing its token")
  })

  it("refuses a verification link without a token", () => {
    const html = render("/verify-email", <VerifyEmailScreen />)
    expect(html).toContain("missing its token")
  })
})

describe("activity switcher", () => {
  it("renders the six activities while the request is pending", () => {
    const html = render("/activities", <ActivitySwitcher />)
    expect(html).toContain("How do you want to use Hivorr today?")
    expect(html).toContain("One account")
    expect(html).toContain("Loading your activities")
  })
})
