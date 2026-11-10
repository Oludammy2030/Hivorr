import {
  Controller,
  Get,
  Inject,
  ServiceUnavailableException,
} from "@nestjs/common"

import { API_CONFIG, type ApiConfig } from "../config"
import { Audience } from "../common/audience"

@Controller("health")
@Audience("public")
export class HealthController {
  constructor(@Inject(API_CONFIG) private readonly config: ApiConfig) {}

  @Get()
  live() {
    return {
      status: "ok",
      service: "hivorr-api",
      version: "v1",
      environment: this.config.environment,
      releaseSha: this.config.releaseSha,
      releaseDigest: this.config.releaseDigest,
      time: new Date().toISOString(),
    }
  }

  @Get("live")
  liveness() {
    return this.live()
  }

  @Get("ready")
  readiness() {
    // The database adapter is not wired until EP-01-020/026. Reporting ready
    // before it exists would be a false readiness claim.
    throw new ServiceUnavailableException({
      status: "not_ready",
      service: "hivorr-api",
      checks: { configuration: "ok", database: "not_implemented" },
    })
  }
}
