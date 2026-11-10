import React from "react"
import ReactDOM from "react-dom/client"
import { Navigate } from "react-router"

import { AppProviders, SliceBrowserRouter } from "@hivorr/app-shell"

import {
  ForgotPasswordScreen,
  RegisterScreen,
  ResetPasswordScreen,
  SessionBootstrap,
  SignInScreen,
  VerifyEmailScreen,
  apiClient,
} from "./features/identity"
import { ActivitySwitcher } from "./features/profile"
import "./styles/index.css"

const screens = {
  home: <SessionBootstrap />,
  login: <SignInScreen />,
  signup: <RegisterScreen />,
  onboarding: <Navigate to="/login" replace />,
  "forgot-password": <ForgotPasswordScreen />,
  "reset-password": <ResetPasswordScreen />,
  "verify-email": <VerifyEmailScreen />,
  activities: <ActivitySwitcher />,
}

ReactDOM.createRoot(document.getElementById("root")!).render(
  <React.StrictMode>
    <AppProviders client={apiClient}>
      <SliceBrowserRouter screens={screens} />
    </AppProviders>
  </React.StrictMode>,
)
