# Developer Bootstrap — EP-00

This is the verified clone-to-green instruction for the repository as it exists at
`v0.0.1-bootstrap` and after the EP-00 quality gates. It covers what exists today: the React
prototype, the pinned toolchain, the frozen lockfile, typecheck, lint, test, build and the local dev
server.

It does **not** start PostgreSQL, an API or a worker. Those components do not exist in EP-00 and are
delivered by EP-01 (founder ruling `D-02`, 4 November 2026).

## 1. Provision the pinned toolchain

The single source of truth is `.mise.toml`: Node 22 and pnpm `10.34.9`. `package.json` restates the
contract in `packageManager` and `engines`, so a wrong version fails loudly.

```sh
# Install mise once: https://mise.jdx.dev/
mise install
mise exec -- node -v    # expect v22.x
mise exec -- pnpm -v    # expect 10.34.9
```

If `mise` is unavailable, install Node 22 and pnpm `10.34.9` by another trusted method. Do not use a
different pnpm version: `pnpm check:toolchain` rejects it.

## 2. Clone and frozen install

```sh
git clone https://github.com/Oludammy2030/Hivorr.git
cd Hivorr
pnpm install --frozen-lockfile
```

Expected: `Lockfile is up to date, resolution step is skipped`, exit 0. The install must not modify
`pnpm-lock.yaml`.

Enable the local pre-push secret guard once per clone:

```sh
git config core.hooksPath .githooks
```

## 3. Verify

Run the same gates CI runs, in the same order:

```sh
pnpm check:toolchain   # node/pnpm parity
pnpm lint              # ESLint + the written baseline
pnpm format:check      # oxfmt on changed files only
pnpm typecheck         # tsc --noEmit
pnpm test              # Vitest
pnpm build             # vite.figma.config.ts
```

Or run the sequence with one command:

```sh
pnpm verify
```

Expected: every command exits 0. The build emits `dist/`. `dist/` is ignored and is never committed.

### Optional: local dev server

```sh
pnpm dev
```

It binds `0.0.0.0:8443` (or `$PORT`). This is a **local development tool only**. Do not expose it to
a network, a tunnel or the public internet; it has no authentication or production hardening
(`DEP-31`, `EX-16`).

## 4. What fails, and why

| Command | Fails when |
| --- | --- |
| `pnpm install --frozen-lockfile` | The lockfile and `package.json` disagree. Fix `package.json` intentionally and regenerate; never hand-edit the lockfile. |
| `pnpm check:toolchain` | Node is not 22.x or pnpm is not exactly `10.34.9`. |
| `pnpm lint` | A violation is not in `.lint-baseline.json`, or the baseline has expired. |
| `pnpm format:check` | A **changed** JavaScript/TypeScript file is not `oxfmt` formatted. Untouched files, including the prototype, are not reformatted. |
| `pnpm typecheck` | A real TypeScript error exists. Do not add `@ts-ignore`; ask for a bounded fix. |
| `pnpm test` | An asserted behaviour regressed. |
| `pnpm build` | The Figma Make/Vite build is broken. |
| `pnpm security:deps` | A High or Critical advisory is present. |
| `pnpm security:secrets` | A tracked file matches a known credential shape. |

## 5. Windows note

The repository's `pnpm-workspace.yaml` pins the reference architecture to Linux, matching CI. On a
Windows workstation native optional packages can be skipped. The recorded local workaround is a
one-off `pnpm install --force` (`PC-01`); CI on Linux remains the reference. Do not change
`supportedArchitectures` without an architect decision.

## 6. What EP-01 adds

EP-01 extends this instruction; it does not replace it:

- PostgreSQL and the migration runner;
- the TypeScript API and the worker;
- seed data and local environment variables;
- Playwright, Testcontainers and component-test DOM;
- the visual-regression baseline and the OpenAPI diff stage.

Do not start those services or add those tools in EP-00.
