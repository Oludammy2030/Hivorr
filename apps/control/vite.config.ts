import { defineConfig } from "vite"
import react from "@vitejs/plugin-react"
import { fileURLToPath } from "node:url"

const appRoot = fileURLToPath(new URL(".", import.meta.url))

export default defineConfig({
  root: appRoot,
  plugins: [react()],
  build: {
    outDir: fileURLToPath(
      new URL("../../dist/portals/control", import.meta.url),
    ),
    emptyOutDir: true,
  },
})
