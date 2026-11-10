import { defineConfig } from "vite"
import path from "path"
import tailwindcss from "@tailwindcss/vite"
import react from "@vitejs/plugin-react"

export default defineConfig({
  plugins: [
    // The React and Tailwind plugins are both required for Make, even if
    // Tailwind is not being actively used – do not remove them
    react(),
    tailwindcss(),
  ],
  resolve: {
    alias: {
      // Alias @ to the src directory
      "@": path.resolve(__dirname, "./src"),
      // Tests and dev consume shared contracts from source. The API process
      // loads the compiled ESM package from `dist` (EP-01-010).
      "@hivorr/shared": path.resolve(
        __dirname,
        "./packages/shared/src/index.ts",
      ),
    },
  },

  build: {
    rollupOptions: {
      input: {
        main: path.resolve(__dirname, "index.html"),
        slice: path.resolve(__dirname, "slice.html"),
      },
    },
  },

  // File types to support raw imports. Never add .css, .tsx, or .ts files to this.
  assetsInclude: ["**/*.svg", "**/*.csv"],
})
