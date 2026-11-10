# Build and run the Hivorr API or worker.
#
# One image serves both entry points; the process command selects one:
#   API:    node server/dist/main.js
#   Worker: node server/dist/worker.js

FROM node:22-bookworm-slim AS build
WORKDIR /app
RUN corepack enable && corepack prepare pnpm@10.34.9 --activate

COPY package.json pnpm-lock.yaml pnpm-workspace.yaml tsconfig.json ./
COPY server ./server
COPY packages ./packages
COPY apps ./apps
COPY scripts ./scripts

RUN pnpm install --frozen-lockfile --fetch-retries=5 --fetch-timeout=600000 --fetch-retry-maxtimeout=120000
RUN pnpm build:server

FROM node:22-bookworm-slim AS runtime
ENV NODE_ENV=production
WORKDIR /app

COPY --from=build /app/node_modules ./node_modules
COPY --from=build /app/server/node_modules ./server/node_modules
COPY --from=build /app/server/dist ./server/dist
COPY --from=build /app/server/package.json ./server/package.json
COPY --from=build /app/packages/shared/package.json ./packages/shared/package.json
COPY --from=build /app/packages/shared/dist ./packages/shared/dist

USER node
EXPOSE 3000 3001
CMD ["node", "server/dist/main.js"]
