# Hivorr server

The API and worker boundary.

**Current state:** boundary only. `src/index.ts` exports the package constants;
the NestJS + Fastify bootstrap, modules, migrations, and worker arrive in
EP-01-010 through EP-01-014 and EP-01-020 onward.

Rules:

- The server is never imported by a portal bundle.
- Portal bundles call the API through `@hivorr/api-client`, which is generated
  from the OpenAPI document (EP-01-013).
- Provider SDKs live behind adapters in `src/integrations/` when they are added.
