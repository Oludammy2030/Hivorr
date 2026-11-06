# Work Package Record — EP-00-012
## Prototype typecheck remediation

| Field | Value |
|---|---|
| **ID** | `EP-00-012` |
| **Phase** | `EP-00` — Execution Readiness |
| **Objective** | Make `pnpm typecheck` exit 0 on the pinned toolchain, without suppression, by fixing the genuine type errors revealed by `EP-00-001`. |
| **Class** | `[FOUNDER]` — the change touches `src/app/App.tsx`, the visual authority (`GOV-09`); approved by the founder on 2026-11-06. |
| **Status** | `Verified` 2026-11-06 — implemented, locally verified and founder-approved. No architect review is recorded; the second-reviewer gap is covered by the approved time-boxed deviation `DEV-001`, which must be settled by `EP-00-007`. |
| **Origin** | `EP-00-001` T3 failed with 47 errors (46 in `App.tsx`, 1 in `vite.figma.config.ts`). Approved plan §6.5 requires a stop and a separate package. Founder approved opening it on 2026-11-06. |
| **Review artefact** | The four corrections are inside root commit `8029466`; no standalone `EP-00-012` diff exists in history. Inspect with `git show 8029466 -- src/app/App.tsx vite.figma.config.ts`. See the amendment at the end of this record. |

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

Founder (`[FOUNDER]`), 2026-11-06. Architect review of the review artefact remains a `QUA-29`/`QUA-31` requirement before merge.

### Follow-up

- Fold `EP-00-012` into the EP-00 phase plan and evidence index (`EP-00-010`) as a `QUA-38` follow-up; this record does not amend the approved phase document.
- `EP-00-001` remains blocked at T4 (build) by finding F-01 and at the commit by the missing author email.


---

### Amendment — 2026-11-06

**Authority:** recorded on the instruction of the project lead, following the approved implementation plan §20 item 1. This is a record-accuracy correction: it changes no scope, no code, no test result and no approval claim.

**1. Where the diff lives.** The four corrections were committed inside the root commit `8029466` (`v0.0.1-bootstrap`), together with `EP-00-001`'s tree. `src/app/App.tsx` and `vite.figma.config.ts` are touched by no other commit, so there is no standalone `EP-00-012` revision to diff against. The review artefact is the content of that commit at those two paths:

```
git show 8029466 -- src/app/App.tsx vite.figma.config.ts
```

`[FOUNDER]` review and the `QUA-29`/`QUA-31` architect review apply to that artefact. The claim that the change is annotation-only rests on inspection of the committed file content plus the compiler, not on a hunk diff against a prior revision, and that limitation is recorded here rather than implied away.

**2. Build result superseded, not rewritten.** Test 4 above records `pnpm build` as blocked by finding `F-01` (`@rollup/rollup-win32-x64-msvc`). That finding was subsequently resolved by the recorded local `--force` frozen install (`PC-01`), as reflected in the approved phase plan §8 assumption 4. Re-verified 2026-11-06: `pnpm build` exits 0 and produces `dist/`. The original result is retained above for history.

**3. Verification evidence (2026-11-06).**

- `pnpm typecheck`: exit 0, empty output — `C:\Users\user\AppData\Local\Temp\opencode\ep-00-012\typecheck.log`
- `pnpm build`: exit 0 — `...\ep-00-012\build.log`
- Fact verification covering the icon contract, `TITLES` keys, the `configs` annotation, the union annotation and the suppression scan: 15/15 pass — `...\ep-00-012\verification.log`
- Seeded regression on a scratch copy outside the tree: reverting one `LucideIcon` declaration reproduced 18 errors (exit 2), proving the typecheck gate is still live; the copy was deleted afterwards.
- Suppression scan: 0 `@ts-ignore`/`@ts-expect-error`/`@ts-nocheck` directives, `skipLibCheck` unchanged, 0 `any` in `App.tsx`.
- Tracked tree byte-identical to `HEAD`; the only untracked additions are the implementation plan and the Definition of Done for this task.

**4. Follow-up unchanged.** The `QUA-38` follow-up into `EP-00-010` stands. This amendment does not amend the approved phase document.

**5. Founder review recorded.** On 2026-11-06 the project lead reviewed this record and its amendment and approved the task’s completion. That records the `[FOUNDER]` step only. It does not substitute for the architect review required by `QUA-29`/`QUA-31`, no architect review is claimed, and the task is not marked `Verified` until that review exists.

**6. Task closed — 2026-11-06.** Status advanced to `Verified` on the project lead’s instruction. Basis: `pnpm typecheck` exit 0 with no suppression; `pnpm build` exit 0; the 15-point fact verification (15/15); the seeded regression proving the gate still fails when a correction is reverted; and a tracked tree byte-identical to `HEAD` apart from these records. Two limits are recorded rather than implied away. First, no architect review exists; `QUA-29`/`QUA-31` are satisfied only through the approved time-boxed deviation `DEV-001`, whose compensating controls do not extend to `G4`, and which must be settled before `EP-00-007`. Second, because both files entered history with the root commit, the §1 limitation stands: the annotation-only claim rests on inspection of committed content and the compiler, not on a hunk diff. Closing this task does not close `EX-14` or `EX-01`.
