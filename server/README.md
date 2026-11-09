# Hivorr server

The API and worker boundary.

**Current state:** API bootstrap only. `src/app.ts` creates the NestJS + Fastify
application; `src/main.ts` starts it. Configuration fails closed, `/v1/health` is a
liveness endpoint, and `/v1/health/ready` deliberately reports `503` until the
database adapter exists. The capability engine is pure and default-deny. The
modules, database, migrations, worker, and provider adapters arrive in the
remaining EP-01 packages.

Rules:

- The server is never imported by a portal bundle.
- Portal bundles call the API through `@hivorr/api-client`, which is generated
  from the OpenAPI document (EP-01-013).
- Provider SDKs live behind adapters in `src/integrations/` when they are added.
