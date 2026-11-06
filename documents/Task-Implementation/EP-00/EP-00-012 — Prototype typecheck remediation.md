# Work Package Record — EP-00-012
## Prototype typecheck remediation

| Field | Value |
|---|---|
| **ID** | `EP-00-012` |
| **Phase** | `EP-00` — Execution Readiness |
| **Objective** | Make `pnpm typecheck` exit 0 on the pinned toolchain, without suppression, by fixing the genuine type errors revealed by `EP-00-001`. |
| **Class** | `[FOUNDER]` — the change touches `src/app/App.tsx`, the visual authority (`GOV-09`); approved by the founder on 2026-11-06. |
| **Status** | `In review` — implemented and locally verified; awaiting `[FOUNDER]` review of the diff. |
| **Origin** | `EP-00-001` T3 failed with 47 errors (46 in `App.tsx`, 1 in `vite.figma.config.ts`). Approved plan §6.5 requires a stop and a separate package. Founder approved opening it on 2026-11-06. |

### Scope — in

1. `src/app/App.tsx`: replace the icon prop type `React.ComponentType<{ size: number; color: string }>` with `LucideIcon` at every definition (8 sites), and import the type from `lucide-react`. This is a type-level correction: `lucide-react` icons accept `size: string | number`, so the narrower hand-written type rejected every icon.
2. `src/app/App.tsx`: add the two missing `Screen` keys — `"forgot-password"` and `"reset-sent"` — to the `TITLES` record, which is declared `Record<Screen, string>`. Both map to `""`, matching the other auth screens.
3. `src/app/App.tsx`: annotate the `configs` object in `getAdminModuleData` with its declared record type instead of `satisfies`, so the heterogeneous `fields` objects in the `hiring` records are contextually typed as `Record<string, string>`. No data changed.
4. `vite.figma.config.ts`: type `userConfig` as `UserConfig | ((env) => UserConfig | Promise<UserConfig>)` before the `typeof === 'function'` branch, removing the `never` narrowing. Runtime behaviour is unchanged.

### Scope — out

Any visual, copy, layout, token or behaviour change; any dependency, lockfile, toolchain or config-policy change; any suppression (`@ts-ignore`, `@ts-expect-error`, `any` widening, `skipLibCheck`); any refactor beyond the four items above.

### Reuse check

Inspected: `App.tsx` type definitions, `TITLES`, `getAdminModuleData`, `lucide-react` exports, `vite.figma.config.ts` `resolveUserConfig`, `tsconfig.json` (strict, no `skipLibCheck` change), and the approved `EP-00-001` plan §6.5. No existing type alias existed for the icon prop; `LucideIcon` is the package's own exported type, so it is reused rather than redefined. No new utility, component or config was created.

### Dependencies

`EP-00-001` install (complete); architect/founder approval (`[FOUNDER]`, given 2026-11-06).

### Test plan and result

| # | Test | Result |
|---|---|---|
| 1 | `pnpm typecheck` exits 0 with no suppression | **Pass** — exit 0, empty output |
| 2 | Error count reduced from 47 to 0 | **Pass** |
| 3 | No runtime behaviour changed except the two empty title entries | Reviewed: type annotations only; `TITLES` gains two `""` values for screens that previously had no entry |
| 4 | `App.tsx` still builds through the Figma wrapper | **Blocked** — `pnpm build` fails on the missing `@rollup/rollup-win32-x64-msvc` (finding F-01, platform), not on these edits |

### Evidence

- `pnpm typecheck` transcript, exit 0: `C:\Users\user\AppData\Local\Temp\opencode\ep-00-001\typecheck-3.log`
- Previous failing transcript (47 errors): `...\typecheck.log`
- `pnpm build` transcript (platform failure): `...\build.log`

### Rollback

Revert the four edits. No data, schema, lockfile or dependency is involved. `EP-00-001`'s lockfile change is independent and unaffected.

### Approver

Founder (`[FOUNDER]`), 2026-11-06. Architect review of the diff remains a `QUA-29`/`QUA-31` requirement before merge.

### Follow-up

- Fold `EP-00-012` into the EP-00 phase plan and evidence index (`EP-00-010`) as a `QUA-38` follow-up; this record does not amend the approved phase document.
- `EP-00-001` remains blocked at T4 (build) by finding F-01 and at the commit by the missing author email.
