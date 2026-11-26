import { useEffect, useState, type FormEvent } from "react"

import { Link } from "react-router"

import { ApiClientError } from "@hivorr/api-client"

import {
  Button,
  Pill,
  TextField,
  colorTokens,
  fontTokens,
  radiusTokens,
  shadowTokens,
} from "@hivorr/design"

import { useSession } from "@hivorr/app-shell"

import { apiClient } from "../identity/client"

interface Balance {
  readonly currency: string

  readonly available: string

  readonly pending: string

  readonly total: string

  readonly withdrawable: string
}

interface PayoutAccount {
  readonly id: string

  readonly bankCode: string

  readonly bankName: string

  readonly accountName: string

  readonly accountNumberMasked: string

  readonly state: "pending" | "verified" | "rejected" | "disabled"

  readonly boundAt: string | null

  readonly createdAt: string
}

interface CollectionAccount {
  readonly id: string

  readonly accountNumber: string

  readonly accountName: string

  readonly bankName: string | null

  readonly currency: string

  readonly status: string
}

function messageFor(error: unknown): string {
  if (error instanceof ApiClientError) return error.message

  return "Something went wrong. Try again."
}

const card = {
  background: "#fff",

  borderRadius: radiusTokens.control,

  boxShadow: shadowTokens.rest,

  padding: 20,
} as const

export function WalletScreen() {
  const session = useSession()

  const [balances, setBalances] = useState<readonly Balance[]>([])

  const [accounts, setAccounts] = useState<readonly PayoutAccount[]>([])

  const [collection, setCollection] = useState<CollectionAccount | null>(null)

  const [error, setError] = useState<string | undefined>()

  const [busy, setBusy] = useState(false)

  const [selectedAccount, setSelectedAccount] = useState("")

  const [amount, setAmount] = useState("")

  const [bindOpen, setBindOpen] = useState(false)

  async function refresh() {
    const [nextBalances, nextAccounts, nextCollection] = await Promise.all([
      apiClient.getWalletBalance(),

      apiClient.listPayoutAccounts(),

      apiClient.getCollectionAccount(),
    ])

    setBalances(nextBalances as never)

    setAccounts(nextAccounts as never)

    setCollection(nextCollection as never)

    setSelectedAccount(
      (current) =>
        current ||
        (nextAccounts as readonly PayoutAccount[]).find(
          (account) => account.state === "verified",
        )?.id ||
        "",
    )
  }

  useEffect(() => {
    if (session.status !== "authenticated") return

    let active = true

    setBusy(true)

    refresh()

      .catch((value: unknown) => {
        if (active) setError(messageFor(value))
      })

      .finally(() => {
        if (active) setBusy(false)
      })

    return () => {
      active = false
    }
  }, [session.status])

  if (session.status === "loading") {
    return <main style={{ padding: 32 }}>Loading wallet…</main>
  }

  if (session.status !== "authenticated" || !session.session) {
    return (
      <main style={{ padding: 32 }}>
        <h1>Wallet</h1>
        <p>
          <Link to="/login">Sign in</Link> to see your wallet.
        </p>
      </main>
    )
  }

  const balance =
    balances.find((entry) => entry.currency === "NGN") ?? balances[0]

  const verifiedAccounts = accounts.filter(
    (account) => account.state === "verified",
  )

  async function createCollection() {
    setBusy(true)

    setError(undefined)

    try {
      const value = await apiClient.createCollectionAccount()

      setCollection(value as never)
    } catch (value) {
      setError(messageFor(value))
    } finally {
      setBusy(false)
    }
  }

  async function bindPayout(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()

    const form = new FormData(event.currentTarget)

    setBusy(true)

    setError(undefined)

    try {
      await apiClient.bindPayoutAccount({
        bankCode: String(form.get("bankCode") ?? "").trim(),

        bankName: String(form.get("bankName") ?? "").trim(),

        accountNumber: String(form.get("accountNumber") ?? "").trim(),
      })

      setBindOpen(false)

      await refresh()
    } catch (value) {
      setError(messageFor(value))
    } finally {
      setBusy(false)
    }
  }

  async function withdraw(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()

    if (!selectedAccount) {
      setError("Bind a verified payout account first.")

      return
    }

    setBusy(true)

    setError(undefined)

    try {
      await apiClient.requestWithdrawal({
        payoutAccountId: selectedAccount,

        amount: amount.trim(),

        currency: "NGN",
      })

      setAmount("")

      await refresh()
    } catch (value) {
      setError(messageFor(value))
    } finally {
      setBusy(false)
    }
  }

  async function disable(id: string) {
    setBusy(true)

    setError(undefined)

    try {
      await apiClient.disablePayoutAccount(
        { id },

        { reason: "Disabled from the wallet screen" },
      )

      await refresh()
    } catch (value) {
      setError(messageFor(value))
    } finally {
      setBusy(false)
    }
  }

  return (
    <main
      style={{
        maxWidth: 1080,

        margin: "0 auto",

        padding: "32px 24px 80px",

        fontFamily: fontTokens.body,

        color: colorTokens.ink,
      }}
    >
      <header style={{ marginBottom: 22 }}>
        <p
          style={{
            color: colorTokens.mutedText,
            fontSize: 12,
            letterSpacing: 1,
          }}
        >
          HIVORR WALLET
        </p>
        <h1 style={{ fontSize: 30, fontWeight: 800, marginTop: 6 }}>Wallet</h1>
        <p style={{ color: colorTokens.gray, marginTop: 5 }}>
          Deposit, bind a payout destination and withdraw. Limits follow your
          KYC tier.
        </p>
      </header>

      {error && (
        <p role="alert" style={{ color: colorTokens.danger, marginBottom: 16 }}>
          {error}
        </p>
      )}

      <section
        style={{
          display: "grid",

          gridTemplateColumns: "repeat(auto-fit,minmax(160px,1fr))",

          gap: 12,
        }}
      >
        {[
          ["Available", balance?.available ?? "0.0000"],

          ["Pending", balance?.pending ?? "0.0000"],

          ["Withdrawable", balance?.withdrawable ?? "0.0000"],

          ["Total", balance?.total ?? "0.0000"],
        ].map(([label, value]) => (
          <div key={label} style={card}>
            <p style={{ color: colorTokens.mutedText, fontSize: 11 }}>
              {label}
            </p>
            <p style={{ fontSize: 22, fontWeight: 800, marginTop: 6 }}>
              {value}
            </p>
            <p style={{ color: colorTokens.mutedText, fontSize: 10 }}>NGN</p>
          </div>
        ))}
      </section>

      <div
        style={{
          display: "grid",

          gridTemplateColumns: "repeat(auto-fit,minmax(320px,1fr))",

          gap: 16,

          marginTop: 18,
        }}
      >
        <section style={card}>
          <div
            style={{
              display: "flex",

              justifyContent: "space-between",

              alignItems: "center",
            }}
          >
            <h2 style={{ fontSize: 16, fontWeight: 800 }}>Deposit account</h2>
            {collection ? (
              <Pill tone="success">Active</Pill>
            ) : (
              <Pill tone="attention">Not created</Pill>
            )}
          </div>
          {collection ? (
            <div style={{ marginTop: 14 }}>
              <p style={{ fontSize: 24, fontWeight: 800, letterSpacing: 1 }}>
                {collection.accountNumber}
              </p>
              <p style={{ color: colorTokens.gray, marginTop: 4 }}>
                {collection.accountName}
              </p>
              <p style={{ color: colorTokens.mutedText, fontSize: 12 }}>
                {collection.bankName ?? "Paystack"} · {collection.currency}
              </p>
              <p
                style={{
                  color: colorTokens.mutedText,

                  fontSize: 11,

                  marginTop: 12,
                }}
              >
                Transfer to this account from your bank. The wallet is credited
                after Paystack confirms the payment.
              </p>
            </div>
          ) : (
            <div style={{ marginTop: 14 }}>
              <p style={{ color: colorTokens.gray, fontSize: 12 }}>
                Create a dedicated virtual account to fund this wallet.
              </p>
              <div style={{ marginTop: 14 }}>
                <Button onClick={createCollection} disabled={busy}>
                  Create deposit account
                </Button>
              </div>
            </div>
          )}
        </section>

        <section style={card}>
          <div
            style={{
              display: "flex",

              justifyContent: "space-between",

              alignItems: "center",
            }}
          >
            <h2 style={{ fontSize: 16, fontWeight: 800 }}>Withdraw</h2>
            <Pill tone="neutral">NGN</Pill>
          </div>
          <form onSubmit={withdraw} style={{ marginTop: 12 }}>
            <label style={{ display: "block", fontSize: 12, marginBottom: 6 }}>
              Payout account
            </label>
            <select
              value={selectedAccount}
              onChange={(event) => setSelectedAccount(event.target.value)}
              disabled={busy || verifiedAccounts.length === 0}
              style={{
                width: "100%",

                padding: "10px 12px",

                borderRadius: radiusTokens.control,

                border: `1px solid ${colorTokens.border}`,
              }}
            >
              <option value="">Select a verified account</option>
              {verifiedAccounts.map((account) => (
                <option key={account.id} value={account.id}>
                  {account.bankName} · {account.accountNumberMasked}
                </option>
              ))}
            </select>
            <div style={{ marginTop: 12 }}>
              <TextField
                label="Amount"
                value={amount}
                onChange={(event) => setAmount(event.target.value)}
                placeholder="0.00"
                inputMode="decimal"
                disabled={busy || verifiedAccounts.length === 0}
              />
            </div>
            <div style={{ marginTop: 14 }}>
              <Button
                type="submit"
                disabled={busy || verifiedAccounts.length === 0}
              >
                {busy ? "Working…" : "Withdraw"}
              </Button>
            </div>
            <p
              style={{
                color: colorTokens.mutedText,

                fontSize: 11,

                marginTop: 8,
              }}
            >
              Withdrawals are checked against your KYC tier's daily CBN limit.
            </p>
          </form>
        </section>
      </div>

      <section style={{ ...card, marginTop: 18 }}>
        <div
          style={{
            display: "flex",

            justifyContent: "space-between",

            alignItems: "center",
          }}
        >
          <h2 style={{ fontSize: 16, fontWeight: 800 }}>Payout accounts</h2>
          <Button
            variant="secondary"
            size="sm"
            onClick={() => setBindOpen(!bindOpen)}
          >
            {bindOpen ? "Cancel" : "Add account"}
          </Button>
        </div>
        {accounts.length === 0 && (
          <p style={{ color: colorTokens.gray, fontSize: 12, marginTop: 12 }}>
            No payout account yet. Add one to withdraw.
          </p>
        )}
        <div style={{ marginTop: 12 }}>
          {accounts.map((account) => (
            <div
              key={account.id}
              style={{
                display: "flex",

                justifyContent: "space-between",

                gap: 12,

                padding: "12px 0",

                borderTop: `1px solid ${colorTokens.border}`,
              }}
            >
              <div>
                <p style={{ fontWeight: 700, fontSize: 13 }}>
                  {account.bankName} · {account.accountNumberMasked}
                </p>
                <p style={{ color: colorTokens.mutedText, fontSize: 11 }}>
                  {account.accountName} · {account.state}
                </p>
              </div>
              {account.state === "verified" && (
                <Button
                  variant="ghost"
                  size="sm"
                  onClick={() => disable(account.id)}
                  disabled={busy}
                >
                  Disable
                </Button>
              )}
            </div>
          ))}
        </div>
        {bindOpen && (
          <form
            onSubmit={bindPayout}
            style={{
              marginTop: 16,

              paddingTop: 16,

              borderTop: `1px solid ${colorTokens.border}`,
            }}
          >
            <div
              style={{
                display: "grid",

                gridTemplateColumns: "repeat(auto-fit,minmax(160px,1fr))",

                gap: 12,
              }}
            >
              <TextField label="Bank code" name="bankCode" required />
              <TextField label="Bank name" name="bankName" required />
              <TextField
                label="Account number"
                name="accountNumber"
                inputMode="numeric"
                required
              />
            </div>
            <div style={{ marginTop: 14 }}>
              <Button type="submit" disabled={busy}>
                {busy ? "Verifying…" : "Bind account"}
              </Button>
            </div>
            <p
              style={{
                color: colorTokens.mutedText,

                fontSize: 11,

                marginTop: 8,
              }}
            >
              The bank account name must match your verified legal name.
            </p>
          </form>
        )}
      </section>
    </main>
  )
}
