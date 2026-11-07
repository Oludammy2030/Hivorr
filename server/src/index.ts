/**
 * API and worker boundary.
 *
 * EP-01-010 bootstraps the NestJS + Fastify API here, and EP-01-014 adds the
 * worker. This package exists from EP-01-002 so the server cannot be imported
 * by a portal bundle and so the workspace graph is real before the API is
 * implemented.
 */

export const SERVER_PACKAGE_NAME = "@hivorr/server" as const
export const API_VERSION = "v1" as const
