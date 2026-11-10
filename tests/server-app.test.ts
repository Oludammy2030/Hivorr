import { describe, expect, it } from "vitest"

import { createApplication } from "../server/src/app"
import { parseConfig } from "../server/src/config"

const config = parseConfig({
  HIVORR_ENV: "test",
  LOG_LEVEL: "error",
  API_PORT: "3000",
})

describe("API bootstrap", () => {
  it("serves liveness and reports readiness honestly", async () => {
    const { app } = await createApplication(config)

    try {
      await app.init()
      await app.getHttpAdapter().getInstance().ready()

      const live = await app.getHttpAdapter().getInstance().inject({
        method: "GET",
        url: "/v1/health",
      })
      expect(live.statusCode).toBe(200)
      expect(live.headers["x-correlation-id"]).toBeTruthy()
      expect(live.json()).toMatchObject({
        status: "ok",
        service: "hivorr-api",
        environment: "test",
      })

      const ready = await app.getHttpAdapter().getInstance().inject({
        method: "GET",
        url: "/v1/health/ready",
      })
      expect(ready.statusCode).toBe(503)
      expect(ready.json()).toMatchObject({
        status: "not_ready",
        checks: { configuration: "ok", database: "not_implemented" },
      })
    } finally {
      await app.close()
    }
  })

  it("reports the injected release identity", async () => {
    const releaseSha = "a".repeat(40)
    const releaseDigest = `sha256:${"b".repeat(64)}`
    const releaseConfig = parseConfig({
      HIVORR_ENV: "test",
      LOG_LEVEL: "error",
      RELEASE_SHA: releaseSha,
      RELEASE_DIGEST: releaseDigest,
    })
    const { app } = await createApplication(releaseConfig)

    try {
      await app.init()
      await app.getHttpAdapter().getInstance().ready()
      const live = await app.getHttpAdapter().getInstance().inject({
        method: "GET",
        url: "/v1/health/live",
      })
      expect(live.statusCode).toBe(200)
      expect(live.json()).toMatchObject({
        status: "ok",
        releaseSha,
        releaseDigest,
      })
    } finally {
      await app.close()
    }
  })
})
