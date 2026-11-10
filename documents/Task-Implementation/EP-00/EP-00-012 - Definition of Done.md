# Task Definition of Done - EP-00-012
## Prototype typecheck remediation

| Field | Value |
|---|---|
| **Task ID** | `EP-00-012` |
| **Task Name** | Prototype typecheck remediation |
| **Related Phase** | `EP-00` - Execution Readiness |
| **Reference Implementation Plan** | `documents/Task-Implementation/EP-00/EP-00-012 — Prototype typecheck remediation (Implementation Plan).md` |
| **Artifact under verification** | `src/app/App.tsx` (type-level corrections) and `vite.figma.config.ts` (one annotation), committed in `8029466` |
| **Task class** | `[FOUNDER]` - the change touches the visual authority (`GOV-09`) |
| **Verification owner** | Project lead, with architect review (`QUA-29`/`QUA-31`) and founder approval |
| **Verification date** | 2026-11-06 |
| **Overall result** | `Verified` — see the approval record in §9 and the work-package record. Architect review remains covered by `DEV-001`. |

**Verification boundary.** This DoD verifies only the four type-level corrections produced by `EP-00-012` and their non-effect on the prototype. It does not verify `EP-00-001`'s lockfile, commit identity or tag; `EP-00-002`-`011`; CI; branch protection; scanning; or any database, API, worker or product capability. Nothing outside the two named source files is in scope.

**How to use this document.** Every row is a check the project lead can perform. A row passes only when the stated evidence exists and was inspected, not when the author asserts it. Any unchecked row in §8 blocks approval unless it is recorded as an approved exception in §9.

---

## 1. Functional Verification

### 1.1 Required functionality

| ID | Verification | Pass condition | Evidence |
|---|---|---|---|
| **F-01** | The typecheck gate is green | `pnpm typecheck` exits `0` and prints no diagnostics | Terminal transcript with exit code |
| **F-02** | The failure is closed, not hidden | The recorded 47 errors (46 `App.tsx`, 1 `vite.figma.config.ts`) are reduced to `0`, and each error family maps to a named correction: 43 icon-variance, 1 `TITLES`, 1 `getAdminModuleData`, 1 `resolveUserConfig` | Before transcript (`typecheck.log`), intermediate transcript (`typecheck-2.log`), after transcript (`typecheck-3.log`) |
| **F-03** | Correction 1 is complete | `LucideIcon` is imported from `lucide-react` with `import type`, and all **8** icon declaration sites use it: `NavItem`, the two admin-workspace arrays, `MobileNavEntry`, `ActivityNavItem`, the `getAdminModuleData` return type, the `configs` record type, the `adminWorkspaceConfig` record type. No `React.ComponentType<{ size: number; color: string }>` remains | File inspection + `Select-String` count |
| **F-04** | Correction 2 is complete | `TITLES` contains `"forgot-password": ""` and `"reset-sent": ""`; the record remains `Record<Screen, string>` and exhaustive over all 76 `Screen` members | File inspection |
| **F-05** | Correction 3 is complete | `configs` in `getAdminModuleData` is annotated with its declared record type; `satisfies` is no longer used there; `AdminModuleRecord` and `fields: Record<string, string>` are unchanged | File inspection |
| **F-06** | Correction 4 is complete | `resolveUserConfig` types `userConfig` as `UserConfig \| ((env: ConfigEnv) => UserConfig \| Promise<UserConfig>)` before the `typeof === 'function'` branch; the runtime branch is unchanged | File inspection |
| **F-07** | No suppression of any kind | No `@ts-ignore`, `@ts-expect-error`, `@ts-nocheck`, no `any` widening introduced, no `skipLibCheck` change, no `tsconfig` exclusion, no lint-style disable | Repository-wide scan + `tsconfig.json` diff |
| **F-08** | The preview still builds | `pnpm build` exits `0` and produces `dist/` | Build transcript with exit code |
| **F-09** | The prototype is visually untouched | No colour, type size, spacing, radius, shadow, gradient, token, copy, JSX structure or layout change anywhere in the diff | Diff review, hunk by hunk |
| **F-10** | The only runtime delta is intentional and inert | The emitted JavaScript differs only by two empty `TITLES` entries; those entries are never rendered because `AUTH_SCREENS`/`isAuth` route auth screens outside the `TopBar` shell | Diff + render-path review (`AUTH_SCREENS` 3656, `isAuth` 3673, `TopBar` 2798/3765) |
| **F-11** | The review artefact is identifiable | The corrections can be inspected with `git show 8029466 -- src/app/App.tsx vite.figma.config.ts`, and no other commit touches those files | `git log --oneline -- <paths>` |
| **F-12** | The record is honest about where the diff lives | The work package record states the corrections sit inside the root commit and names the review command; it does not claim a standalone `EP-00-012` diff that does not exist | Record review |
| **F-13** | Rollback is executable | Reverting the four corrections returns the tree to the 47-error state; no data, schema, lockfile or dependency is involved | Rollback note + reverted-copy check |
| **F-14** | No new assets were created | No new module, type alias, utility, component, config, script, test harness or dependency exists | File list + `package.json` diff |
| **F-15** | Protected files are byte-identical | `package.json`, `pnpm-lock.yaml`, `tsconfig.json`, `.mise.toml`, `pnpm-workspace.yaml` and `documents/Context/*` match the `EP-00-001` state | SHA-256 manifest before/after |

### 1.2 Expected workflows

| ID | Workflow | Pass condition |
|---|---|---|
| **W-01** | Diagnose → widen the declaration → re-run `typecheck` → verify build → review | Each step is evidenced in order; no step is skipped to reach green |
| **W-02** | A verification row fails | Work stops, the failing row is recorded, and the fix is a type-level correction only - never a suppression, never a prototype restyle |
| **W-03** | A fifth error appears that the four corrections do not explain | Work stops and is reported as a new diagnosis, not folded into this task |
| **W-04** | Reviewer wants visual proof | The reviewer is shown the annotation-only diff and the green build; the absence of a screenshot baseline until EP-01 is stated, not papered over |
| **W-05** | Approval requested | The project lead completes §8 before any status advances beyond `In review` |

### 1.3 Success conditions

| ID | Condition | Pass condition |
|---|---|---|
| **S-01** | Phase criterion `C4` is supported | `pnpm typecheck` exit 0 exists as the linked artifact, with an unsuppressed diff |
| **S-02** | Technical goal `TG-03` is supported | Green, unsuppressed typecheck evidenced on the pinned toolchain |
| **S-03** | `EP-00-001` T3 becomes a pass | The same green transcript resolves `001`'s outstanding T3 row |
| **S-04** | Phase criterion `C12` is supported | The prototype diff is type-only and founder-reviewed |
| **S-05** | The gate is trustworthy | The typecheck check still fails when a correction is reverted (seeded proof retained) |
| **S-06** | Scope held | Exactly two source files differ; nothing else in the repository changed |

### 1.4 Error handling scenarios

| ID | Scenario | Required behaviour | Verify |
|---|---|---|---|
| **E-01** | A type error remains after the four corrections | Stop; report the exact diagnostic; do not add a suppression, `any`, or `tsconfig` exclusion | Re-run transcript + diff |
| **E-02** | The fix would require changing JSX, style or copy | Stop; escalate as a product decision; do not "tidy while here" | Diff review |
| **E-03** | `pnpm build` regresses | Stop; the preview must keep working (`ARCHITECTURE.md` §8.11); no workaround that changes the wrapper's behaviour | Build transcript |
| **E-04** | A reviewer proposes `@ts-expect-error` to finish quickly | Rejected; the deviation path (`GOV-12`) is required, and this task's scope forbids it outright | Diff + review note |
| **E-05** | `TITLES` empty values would render | Not possible for auth screens today; if a future shell renders them, it shows an empty title exactly like the six existing auth entries - recorded, not silently "fixed" with invented copy | Render-path review |
| **E-06** | The `as` union in `vite.figma.config.ts` drifts from `vite.config.ts` | Recorded as residual risk; closed by `EP-00-002`'s toolchain contract work, not silently patched here | Security row `SEC-08` |
| **E-07** | Evidence contains an unredacted local path or token-bearing URL | Redact before indexing; re-scan | Evidence scan |
| **E-08** | Someone edits the prototype to make a check pass | Rejected; the visual authority is founder-owned; the change is reverted and reported | File manifest |

### 1.5 Important user interactions

| ID | Consumer | Pass condition |
|---|---|---|
| **U-01** | Founder | Can confirm in one pass that no pixel, string or behaviour changed, from the diff alone |
| **U-02** | Architect | Can confirm the four corrections match the approved plan and that no suppression was introduced |
| **U-03** | Project lead | Can trace every closed error to a named correction and an evidence artefact |
| **U-04** | Future contributor | Sees a compiling prototype with a package-typed icon contract; new nav items are type-checked automatically |
| **U-05** | CI author (`EP-00-006`) | Inherits a `typecheck` stage that is already green and known to fail when broken |

---

## 2. Technical Verification

| ID | Verification | Pass condition | Evidence |
|---|---|---|---|
| **A-01** | Architecture compliance | No runtime module, service, API, worker, database, schema, migration, queue, container, auth component or new UI component is created or modified | File list + `git status` |
| **A-02** | Prototype change is type-only | The `App.tsx` hunks contain only type annotations, one `import type`, and the two `""` title entries - no logic, no structure, no styling | Diff, hunk by hunk |
| **A-03** | Icon type provenance | The icon type is `lucide-react`'s exported `LucideIcon`; no local alias, interface or wrapper redefines it | Import + declaration review |
| **A-04** | Import is type-only | The import uses `import type`, so no new runtime import is added to the bundle graph | File inspection |
| **A-05** | Type configuration unchanged | `tsconfig.json` is byte-identical: `strict: true`, `skipLibCheck: true`, `noEmit`, same `include`/`exclude` | SHA-256 comparison |
| **A-06** | Dependency and toolchain unchanged | `package.json`, `pnpm-lock.yaml`, `pnpm-workspace.yaml`, `.mise.toml` unchanged; `lucide-react` version unchanged | SHA-256 comparison |
| **A-07** | Module integration | Both files still participate in the same import graph; the app entry, router and screens resolve; no import path, export name or module boundary changed | Build + import review |
| **A-08** | Wrapper behaviour preserved | `vite.figma.config.ts` runtime behaviour is unchanged: same branch, same `mergeConfig`, same plugins, same server/preview settings | Diff review |
| **A-09** | Markdown/source integrity | Files remain UTF-8, valid TypeScript, no truncation, no mojibake introduced | Compiler + editor check |
| **A-10** | Diff reviewability | The change is reviewable in one sitting (`QUA-32`); no unrelated hunks, no reordering, no reformatting | Diff size and content |
| **A-11** | No extra artifacts | No test file, script, config, README, index or helper was added to satisfy the checks | Full untracked/tracked diff |
| **A-12** | Evidence sufficiency | Each of F-01-F-15 has a named artefact; no row rests on a prose claim | Evidence index cross-check |

**Practical method for A-05/A-06/F-15:** compare SHA-256 hashes of the protected paths before and after the verification run; `git status` alone does not prove absence of change for already-committed files.

---

## 3. Data Verification

**Applicability:** applicable only in the limited sense described below. No database exists and none is created; the "data" is the prototype's in-file literal content.

| ID | Verification | Pass condition | Evidence |
|---|---|---|---|
| **D-01** | No data creation | No record, entity, table, fixture or seed is created | Diff review |
| **D-02** | No data update | Every literal string in the admin configs, nav arrays and screens is unchanged - including the `hiring` records that motivated correction 3 | Spot-check `hiring`, `clients`, `payments` records |
| **D-03** | Data relationships unchanged | `Screen` → `TITLES` remains exhaustive; `AdminRecordModule` → `configs` remains exhaustive; `AdminModuleRecord.fields` remains `Record<string, string>` | Type inspection |
| **D-04** | Data accuracy | The two added `TITLES` values are exactly `""`, matching the existing auth entries; no invented copy | File inspection |
| **D-05** | Data integrity | No `undefined` is introduced into a rendered field; contextual typing widens objects, it does not change values | Compiler + diff |
| **D-06** | Contract preservation | `AdminModuleRecord` is not loosened; no optional `undefined` is added to any shared record type | Diff review |
| **D-07** | No database artefact | No migration, grant, RLS policy, schema or data-API path created | File list |
| **D-08** | Evidence data hygiene | Transcripts and diffs contain no personal data; local user-home paths redacted before indexing | Evidence review |

---

## 4. Security Verification

| ID | Verification | Pass condition | Evidence |
|---|---|---|---|
| **SEC-01** | No security control weakened | The typecheck gate is not bypassed; no suppression, `any` widening, `skipLibCheck` change or file exclusion | Scan + diff |
| **SEC-02** | Trust boundary unchanged | No authentication, authorisation, session, token, permission or access-control path is touched | Diff review |
| **SEC-03** | No secrets | No token, key, password, connection string, webhook URL or `.env` content in the source, diff or evidence | Secret-pattern scan |
| **SEC-04** | No credential-bearing URLs | No URL with an embedded token or signed parameter is added to any artefact | URL review |
| **SEC-05** | Sensitive data protection | No personal data is added or exposed; evidence contains compiler text and local paths only, redacted | Evidence review |
| **SEC-06** | Supply chain unchanged | No dependency added, removed or upgraded; no lockfile edit; `minimumReleaseAge` untouched (`TEC-08`, `TEC-09`, `SEC-56`) | SHA-256 + diff |
| **SEC-07** | No unsafe sink introduced | No HTML sink, dynamic code path, `eval`, or `dangerouslySetInnerHTML` change | Diff review |
| **SEC-08** | Residual risk recorded | The `as` union assertion is declared as a compile-time statement with a named owner and a closing task (`EP-00-002`) | Record review |
| **SEC-09** | AI boundary respected | An agent may have authored and verified; it did not approve, self-review or advance the status | Review record |
| **SEC-10** | Completion reporting complete | The report states files changed, rules applied (`GOV-09`, `QUA-29`, `QUA-31`), suppression-scan result, tests run, residual risk, and confirms no secret exposure | Report review |

---

## 5. Performance Verification

| ID | Verification | Pass condition | Evidence |
|---|---|---|---|
| **P-01** | No runtime cost | Type annotations are erased; no runtime branch, loop or allocation is added | Diff review |
| **P-02** | Bundle impact is negligible and explained | Only two empty properties are added to an existing object; the pre-existing >500 kB chunk warning is unchanged and not "fixed" here | Build output comparison |
| **P-03** | Build time unaffected | `pnpm build` completes in the same order of magnitude (recorded baseline ~4.5 s) | Build transcript |
| **P-04** | Developer feedback preserved | `pnpm typecheck` remains fast and is the first signal in the phase; it is not made slower by added tooling | Timing note |
| **P-05** | Review performance | The diff can be reviewed in one sitting; no reformat or restructure inflates it (`QUA-32`) | Diff size |
| **P-06** | Reliability | No unreachable code, no dead branch, no behaviour that depends on the assertion at runtime | Build + review |

---

## 6. Testing Verification

**Applicability:** manual compiler gates plus one seeded-failure proof. No test runner exists at this point (`EP-00-003`); no CI exists (`EP-00-006`). The record must not claim either.

| ID | Test | Pass condition | Evidence |
|---|---|---|---|
| **TV-01** | `pnpm typecheck` (T1) | Exit `0`, empty output | Transcript |
| **TV-02** | Error census (T2) | 47 = 43 + 1 + 1 + 1; every error mapped; intermediate run left exactly 1 | Census table + transcripts |
| **TV-03** | Suppression scan (T3) | No suppression directive; `skipLibCheck` unchanged; no new `any` | Scan output |
| **TV-04** | `pnpm build` (T4) | Exit `0`; `dist/` produced | Transcript |
| **TV-05** | Behavioural equivalence (T5) | Only delta is two empty `TITLES`; auth screens render outside the shell | Render-path review |
| **TV-06** | Diff-shape check (T6) | Every hunk is an annotation or the two `""` entries | Diff review |
| **TV-07** | Seeded regression (T7) | Reverting one `LucideIcon` declaration on a scratch copy makes `typecheck` fail again; the copy is outside the tree and deleted afterwards | Seeded-failure transcript |
| **TV-08** | Protected-file check (T8) | Protected paths byte-identical | SHA-256 comparison |
| **TV-09** | Manual verification | A reviewer other than the author ran T1, T3 and T4 independently and reproduced the results | Reviewer transcript |
| **TV-10** | Edge case - exhaustive union | `TITLES` covers all 76 `Screen` members; removing any single key makes typecheck fail | Compiler behaviour |
| **TV-11** | Edge case - both config branches | The function branch and the object branch of `resolveUserConfig` are both still reachable and correct | Code review |
| **TV-12** | Edge case - heterogeneous admin fields | At least one module with differing `fields` keys (`hiring`) and one uniform module (`clients`) both type-check and render unchanged | Review + build |
| **TV-13** | Failure scenario - new type error | Introducing a deliberate type error on a scratch copy fails the gate; no suppression is available as a shortcut | Scratch-copy transcript |
| **TV-14** | Failure scenario - build | A broken import on a scratch copy fails `pnpm build`; proves the preview check is live | Scratch-copy transcript |
| **TV-15** | No false automated claim | The record does not claim a CI run, test suite, coverage or scanner result that does not exist | Record review |
| **TV-16** | Evidence reproducibility | Every claimed command is documented exactly enough for the project lead to re-run it | Command list |

---

## 7. User Acceptance Verification

| ID | Real-world check | Pass condition |
|---|---|---|
| **UA-01** | Founder diff read-through | The founder can confirm from the diff alone that no pixel, string or interaction changed, and approves under `[FOUNDER]` |
| **UA-02** | Architect fidelity review | The architect confirms the four corrections match the approved plan, that no fifth change exists, and that no suppression was used |
| **UA-03** | Project lead verification | The project lead re-runs `pnpm typecheck` and `pnpm build` and obtains green results |
| **UA-04** | Preview sanity | The running preview (`pnpm dev`) renders the dashboard, an admin module and the auth flow unchanged, including the forgot-password navigation |
| **UA-05** | No-surprise check | `git status` shows only the expected source files changed; no protected file, dependency or config moved |
| **UA-06** | Record accuracy | The record states the true location of the diff, the true verification status, and the outstanding reviews - with no overclaim |
| **UA-07** | Handoff clarity | `EP-00-001` T3 and `EP-00-002` can proceed with no ambiguity about what `012` delivered |

---

## 8. Final Approval Checklist

A single unchecked item below blocks approval, unless it is recorded as an approved exception in §9.

- [ ] **FA-01** All Functional checks F-01-F-15 pass.
- [ ] **FA-02** All Technical checks A-01-A-12 pass.
- [ ] **FA-03** All Data checks D-01-D-08 pass.
- [ ] **FA-04** All Security checks SEC-01-SEC-10 pass.
- [ ] **FA-05** All Performance checks P-01-P-06 pass.
- [ ] **FA-06** All Testing checks TV-01-TV-16 pass, including the seeded failure.
- [ ] **FA-07** All User Acceptance checks UA-01-UA-07 pass.
- [ ] **FA-08** `pnpm typecheck` exits 0 with empty output on the pinned toolchain, and the transcript is retained.
- [ ] **FA-09** All 47 original errors are accounted for by the four approved corrections; none is unexplained.
- [ ] **FA-10** No `@ts-ignore`, `@ts-expect-error`, `@ts-nocheck`, `any` widening, `skipLibCheck` change or `tsconfig` exclusion exists.
- [ ] **FA-11** The icon contract uses `lucide-react`'s `LucideIcon` at all eight sites; no local type duplicate exists.
- [ ] **FA-12** `TITLES` contains both missing keys with `""`; `AdminModuleRecord` and its `fields` contract are unchanged.
- [ ] **FA-13** `resolveUserConfig` uses a named union; no `any` and no runtime behaviour change.
- [ ] **FA-14** The diff is annotation-only plus two `""` entries; no visual, copy, layout, token or behaviour change.
- [ ] **FA-15** `pnpm build` exits 0 and the preview still builds.
- [ ] **FA-16** `package.json`, `pnpm-lock.yaml`, `tsconfig.json`, `.mise.toml`, `pnpm-workspace.yaml` and `documents/Context/*` are unchanged.
- [ ] **FA-17** The seeded-regression and failure-scenario runs demonstrate the gates can still fail.
- [ ] **FA-18** The record states where the diff actually lives and cites the review command; no nonexistent standalone diff is claimed.
- [ ] **FA-19** Founder approval under `[FOUNDER]` is recorded; architect review per `QUA-29`/`QUA-31` is recorded; no agent self-approval.
- [ ] **FA-20** Rollback is recorded and executable; no data, schema, lockfile or dependency is involved.
- [ ] **FA-21** No secret, credential, token-bearing URL or personal data appears in any artefact.
- [ ] **FA-22** The task's follow-up is registered against `EP-00-010` under `QUA-38`, without amending the approved phase document.
- [ ] **FA-23** `EX-14` and `EX-01` are not claimed as closed; they remain open register rows.
- [ ] **FA-24** The project lead has signed the approval record in §9.

### Mandatory stop conditions - do not approve if any is true

- `pnpm typecheck` does not exit 0, or exits 0 only because something was suppressed, widened or excluded.
- Any of the 47 errors is unaccounted for, or the count changed for a reason other than the four corrections.
- A visual, copy, layout or behavioural change exists beyond the two empty `TITLES` entries.
- `pnpm build` fails, or the Figma wrapper's behaviour was altered.
- Any protected file, dependency, lockfile or type configuration changed.
- The record claims a standalone review diff, CI run, test suite or approval that does not exist.
- Approval is asserted by the author or an agent rather than an independent reviewer.
- A secret, credential or token-bearing URL is present in any artefact.

---

## 9. Approval Record

| Field | Value |
|---|---|
| **Project lead** | Prince Abidemi Oluwadamilare |
| **Decision** | Approved, with the recorded `DEV-001` review gap |
| **Conditions / notes** | Typecheck exit 0 with no suppression; build exit 0; 15/15 fact verification; seeded regression reproduced 18 errors. No architect review is claimed; `QUA-29`/`QUA-31` are covered only by the time-boxed deviation `DEV-001`. The four corrections live inside root commit `8029466`, so the review artefact is `git show 8029466 -- src/app/App.tsx vite.figma.config.ts`. |
| **Date** | 2026-11-06 |
| **Next action** | Proceed to `EP-00-002`; settle or re-deviate the second reviewer before EP-01 auth/capability/migration work. |

---

This DoD is specific to `EP-00-012`. It verifies the typecheck remediation, the integrity of the visual authority, and the evidence supporting phase criterion `C4`/`C12` - nothing from `EP-00-001`'s commit work, `EP-00-002` onward, or any later phase.
