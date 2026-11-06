# Task Implementation Plan — EP-00-012
## Prototype typecheck remediation

> Planning artifact only. No repository file was created or modified. The approved Phase document is unchanged. Nothing below is implemented by this document.

---

### 0. Verified starting position (inspected and executed today, 6 November 2026)

| Fact | Verified state |
|---|---|
| Task class | `[FOUNDER]` — touches `src/app/App.tsx`, the visual authority (`GOV-09`) |
| Phase authority | `EP-00 - Execution Readiness.md` §6 stage 1, §6.2 critical path, §9 item `EP-00-012`, §11 criterion `C12` |
| Failure origin | `EP-00-001` T3 produced **47** errors — 46 in `App.tsx`, 1 in `vite.figma.config.ts` (transcript retained at `...\Temp\opencode\ep-00-001\typecheck.log`) |
| Error census (from that transcript) | **43×** `TS2322` icon-variance, **1×** `TS2739` `TITLES` missing keys, **1×** `TS2322` `getAdminModuleData` object, **1×** `TS2349` `resolveUserConfig` not callable |
| Intermediate state (after icon + `TITLES` fixes only) | exactly **1** error remained — the `configs` object, at `App.tsx(3514,3)` (`typecheck-2.log`) |
| Current tree | `pnpm typecheck` → **exit 0, empty output** (re-run today); `pnpm build` → **exit 0**, `dist/` produced in 4.46 s |
| Suppression scan | No `@ts-ignore`, `@ts-expect-error`, `@ts-nocheck` anywhere. Two `any` casts in `vite.figma.config.ts` (the Figma error-overlay wrapper) are pre-existing and outside the task |
| `tsconfig.json` | `strict: true`, `skipLibCheck: true` (pre-existing, unchanged), `noEmit` |
| Git | 6 commits on `main`, tag `v0.0.1-bootstrap`, working tree **clean**. The four corrections live inside the root commit `8029466` — `App.tsx` and `vite.figma.config.ts` are touched by **no other commit** |
| Phase plan dependency | `EP-00-001` T3 and criterion `C4` both reference this task; §8 risk `R3` is the risk this task closes |

**Consequence — one governance finding, not a technical one.** The work package record describes the state as *"implemented and locally verified; awaiting `[FOUNDER]` review of the diff"*, and the phase plan treats `EP-00-012` as a separate type-only diff under `C12`. In the repository, the corrections are already **inside the root commit**, so there is no standalone `EP-00-012` diff to review. The reviewable artifact is `git show 8029466 -- src/app/App.tsx vite.figma.config.ts`. This plan therefore treats the engineering work as **done and verified**, and the remaining work as **review, evidence and record reconciliation** — see §16 and §20.

---

### 1. Task Objective

Make `pnpm typecheck` exit **0** on the pinned toolchain, with **no suppression**, by correcting the genuine type errors `EP-00-001` T3 revealed — and do it as a **type-level correction only**, so the visual authority (`src/app/App.tsx`) keeps its pixels, copy, layout and behaviour.

After this task is true:

1. `pnpm typecheck` exits 0 with no `@ts-ignore`, `@ts-expect-error`, `any` widening, `noImplicitAny` change or `skipLibCheck` change.
2. The 47 errors are **accounted for individually** and none is silenced.
3. The emitted JavaScript changes only by two empty strings in `TITLES`, which never render.
4. `pnpm build` still produces the Figma Make preview bundle.
5. The diff is reviewed under `[FOUNDER]` and the record is honest about what was verified and how.

---

### 2. Business Problem Being Solved

`EP-00-001` exists so the project has a reproducible base. Its T3 gate — "the tree typechecks" — **failed**, and the failure was not a tooling defect: 46 of the 47 errors were in the prototype itself, caused by a hand-written prop type that the icon library never satisfied.

This is the second instance of the v1 failure mode in EP-00. The first was a stale lockfile (a tree that could not be rebuilt); this one is a tree that *looks* finished and was never compiled. Left unfixed, one of two things happens, and both are worse than the errors:

- someone adds `@ts-ignore` to get a green light, and the typecheck gate becomes decorative for the rest of the project's life; or
- the prototype is "cleaned up" under time pressure, which is an unapproved product change to the visual authority.

`EP-00-012` exists to take the third path: diagnose each error, fix the type at its **declaration**, and prove that no behaviour moved. Its business value is indirect but structural — it converts a red gate into evidence, and it makes `C4`/`TG-03` ("typecheck is green and unsuppressed") a claim backed by a transcript.

---

### 3. Scope

#### 3.1 In scope — the four approved corrections, nothing else

| # | File | Correction | Errors closed |
|---|---|---|---|
| 1 | `src/app/App.tsx` | Replace `React.ComponentType<{ size: number; color: string }>` with `LucideIcon` at all **8** declaration sites; add `import type { LucideIcon } from "lucide-react"` | 43 |
| 2 | `src/app/App.tsx` | Add `"forgot-password": ""` and `"reset-sent": ""` to `TITLES: Record<Screen, string>` | 1 |
| 3 | `src/app/App.tsx` | Annotate `configs` in `getAdminModuleData` with its declared record type **instead of** `satisfies`, restoring contextual typing for `fields` | 1 |
| 4 | `vite.figma.config.ts` | Type `userConfig` as `UserConfig \| ((env: ConfigEnv) => UserConfig \| Promise<UserConfig>)` before the `typeof === 'function'` branch | 1 |

#### 3.2 Out of scope — must not be done here

- Any visual, copy, layout, spacing, colour, radius, shadow or token change. No new hex. No restyle.
- Any behaviour change; the only permitted runtime delta is two empty `TITLES` entries.
- Any dependency, lockfile, toolchain, `tsconfig.json`, `.mise.toml` or `pnpm-workspace.yaml` change.
- Any suppression: `@ts-ignore`, `@ts-expect-error`, `@ts-nocheck`, `any` widening, `skipLibCheck` change, `tsconfig` exclusion of `App.tsx`, or a `// eslint-disable` equivalent.
- Any refactor: no component extraction, no splitting the 3,8xx-line file, no token migration (`AGENTS.md` §7 #12 — that is a separate, approved-as-touched job).
- Any edit to `documents/Context/*`, the phase plan, `EP-00-000`, or `EP-00-001`'s record beyond what this task's own record already states.
- Any new script, config, helper, type utility or CI stage (the typecheck stage is `EP-00-006`).
- Fixing unrelated type weaknesses the file merely *contains* (e.g. the `EX-14` `noUncheckedIndexedAccess` gap) — those are open register rows, not this task's errors.

---

### 4. Existing Asset and Dependency Analysis

#### 4.1 Assets inspected before proposing anything

| Asset | Path | What it provides | Decision |
|---|---|---|---|
| Phase authority | `EP-00 - Execution Readiness.md` §9, §11 `C12`, §8 `R3` | Objective, scope, evidence expectations, the prototype exception | **Reuse as single source of truth** |
| Work package record | `EP-00-012 - Prototype typecheck remediation.md` | Approved scope, reuse check, test plan, rollback, approver | **Reuse; reconcile with §0 finding** |
| Failing transcript | `...\ep-00-001\typecheck.log` (120 KB) | Exact error census and messages | **Reuse as the "before" evidence** — no re-derivation needed |
| Intermediate transcript | `...\ep-00-001\typecheck-2.log` | Proves the `configs` error was the **last** one standing | **Reuse as isolation evidence** |
| Passing transcript | `...\ep-00-001\typecheck-3.log` | Exit 0, empty output | **Reuse as the "after" evidence** |
| Icon type | `lucide-react` — `LucideIcon` export | The package's own `ForwardRefExoticComponent<Omit<LucideProps,"ref"> & RefAttributes<SVGSVGElement>>` alias | **Reuse** — do not redefine |
| Icon props | `lucide-react` `LucideProps` | `size?: string \| number`, `color?: string` | **Constraint** — proves the hand-written type was wrong, not the icons |
| Nav declarations | `NavItem` (943), `exploreAdminWorkspaces` (967), `earnAdminWorkspaces` (972), `MobileNavEntry` (1092), `ActivityNavItem` (2695) | The five nav-side declaration sites | **Extend in place** (widen to `LucideIcon`) |
| Admin declarations | `getAdminModuleData` return type (3447), `configs` (3448), `adminWorkspaceConfig` (3589) | The three admin-side declaration sites | **Extend in place** |
| Shared record type | `AdminModuleRecord` (3440) — `fields: Record<string, string>` | The genuine contract that the `hiring` literals violate under `satisfies` | **Reuse unchanged** — do not loosen it |
| Screen union | `type Screen` (31) and `TITLES` (3637) | Exhaustive title map | **Extend in place** — two keys |
| Auth gating | `AUTH_SCREENS` (3656), `isAuth` (3673), `TopBar` (2798, 3765) | Proves auth screens render **outside** the shell, so `TITLES` is never read for them | **Verified**, not assumed |
| Build wrapper | `vite.figma.config.ts` `resolveUserConfig` (85) | The one non-prototype error | **Extend in place** — one annotation |
| Type config | `tsconfig.json` | `strict`, `skipLibCheck` (already `true`), `noEmit` | **Reuse unchanged** |
| Standards | `GOV-09`, `QUA-29`/`QUA-31`, `QUA-38`, `SEC-56`, `TEC-08` | Class, review requirement, follow-up rule | **Constraint** |

#### 4.2 Dependencies

| Dependency | Type | State |
|---|---|---|
| `EP-00-001` install complete; T3 failed | Sequencing | **Met** |
| Founder approval to open the package (`[FOUNDER]`, `GOV-09`) | Governance | **Given 2026-11-06** |
| Architect review of the diff (`QUA-29`/`QUA-31`) | Governance | **Outstanding** |
| `lucide-react` 0.487.0 installed | Technical | **Met** |
| Pinned toolchain (Node 22, pnpm 10.34.9 contract) | Technical | **Met for this task**; the 10.34.3 parity gap is `EP-00-002` |
| Linux CI as reference environment (`R10`) | Environmental | Not applicable — typecheck is platform-independent; build parity is `EP-00-006`'s proof |

**Genuine external dependency: none.** This task adds no package, touches no service, opens no connection.

---

### 5. Reuse / Extension / Refactoring Assessment

| Need | Options considered | Decision | Justification |
|---|---|---|---|
| Icon prop type | (a) redefine `ComponentType<LucideProps>` locally; (b) import `LucideIcon`; (c) keep the narrow type and cast every icon | **(b) reuse the package's export** | `lucide-react` already publishes exactly this alias. (a) duplicates a third-party contract; (c) would add 43 casts and hide the real defect. No new type alias is created anywhere |
| `TITLES` exhaustiveness | (a) add two keys; (b) widen to `Partial<Record<Screen,string>>`; (c) change `Screen` | **(a) add two keys** | (b) deletes a compile-time guarantee for one missing entry; (c) changes the router's vocabulary. Two `""` values match the six existing auth entries exactly |
| `configs` typing | (a) annotate the object with its declared type; (b) keep `satisfies` and annotate each `fields`; (c) loosen `AdminModuleRecord.fields`; (d) cast the return | **(a) one annotation** | (b) is 13 redundant edits; (c) weakens a shared domain record to fix one literal (a contract regression); (d) is a suppression in spirit. (a) restores the contextual typing `satisfies` deliberately removed — the minimum correct change |
| `resolveUserConfig` narrowing | (a) union annotation; (b) `typeof` guard + separate variable; (c) cast to `any` | **(a) union annotation** | `vite.config.ts`'s default export is a config object or a config function; the union states the real runtime contract. (b) is equivalent but noisier; (c) is forbidden |
| A shared "icon prop" type or `src/types/` module | Create now | **Reject** | `lucide-react` owns it; a new module would be a parallel type system with one consumer. If a Hivorr-owned icon abstraction ever appears, it belongs to the EP-01 design-system extraction, not here |
| New typecheck script / CI stage | Create now | **Reject** | `typecheck` already exists in `package.json`; the pipeline is `EP-00-006` |

**Genuine new assets created by this task: none.** Every correction widens or annotates an existing declaration with an existing exported type. That is the strongest possible reuse outcome and should be stated plainly in the record.

**Why no refactor was appropriate.** The file is 3,8xx lines with 1,065 inline-styled lines (§7 #12, `EX-01`). Extracting components or migrating tokens while fixing four type errors would produce an unreviewable diff, breach "bounded change scope" (§3), and destroy the `C12` property that the diff contains *only* type annotations. The discipline of not refactoring is the deliverable here.

---

### 6. Recommended Technical Approach

Four independent, ordered corrections. Each is diagnosis-first: the error is understood before the type is widened.

#### 6.1 Correction 1 — `ComponentType` → `LucideIcon` (43 errors)

**Diagnosis.** `LucideIcon` is `ForwardRefExoticComponent<Omit<LucideProps,"ref"> & RefAttributes<SVGSVGElement>>`. `LucideProps.size` is `string | number` and every prop is optional. A component typed as `ComponentType<{ size: number; color: string }>` requires *mandatory* `number`/`string` props, so the real icon component is **not assignable** — props are contravariant. The declaration was wrong; the icons were correct. That is why **one** wrong declaration produced **43** errors at the usage sites (nav arrays, mobile-nav entries, activity arrays, admin config records).

**Change.** At each of the eight declaration sites, replace the hand-written type with the imported alias:

```ts
import type { LucideIcon } from "lucide-react";
...
icon: LucideIcon;
```

Sites: `NavItem`, the two admin-workspace array declarations, `MobileNavEntry`, `ActivityNavItem`, the `getAdminModuleData` return type, the `configs` record type, and the `adminWorkspaceConfig` record type.

**Not chosen:** `ComponentType<LucideProps>` (works, but duplicates a third-party alias and loses the package's own guarantees — the exact anti-duplication rule the brief demands).

#### 6.2 Correction 2 — two missing `TITLES` keys (1 error)

**Diagnosis.** `TITLES: Record<Screen, string>` is exhaustive over a 76-member `Screen` union. Two auth routes exist in the union and in `AUTH_SCREENS` but were never given titles (`TS2739`).

**Change.** Add `"forgot-password": ""` and `"reset-sent": ""` alongside the existing `splash/login/signup/otp/role-select` entries, which are also `""`.

**Why `""` is correct, not a placeholder.** `TITLES` is read only at `TopBar` (2798) and the shell render (3765). Auth screens are gated by `isAuth` (3673) and render outside the shell, so the empty title is never painted. It matches the six existing auth entries, so it introduces no new convention. **Verified, not assumed.**

#### 6.3 Correction 3 — contextual annotation in `getAdminModuleData` (1 error)

**Diagnosis.** With `satisfies`, the object literal is inferred **on its own** and then checked. The `hiring` records carry heterogeneous `fields` keys (`"Hired on"`, `"Start date"`, `"Completed"`, `"Selected on"`…). TypeScript infers a union of object shapes whose absent keys are `undefined`, which violates the `Record<string, string>` index signature on `AdminModuleRecord` — hence `Property '"Completed"' is incompatible with index signature. Type 'undefined' is not assignable to type 'string'`.

**Change.** Annotate the object with its declared record type (`const configs: Record<AdminRecordModule, {...}> = { ... }`) instead of `satisfies`. Contextual typing then widens each `fields` object to `Record<string, string>`, which is what the data already is.

**Not chosen:** loosening `AdminModuleRecord.fields` to `Record<string, string | undefined>` — that would weaken a shared record used by every admin module and force `?? ""` at every render site. It fixes one literal by degrading a domain contract.

**No data changed.** Not one string, key or record was edited — proven by the diff being annotation-only.

#### 6.4 Correction 4 — `resolveUserConfig` union annotation (1 error)

**Diagnosis.** `userConfig` is imported from `vite.config.ts`, whose default export type does not include the callable member in the imported position. Under `typeof config === 'function'`, TypeScript narrows the non-callable type to `never`, so `config(env)` raises `TS2349` — "This expression is not callable" — on code that runs correctly.

**Change.**

```ts
const config = userConfig as UserConfig | ((env: ConfigEnv) => UserConfig | Promise<UserConfig>)
return typeof config === 'function' ? await config(env) : await config
```

**Is this a suppression?** No. It is a widening to a **named union of real types** that describes the documented Vite config contract. It adds no `any`, no `@ts-*` directive, and no `unknown`→`any` escape. The runtime branch is unchanged. The stricter alternative — typing `vite.config.ts`'s export so it needs no assertion — would touch a second config file and pre-empt `EP-00-002`'s toolchain contract work.

#### 6.5 Stop rules

Stop and report if any of these occur:

- A symptom needs a **fifth** correction, or any of these four does not hold. That is a different diagnosis and possibly a different package (`R3`).
- A fix would change JSX, style, copy, structure or behaviour beyond the two empty titles.
- A fix would require suppression, an `any` widening, `skipLibCheck`, or excluding a file from `tsconfig.json`.
- `pnpm build` regresses (the preview must keep working — `ARCHITECTURE.md` §8.11).
- The diff grows beyond annotation-only hunks plus two `""` entries.

---

### 7. Required Systems, Modules and Components

| Component | Role | New? |
|---|---|---|
| `src/app/App.tsx` | Visual authority; 46 of 47 errors | **Existing — 3 type-level edits** |
| `vite.figma.config.ts` | Figma Make wrapper; 1 error | **Existing — 1 annotation** |
| `lucide-react` (`LucideIcon`, `LucideProps`) | Source of the correct type | **Existing — re-exported type reused** |
| `tsc` 5.9.3 via `pnpm typecheck` | The gate | **Existing, unchanged** |
| `vite` 6.3.5 + Figma wrapper via `pnpm build` | Preview regression check | **Existing, unchanged** |
| Retained transcripts | Evidence | **Existing artefacts** |

**No module, service, API, worker, database, schema, hook, component, utility, config or dependency is created.**

---

### 8. Data Requirements

- **Type-level only.** No domain model, table, record or literal value changes.
- **Runtime delta:** exactly two properties (`"forgot-password"`, `"reset-sent"`) added to the `TITLES` object with value `""`. Invisible because auth screens render outside the shell.
- **Evidence data:** the before/after error census, the transcripts, the diff, and the suppression scan — stored outside the tree until `EP-00-010` indexes them. No personal data, no secrets, no absolute paths left unredacted.

---

### 9. Database Considerations

**None.** No table, schema, migration, grant, RLS policy, Supabase project, data-API path or connection. The task is a compile-time correction in a prototype with no data layer. The record must state this so a later reader does not infer that a persistence concern arrived with the type fix.

---

### 10. API Requirements

**None.** No endpoint, contract, OpenAPI document, versioning decision or webhook. No server exists. The one server-adjacent file touched (`vite.figma.config.ts`) is a local build wrapper, not an API surface.

---

### 11. User Interface Requirements

**No user-facing change is permitted.** The requirements are all *negative* and must be proven:

1. No colour, type size, spacing, radius, shadow, gradient or token change (`AGENTS.md` §2).
2. No copy change — the two `TITLES` entries are empty and never rendered.
3. No JSX structure or layout change.
4. `pnpm build` still produces the preview bundle.
5. `App.tsx` and `vite.figma.config.ts` diffs contain **only** type annotations plus the two `""` entries — reviewable in one sitting (`QUA-32`).

---

### 12. User Experience Considerations

- **End user:** none, by design. This is the rare UI-file task whose success criterion is that the interface is indistinguishable.
- **Founder/reviewer (`[FOUNDER]`):** must be able to confirm in one pass that the visual authority was not altered. The review artefact is the diff hunks, not a screenshot — no screenshot baseline exists until EP-01 (§11 `C12` says so explicitly).
- **Future contributor:** sees a prototype that compiles and a package-typed icon contract, so new nav items are checked automatically. The `LucideIcon` alias is discoverable because it is imported from the library that owns it, not buried in a local `types.ts`.
- **Failure clarity:** a wrong icon now fails at the array literal with a message about icons, not a 43-error cascade from one declaration.

---

### 13. Security Considerations

| Concern | Control |
|---|---|
| Quality-control weakening | The whole point is to keep the typecheck gate honest. No suppression, no `any` widening, no `skipLibCheck` change, no file exclusion. A typecheck that passes because the checker was told to ignore something is a control removed (`SEC-*`, `GOV-12` deviation) |
| Trust boundary | **Unchanged.** No auth, session, token, permission, personal data, financial path or third party is touched |
| Secret exposure | None; no `.env`, no key, no credential, no log containing a token. Transcripts contain only compiler text and local paths — redact the home segment before indexing |
| Unsafe sink / injection | None. No HTML sink, no `dangerouslySetInnerHTML`, no dynamic code path altered |
| Dependency supply chain | **No change at all** — no add, upgrade, removal or lockfile edit (`TEC-08`, `TEC-09`, `SEC-56`) |
| Build integrity | `pnpm build` must stay green so the preview artifact is not silently broken (`ARCHITECTURE.md` §8.11) |
| Agent boundary | An agent may edit types and produce transcripts; it may not approve the diff or self-merge (`EES` §5.6, `QUA-29`) |
| Residual risk | The `as` union assertion in §6.4 is a compile-time statement about an imported module's contract. If `vite.config.ts`'s export shape changes, the assertion can drift silently. **Recorded**, and naturally closed when `EP-00-002` restates the toolchain contract |
| Reporting | Completion report states files changed, the `GOV-09`/`GOV-12`/`QUA-29` rules applied, the suppression scan result, the tests run with results, residual risk, and confirmation that no secret was exposed. "Implemented" alone is not a report (§4A) |

Audit readiness (§19): this task touches nothing that requires an `R1`–`R5` classification or an impact note — no money, identity, personal data, authentication, authorisation, third party, production infrastructure or audit log.

---

### 14. Performance Considerations

- **Runtime:** zero. Type annotations are erased. The two `""` properties add negligible bytes to a 524 kB bundle (already over Vite's 500 kB warning, which exists and is **not** this task's to fix).
- **Build time:** unaffected (4.46 s today).
- **Developer feedback:** `tsc --noEmit` is the fastest reliable signal in the phase; making it green at stage 1 means every later task inherits a gate that can actually run — the precondition for `EP-00-006`'s stage ordering.
- **Review cost:** deliberately minimal — a diff of annotations. That is a performance property of the *process*, and it is why refactoring was refused.

---

### 15. Testing Strategy

Every gate must be able to fail. `T1` and `T2` demonstrably failed **before**.

| # | Test | Before → after | Deny path / seeded failure |
|---|---|---|---|
| **T1** | `pnpm typecheck` | **47 errors → exit 0**, empty output | Fails on any real type error; must not pass via suppression |
| **T2** | Error census: 47 = 43 + 1 + 1 + 1, each mapped to a correction, zero unexplained | All 47 accounted for; intermediate run left exactly 1, which correction 3 closed | Fails if any error is unaccounted for, or if the count drops for a reason other than a fix |
| **T3** | Suppression scan across `src/**`, `vite.config.ts`, `vite.figma.config.ts`, `tsconfig.json` | No `@ts-ignore`/`@ts-expect-error`/`@ts-nocheck`; `skipLibCheck` unchanged; no new `any` | Fails on any suppression directive, any `any` widening, or a relaxed `tsconfig` |
| **T4** | `pnpm build` | F-01 blocked earlier; **exit 0 today** | Fails on a broken wrapper, a missing native module, or a type error |
| **T5** | Behavioural equivalence: the only runtime delta is two empty `TITLES` entries; auth screens render outside the shell (`isAuth`, 3673) | Confirmed by reading the render path, not assumed | Fails if any JSX, style, copy or literal other than the two titles changes |
| **T6** | Diff-shape check: every hunk in `App.tsx`/`vite.figma.config.ts` is an annotation or the two `""` entries | Diff is annotation-only | Fails on a structural, styling, naming or logic hunk |
| **T7** | Seeded regression (on a scratch copy outside the tree): revert one `LucideIcon` declaration and confirm `typecheck` fails again | Proves the gate is still wired | Fails if the reverted copy still passes |
| **T8** | Protected-file check: `package.json`, `pnpm-lock.yaml`, `tsconfig.json`, `.mise.toml`, `pnpm-workspace.yaml`, `documents/Context/*` byte-identical to `EP-00-001`'s state | Unchanged | Fails on any edit outside the two source files |

**Evidence:** E1 before transcript (47) · E2 intermediate transcript (1) · E3 after transcript (exit 0) · E4 error census table · E5 suppression scan · E6 build transcript · E7 diff of the two files · E8 seeded-regression transcript · E9 protected-file comparison.

---

### 16. Recommended Implementation Sequence

| Step | Work | Gate |
|---|---|---|
| **0** | Confirm pre-conditions: `EP-00-001` install complete, founder approval recorded, `[FOUNDER]` class acknowledged | Hard stop if approval is absent |
| **1** | Capture the failing state and census from `typecheck.log`; do not re-derive by guesswork | T2 baseline |
| **2** | Correction 1 — widen the 8 icon declarations to `LucideIcon` | 43 errors clear |
| **3** | Correction 2 — add the two `TITLES` keys | 1 error clears |
| **4** | Correction 3 — annotate `configs` instead of `satisfies` | Last error clears; T1 green |
| **5** | Correction 4 — union-annotate `userConfig` in `vite.figma.config.ts` | T1 verified in full |
| **6** | Verify: `pnpm typecheck` (T1), suppression scan (T3), `pnpm build` (T4), diff-shape and behavioural review (T5/T6), protected files (T8) | All green |
| **7** | Seeded regression on a scratch copy (T7) | Gate proven to fail |
| **8** | Founder review of the diff under `[FOUNDER]`; architect review (`QUA-29`/`QUA-31`) | `G1 → G2` |
| **9** | Reconcile the record: state that the corrections sit inside the root commit and cite `git show 8029466 -- src/app/App.tsx vite.figma.config.ts` as the review artefact; fold into `EP-00-010` evidence index (`QUA-38`) | `C12` evidence complete |
| **10** | Hand the green typecheck to `EP-00-001` T3, then `EP-00-002` | Phase order resumes |

**Critical path:** `000 → 001 → 012 → 002 → 003 → 004 → 006 → 008 → 007 → 010 → 011` (phase plan §6.2). `012` is the only item that unblocks `001`'s T3.

**Current position:** steps 0–7 are **already evidenced**; step 8 is the live gate; step 9 is the outstanding record work.

---

### 17. Expected Outcome

- `pnpm typecheck` exits 0 on the pinned toolchain, with **no** suppression of any kind and every one of the 47 errors individually accounted for.
- The icon contract is the icon library's own type, so future nav items are checked automatically.
- The prototype is **visually, textually and behaviourally identical**; the only runtime delta is two empty titles that never render.
- `pnpm build` still produces the Figma Make preview bundle.
- `EP-00-001` T3 becomes a pass, `C4`/`TG-03` gain an artifact, and the typecheck gate enters `EP-00-006` already green.
- The record honestly distinguishes what was verified (transcripts, diff, scans) from what was approved (founder review), and does not claim a separate review diff that does not exist.

---

### 18. Definition of Done

- [ ] `pnpm typecheck` exits 0 with empty output; transcript retained (E3).
- [ ] All 47 errors are mapped to one of the four corrections; none unexplained (E4).
- [ ] No `@ts-ignore`, `@ts-expect-error`, `@ts-nocheck`, `any` widening, `skipLibCheck` change, or `tsconfig` exclusion was added (E5).
- [ ] `LucideIcon` is imported from `lucide-react`; no local icon type alias was created.
- [ ] `TITLES` has both missing keys with `""`, matching the existing auth entries.
- [ ] `configs` is annotated with its declared record type; `AdminModuleRecord` and its `fields` contract are **unchanged**.
- [ ] `resolveUserConfig` uses a named union; no `any`.
- [ ] No visual, copy, layout, token or behaviour change; the diff is annotation-only plus two `""` entries (E7).
- [ ] `pnpm build` exits 0 and the preview still builds (E6).
- [ ] `package.json`, `pnpm-lock.yaml`, `tsconfig.json`, `.mise.toml`, `pnpm-workspace.yaml` and `documents/Context/*` are byte-identical to the pre-task state (E9).
- [ ] The seeded-regression run proves the typecheck gate still fails when a fix is reverted (E8).
- [ ] Founder review under `[FOUNDER]` is recorded; no agent self-approval; architect review per `QUA-29`/`QUA-31`.
- [ ] The record states where the diff actually lives (root commit) and is folded into `EP-00-010`'s evidence index (`QUA-38`).
- [ ] Rollback is recorded: revert the four edits; no data, schema, lockfile or dependency involved.
- [ ] No secret, credential or unredacted local path appears in any evidence artefact.

---

### 19. Implementation AI Execution Profile

| Field | Recommendation |
|---|---|
| **Recommended coding reasoning level** | **Medium** |
| **Justification** | The mechanics are small and local: four annotations across two files, executed against a compiler that reports precisely. The difficulty is **judgement, not volume** — diagnosing *why* `satisfies` loses contextual typing, why prop variance makes 43 errors out of one bad declaration, and why an `as` union is not a suppression. That is squarely Medium: a competent agent with the failing transcript and the stop rules will converge. It does **not** warrant High, because no design decision, trust boundary, security control or data model is in play, and the phase plan itself specifies `Planning – High · Coding – Medium`. **Escalate to High and stop** if a fifth correction is needed, if a fix would touch JSX/style/copy, or if the only apparent route to green is a suppression — those are architect/founder decisions, not reasoning problems to solve mid-task. |

---

### 20. Decisions and Open Points Before Completion

1. **Where the diff lives — needs the founder's acknowledgement.** The four corrections are already inside root commit `8029466` (`v0.0.1-bootstrap`). The phase plan's `C12` assumes a reviewable `EP-00-012` diff. Recommended: accept `git show 8029466 -- src/app/App.tsx vite.figma.config.ts` as the review artefact, record the embedding explicitly, and do not rewrite history (history rewriting is out of scope for every EP-00 item). This is a record-accuracy decision, not an engineering one.
2. **The `as` union in `vite.figma.config.ts`.** Recommended: keep it, recorded as a named-union assertion with no `any`, and let `EP-00-002` close the underlying contract drift. Alternative — type `vite.config.ts`'s export properly now — touches a second config file and belongs to the toolchain contract task.
3. **`TITLES` empty strings.** Recommended: `""`, matching the six existing auth entries, verified never rendered. Alternative — real titles ("Forgot password", "Check your email") would be a **copy decision** and is out of scope; if wanted, it is a product change approved separately.
4. **Follow-up registration.** Recommended: record this package in `EP-00-010`'s evidence index under `QUA-38` as the phase plan's §9 and §14 revision already direct, without amending the approved phase document.
5. **`EX-14` / `EX-01`** (no `noUncheckedIndexedAccess`, inline styles) remain **open register rows**. This task must not appear to close them.

---

**Plan status:** complete for `EP-00-012` only. No other task has been planned, no production code has been written, no repository file has been created or modified, and the approved Phase document is untouched.

**Awaiting your approval before any implementation or record change proceeds.** If you want this written into the repository as a planning artifact (for example `documents/Task-Implementation/EP-00/EP-00-012 - Prototype typecheck remediation plan.md`), say so and switch me out of Plan mode — I will not create it from here.
