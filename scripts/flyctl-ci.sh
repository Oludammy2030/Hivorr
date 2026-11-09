#!/usr/bin/env bash
# Run the pinned flyctl image against the checked-out workspace.
#
# GitHub release downloads are unreliable from the runner, so flyctl is taken
# from the official Docker Hub image. The workspace is mounted because deploy
# reads Dockerfile and the fly.*.toml files. Credentials are passed by name and
# never printed.

set -euo pipefail

exec docker run --rm \
  -e FLY_API_TOKEN \
  -e DATABASE_URL \
  -e WORKER_DATABASE_URL \
  -e MFA_ENCRYPTION_KEY \
  -v "$PWD:/workspace" \
  -w /workspace \
  flyio/flyctl:v0.5.5 "$@"
