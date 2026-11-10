import { describe, expect, it } from "vitest"

import { createApplication } from "../server/src/app"
import { parseConfig } from "../server/src/config"

const config = parseConfig({
  HIVORR_ENV: "test",
  LOG_LEVEL: "error",
  API_PORT: "3000",
})

async function boot() {
  const { app } = await createApplication(config)
  await app.init()
  const instance = app.getHttpAdapter().getInstance()
  await instance.ready()
  return { app, instance }
}

describe("API runtime configuration", () => {
  it("mounts the API under /v1 only", async () => {
    const { app, instance } = await boot()
    try {
      const prefixed = await instance.inject({
        method: "GET",
        url: "/v1/health",
      })
      expect(prefixed.statusCode).toBe(200)

      const unprefixed = await instance.inject({
        method: "GET",
        url: "/health",
      })
      expect(unprefixed.statusCode).toBe(404)
    } finally {
      await app.close()
    }
  })

  it("applies the configured body limit and request timeout", async () => {
    const { app, instance } = await boot()
    try {
      expect(instance.initialConfig.bodyLimit).toBe(1_048_576)
      expect(instance.initialConfig.requestTimeout).toBe(15_000)
    } finally {
      await app.close()
    }
  })

  it("rejects a body above one megabyte before a handler runs", async () => {
    const { app, instance } = await boot()
    try {
      const oversized = JSON.stringify({ padding: "x".repeat(1_100_000) })
      const response = await instance.inject({
        method: "POST",
        url: "/v1/auth/register",
        headers: { "content-type": "application/json" },
        payload: oversized,
      })
      expect(response.statusCode).toBe(413)
    } finally {
      await app.close()
    }
  })

  it("replaces an unsafe correlation id and echoes a safe one", async () => {
    const { app, instance } = await boot()
    try {
      const unsafe = await instance.inject({
        method: "GET",
        url: "/v1/health/live",
        headers: { "x-correlation-id": "<script>alert(1)</script>" },
      })
      const generated = unsafe.headers["x-correlation-id"]
      expect(generated).toMatch(/^[A-Za-z0-9._-]{8,128}$/)

      const safe = await instance.inject({
        method: "GET",
        url: "/v1/health/live",
        headers: { "x-correlation-id": "request-12345678" },
      })
      expect(safe.headers["x-correlation-id"]).toBe("request-12345678")
    } finally {
      await app.close()
    }
  })

  it("closes the HTTP listener and its dependencies on shutdown", async () => {
    const { app, instance } = await boot()
    await app.close()
    await expect(
      instance.inject({ method: "GET", url: "/v1/health" }),
    ).rejects.toThrow()
  })
})
