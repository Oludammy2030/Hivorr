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

On **Windows**, the repository pins `supportedArchitectures` to Linux for CI. Install the Windows
native optional packages for local Vitest/Vite runs without changing the lockfile:

```sh
pnpm install --force --frozen-lockfile --config.supportedArchitectures.os=win32 --config.supportedArchitectures.cpu=x64
```

If Windows refuses the symlinked store (`EPERM`), use a hoisted store for the local install:
`pnpm install --force --no-frozen-lockfile --node-linker=hoisted --config.supportedArchitectures.os=win32 --config.supportedArchitectures.cpu=x64`.
Do not commit a `.npmrc` that changes the store layout for CI.

Expected: `Lockfile is up to date, resolution step is skipped`, exit 0. The install must not modify
`pnpm-lock.yaml`.

Enable the local pre-push policy and secret guard once per clone:

```sh
pnpm hooks:install
# equivalent to: git config --local core.hooksPath .githooks
```

The hook blocks direct pushes to `main` and `staging`, force-pushes and deletions. Work on a
`feature/*`, `fix/*`, `chore/*`, `docs/*` or `test/*` branch and open a pull request. The flow is
`feature/* → PR → staging → PR → main`. See
`documents/Engineering-Execution/BRANCH_PROTECTION.md`.

## 3. Verify

Run the same gates CI runs, in the same order:

```sh
pnpm check:toolchain   # node/pnpm parity
pnpm lint              # ESLint + the written baseline
pnpm lint:boundaries   # no cross-app or app-to-server imports
pnpm format:check      # oxfmt on changed files only
pnpm typecheck         # tsc --noEmit
pnpm test              # Vitest
pnpm build:all         # root web bundle + control/staff/partner
```

Or run the sequence with one command:

```sh
pnpm verify
```

Expected: every command exits 0. The build emits `dist/` for the main web bundle and
`dist/portals/{control,staff,partner}/`. `dist/` is ignored and is never committed.

### Optional: local dev server

```sh
pnpm dev
pnpm --filter @hivorr/app-control dev
pnpm --filter @hivorr/app-staff dev
pnpm --filter @hivorr/app-partner dev
```

The root server binds `0.0.0.0:8443` (or `$PORT`). The portal apps default to Vite's next free port.
These are **local development tools only**. Do not expose them to a network, a tunnel or the public
internet; they have no authentication or production hardening (`DEP-31`, `EX-16`).

## 4. What fails, and why

| Command | Fails when |
| --- | --- |
| `pnpm install --frozen-lockfile` | The lockfile and `package.json` disagree. Fix `package.json` intentionally and regenerate; never hand-edit the lockfile. |
| `pnpm check:toolchain` | Node is not 22.x or pnpm is not exactly `10.34.9`. |
| `pnpm lint` | A violation is not in `.lint-baseline.json`, or the baseline has expired. |
| `pnpm lint:boundaries` | An app imports another app or the server, or a shared package imports UI/server code. |
| `pnpm format:check` | A **changed** JavaScript/TypeScript file is not `oxfmt` formatted. Untouched files, including the prototype, are not reformatted. |
| `pnpm typecheck` | A real TypeScript error exists. Do not add `@ts-ignore`; ask for a bounded fix. |
| `pnpm test` | An asserted behaviour regressed. |
| `pnpm build:all` | The root Figma Make/Vite build or a portal bundle is broken. |
| `pnpm security:deps` | A High or Critical advisory is present. |
| `pnpm security:secrets` | A tracked file matches a known credential shape. |
| `git push origin main` / `staging` | The destination is a protected branch. Push a working branch and open a PR. |

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
