import { useEffect, useState, type FormEvent } from "react"

import { api, errorMessage, type PaymentProviderSetting } from "./api"

interface PaymentsPageProps {
  canManage: boolean
}

function configuredChip(configured: boolean): string {
  return configured ? "chip chip-ok" : "chip chip-danger"
}

export function PaymentsPage({ canManage }: PaymentsPageProps) {
  const [setting, setSetting] = useState<PaymentProviderSetting | null>(null)
  const [provider, setProvider] = useState<"vfd" | "paystack">("paystack")
  const [mode, setMode] = useState<"test" | "live">("test")
  const [reason, setReason] = useState("")
  const [error, setError] = useState<string | undefined>()
  const [busy, setBusy] = useState(false)

  useEffect(() => {
    let active = true
    setBusy(true)
    api
      .getPaymentProvider()
      .then((value) => {
        if (!active) return
        setSetting(value)
        setProvider(value.provider)
        setMode(value.mode)
      })
      .catch((value: unknown) => {
        if (active) setError(errorMessage(value))
      })
      .finally(() => {
        if (active) setBusy(false)
      })
    return () => {
      active = false
    }
  }, [])

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    if (reason.trim().length < 5) {
      setError("A reason of at least five characters is required.")
      return
    }
    setBusy(true)
    setError(undefined)
    try {
      const value = await api.setPaymentProvider({ provider, mode, reason })
      setSetting(value)
      setReason("")
    } catch (value) {
      setError(errorMessage(value))
    } finally {
      setBusy(false)
    }
  }

  return (
    <section className="page">
      <header className="page-head">
        <div>
          <p className="eyebrow">Configuration</p>
          <h2>Payments</h2>
          <p className="muted">
            Switch the active payment provider and mode. Secret keys are held in
            the deployment secret store and are never entered or shown here.
          </p>
        </div>
      </header>

      {error && (
        <p className="error" role="alert">
          {error}
        </p>
      )}

      <div className="grid-two">
        <section className="panel">
          <h3>Active provider</h3>
          {busy && !setting && <p className="muted">Loading.</p>}
          {setting && (
            <>
              <p>
                <strong>{setting.provider}</strong> in{" "}
                <strong>{setting.mode}</strong> mode
              </p>
              <p className="muted">
                Updated {new Date(setting.updatedAt).toLocaleString()}
              </p>
              <table className="table">
                <thead>
                  <tr>
                    <th>Provider</th>
                    <th>Test key</th>
                    <th>Live key</th>
                  </tr>
                </thead>
                <tbody>
                  {(["paystack", "vfd"] as const).map((key) => (
                    <tr key={key}>
                      <td>{key}</td>
                      <td>
                        <span
                          className={configuredChip(
                            setting.configured[key].test,
                          )}
                        >
                          {setting.configured[key].test
                            ? "configured"
                            : "missing"}
                        </span>
                      </td>
                      <td>
                        <span
                          className={configuredChip(
                            setting.configured[key].live,
                          )}
                        >
                          {setting.configured[key].live
                            ? "configured"
                            : "missing"}
                        </span>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </>
          )}
        </section>

        <form className="panel form" onSubmit={handleSubmit}>
          <h3>Switch provider</h3>
          <label className="field">
            <span>Provider</span>
            <select
              value={provider}
              onChange={(event) =>
                setProvider(event.target.value as "vfd" | "paystack")
              }
              disabled={!canManage || busy}
            >
              <option value="paystack">Paystack</option>
              <option value="vfd">VFD (paused)</option>
            </select>
          </label>
          <label className="field">
            <span>Mode</span>
            <select
              value={mode}
              onChange={(event) =>
                setMode(event.target.value as "test" | "live")
              }
              disabled={!canManage || busy}
            >
              <option value="test">Test</option>
              <option value="live">Live</option>
            </select>
          </label>
          <label className="field">
            <span>Reason</span>
            <textarea
              value={reason}
              onChange={(event) => setReason(event.target.value)}
              rows={3}
              maxLength={500}
              disabled={!canManage || busy}
              required
            />
          </label>
          <button
            className="button"
            type="submit"
            disabled={!canManage || busy}
          >
            {busy ? "Saving…" : "Save provider"}
          </button>
          {!canManage && (
            <p className="muted">
              You need configuration write permission to switch providers.
            </p>
          )}
        </form>
      </div>
    </section>
  )
}
