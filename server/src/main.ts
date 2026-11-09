import { createApplication } from "./app"

async function bootstrap(): Promise<void> {
  const { app, config } = await createApplication()
  await app.listen({ port: config.port, host: config.host })
}

bootstrap().catch((error: unknown) => {
  const message =
    error instanceof Error ? error.message : "unknown startup failure"
  console.error(`hivorr-api: failed to start: ${message}`)
  process.exit(1)
})
