import js from "@eslint/js"
import globals from "globals"
import tseslint from "typescript-eslint"

/**
 * Curated lint gate (EP-00-004).
 *
 * The rule set is deliberately small and correctness-focused. It is applied to
 * every source file, including the prototype, without a global disable. Rules
 * that would require a repository-wide reformat (formatting rules) belong to
 * oxfmt, not ESLint.
 */
export default tseslint.config(
  {
    ignores: [
      "dist/**",
      "node_modules/**",
      ".figma/**",
      "supabase/.temp/**",
      "supabase/.branches/**",
      "coverage/**",
      "pnpm-lock.yaml",
    ],
  },
  {
    files: ["**/*.{js,mjs,cjs,ts,tsx}"],
    ...js.configs.recommended,
    languageOptions: {
      ecmaVersion: "latest",
      sourceType: "module",
      globals: {
        ...globals.browser,
        ...globals.node,
      },
    },
  },
  {
    files: ["**/*.{ts,tsx}"],
    plugins: {
      "@typescript-eslint": tseslint.plugin,
    },
    languageOptions: {
      parser: tseslint.parser,
      parserOptions: {
        ecmaVersion: "latest",
        sourceType: "module",
      },
    },
    rules: {
      // TypeScript resolves these; the JavaScript rule produces false positives.
      "no-undef": "off",
      "no-unused-vars": "off",
      "@typescript-eslint/no-unused-vars": [
        "error",
        {
          argsIgnorePattern: "^_",
          varsIgnorePattern: "^_",
          caughtErrorsIgnorePattern: "^_",
        },
      ],
    },
  },
)
