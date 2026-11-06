# Work Package Record — EP-00-005
## CI provider, repository hosting and environment placeholders

| Field | Value |
|---|---|
| **ID** | `EP-00-005` |
| **Phase** | `EP-00` — Execution Readiness |
| **Objective** | Record the host and CI provider decided under #18, create the private remote, prove the pushed tree matches the reviewed tree, and enable the native security features the later items depend on. |
| **Class** | `[FOUNDER]` — repository hosting and CI provider (decision #18, `ARCHITECTURE.md` §16.4 #25). |
| **Status** | `In review` — remote created, tree pushed and verified; scanning partially enabled; one plan conflict raised in § Findings. |
| **Origin** | `EP-00-000` decision #18: GitHub and GitHub Actions, private repository, protected `main`, native scanning. `EP-00` §9 places `EP-00-005` before `EP-00-006`. |

### Scope — in

1. Record the host, repository URL, visibility and CI service.
2. Create the remote and push the reviewed tree with its tag.
3. Prove remote/local parity for `main` and `v0.0.1-bootstrap`.
4. Enable the native security features available on the account's plan; record the ones that are not.
5. Record the deferrals: branch protection (`EP-00-007`), pipeline (`EP-00-006`), environment placeholders.

### Scope — out

Branch protection, required status checks and review enforcement (`EP-00-007`); any workflow file (`EP-00-006`); secret and dependency scanning gates as CI stages (`EP-00-008`); any dependency change; any deployment; any secret, token or credential stored in the repository or in Actions; any `staging`/`production` resource that would receive traffic.

### Reuse check

Inspected: `EP-00` §7.2 and §8.1 (`R5`, `R7`, `R8`, `R9`, `R10`), `EP-00-000` decision #18 and `DEV-001`, `ARCHITECTURE.md` §12.1 and §16.4 #25, the pre-push secret scan performed under `EP-00-001`/`012`, `.gitignore` and `.gitattributes` (already correct), and the existing git credential helper. No new repository, workflow, configuration file or tool was created to perform this item. The remote is the only new external asset.

### Dependencies

`EP-00-000` (decision #18, `DEV-001`); a GitHub account owning the target namespace; a credential already present in the workstation credential store. `EP-00-001`'s commit and tag; `EP-00-012` closed, so the pushed tree typechecks.

### Test plan and result

| # | Test | Result |
|---|---|---|
| 1 | Pre-push hygiene: no `.env`, no `*.pem`/`*.key`, no secret patterns in tracked content, no blob over 1 MB | **Pass** — 123 tracked files, ~996 KiB, scan clean |
| 2 | Push `main` and the annotated tag | **Pass** — `main -> main`, `v0.0.1-bootstrap` |
| 3 | Remote/local parity for `main` | **Pass** — both `f0edfe3` |
| 4 | Remote/local parity for the tag, including the peeled commit | **Pass** — tag object `e6fcd38`, peeled `8029466` |
| 5 | Working tree clean and upstream tracking set | **Pass** — `## main...origin/main`, 0 ahead / 0 behind |
| 6 | Repository visibility is private (decision #18) | **Pass after correction** — created public, corrected to private; see § Incident |
| 7 | Native scanning features enabled | **Partial** — Dependabot alerts and security updates enabled; secret scanning unavailable on a private repository without GitHub Secret Protection |
| 8 | Branch protection | **Not applicable** — deferred to `EP-00-007` by design |

### Evidence

- Remote: `https://github.com/Oludammy2030/Hivorr.git`
- Push transcript: `* [new branch] main -> main`, `* [new tag] v0.0.1-bootstrap -> v0.0.1-bootstrap`
- `git ls-remote origin` — `refs/heads/main f0edfe3…`, `refs/tags/v0.0.1-bootstrap e6fcd38…`, peeled `8029466…`
- Repository metadata — `created_at 2026-11-06T15:29:22Z`, `pushed_at 2026-11-06T15:30:39Z`, `visibility private` (verified 2026-11-06T15:36:27Z), 0 forks, 0 stars, 0 watchers
- API status check — Dependabot alerts `enabled`, security updates `enabled=true`, secret scanning `HTTP 404 - Secret scanning is disabled on this repository`, branch protection `HTTP 403`
- Credential handling — the stored credential was read in memory by the OS credential helper and was never printed, logged, committed or written to disk

### Incident — repository was created public

The repository was created with `public` visibility, contrary to `EP-00-000` decision #18. It was detected on the first authenticated API read and corrected to `private` within the same session.

- **Exposure window:** from `2026-11-06T15:29:22Z` until the correction, verified private at `2026-11-06T15:36:27Z` — under ten minutes.
- **Content exposed:** the full tree, including `documents/Business-Roadmap`, `documents/Context/VISION.md`, `ARCHITECTURE.md`, the security standards and `documents/integrations/vfd/*`.
- **Observed interest:** 0 forks, 0 stars, 0 watchers at the time of correction. No clone or traffic data was retained.
- **Residual risk:** search-engine or third-party caching of a repository that was public for minutes cannot be proven absent. Treated as low, recorded rather than dismissed.
- **Control that would have prevented it:** nothing in the current process asserts visibility at creation; `EP-00-007`'s settings export is the right place to verify it permanently.

### Findings — raised for decision, not acted on

**F-05-01 — Secret scanning is not available on this plan.** Push protection and secret scanning are free on public repositories but require GitHub Secret Protection on private ones. They were enabled while the repository was public and are reported as disabled now. The `SEC-54`/`GOV-19` control is therefore **not active**. Options: purchase Secret Protection, keep the repository private and rely on a local pre-push scan until a later decision, or accept a recorded gap with an owner and expiry. This is a `[FOUNDER]` cost decision and has not been made.

**F-05-02 — 30 open Dependabot alerts, including 5 High.** Enabling alerts surfaced advisories in the pinned tree, among them `react-router` (`GHSA-qwww-vcr4-c8h2`, High, runtime, patched 7.18.2), `vite` (High, dev), `source-map-js` (High), `nanoid` (High) and `browserslist` (High).

**F-05-03 — That finding conflicts with the approved plan.** `EP-00` §8.3 and `TEC-17` forbid dependency upgrades in EP-00, while `EP-00-006`/`EP-00-008` require a dependency gate that fails on High/Critical. A red gate on the bootstrap commit is the outcome the phase is written to avoid. The conflict is recorded, **no dependency was changed and no Dependabot pull request was merged**. Resolution requires either a scoped security-remediation package approved as a scope amendment, or a recorded accepted risk with an owner and expiry.

**F-05-04 — Dependabot opened pull request #1** (`react-router` 7.18.2) within a minute of security updates being enabled. It must not be merged under EP-00. Pull requests are proposals, not changes; no branch protection exists to block a merge, which is another reason `EP-00-007` matters.

**F-05-05 — Branch protection read returned `HTTP 403`.** The token can write repository settings (visibility and security were changed) but the protection endpoint refused. Enabling protection in `EP-00-007` may need a token with different permissions. Recorded now so `EP-00-007` does not discover it late.

### Rollback

Delete the remote repository, or make it private again if visibility is ever wrong. No local history, tag, file or configuration changes. `git remote remove origin` removes the local reference. No data, schema, secret or environment is involved. Note that a public window cannot be un-published, only closed.

### Approver

Founder (`[FOUNDER]`) for decision #18 and for F-05-01's cost choice. Architect review of the settings evidence per `QUA-29`; the standing second-reviewer deviation `DEV-001` applies until `EP-00-007`.

### Follow-up

- Resolve F-05-01 (secret scanning) and F-05-02/F-05-03 (dependency advisories) before `EP-00-006` turns the dependency gate into a required check.
- `EP-00-007`: enable protection and export the settings as evidence; verify visibility at the same time.
- `EP-00-010`: index this record, the `git ls-remote` output and the API status output.
- No environment placeholders were created; `staging` and `production` remain definitions only, as `EP-00` requires.

---

### Amendment — 2026-11-06 (finding resolution)

Recorded on the project lead's instruction. Scope, tests and evidence above are unchanged; this section closes two findings and restates one.

**F-05-01 — secret scanning: resolved locally, with an expiry.** Approved option: a local pre-push guard instead of the paid GitHub feature. Added `scripts/secret-scan.mjs` and `.githooks/pre-push`, enabled with `git config core.hooksPath .githooks`.

- **Proven to block:** a non-live fixture (`ghp_` + 36 zeros) staged in the tree caused `git push` to fail with `pre-push: push blocked by the local secret scan`, exit 1. The fixture was removed and never committed.
- **Proven to pass:** with the fixture removed, the scan reports `clean (124 file(s) scanned)` and the push proceeds.
- **Limits, stated plainly:** it matches common credential shapes only, it scans tracked **content**, not history, and a contributor who never enables `core.hooksPath` is unprotected. It is a guard, not a guarantee, and is not equivalent to provider-side scanning.
- **Expiry / owner:** revisit when GitHub Secret Protection or a CI scanning stage is approved — at the latest in `EP-00-008`. Owner: project lead.

**F-05-02 and F-05-03 — dependency advisories: resolved by `EP-00-013`.** A project-lead-approved scope amendment allowed the pinned packages to move to their patched versions within the installed major line. `pnpm audit` went from **54 advisories (1 critical, 27 high)** to **0**, with the bundle hashes unchanged and `typecheck`, `build` and `--frozen-lockfile` all green. See that record for the package table and the Rollup/Vite compatibility finding.

**F-05-04 — Dependabot pull request #1 is superseded.** The remediation used the same or newer patched versions. The pull request should be closed, not merged.

**F-05-05 — branch protection `HTTP 403`** stands unchanged and is still owed to `EP-00-007`.
