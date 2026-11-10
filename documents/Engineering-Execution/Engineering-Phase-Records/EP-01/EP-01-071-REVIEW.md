# EP-01 — Phase-Level Security and Quality Review

**Task:** `EP-01-071`
**Date:** 2026-11-10
**Reviewer:** AI implementation agent (not independent)
**Scope:** EP-01 authentication, authorisation, RLS, audit immutability, secret handling and test
adequacy against the approved standards.
**Evidence base:** `EP-01-EVIDENCE-PACK.md`, the execution records, the migrations, the identity and
platform services, and the local gate runs.

**Verdict: NOT READY FOR CLOSURE.** No critical finding was found. **Three high findings remain
unmitigated.** The phase must not be signed at `G5` until each is remediated or the founder records an
explicit, scoped acceptance.

**Updates 2026-11-10:**

- H-01 (`F-29`) accepted — distinct CI-only `MIGRATOR_DATABASE_URL`, never injected into Fly;
  `hivorr_migrator` stays `nologin`.
- H-05 (`F-04`) resolved by founder ruling — **no Doppler**. GitHub environment secrets + `fly secrets`
  are the provider, with the recorded compensating controls; standards §16 #8 requires a formal revision.

---

## 1. Method and limits

- Document and code review of the identity, capability, audit, logging, rate-limit and migration paths.
- Artifact review of the evidence pack, gate outputs, visual approval and staging probe.
- Test inventory and local execution.
- **Not performed:** independent penetration test, live database assertions (no local PostgreSQL),
  live staging E2E (staging is stale), CI observation (no push), coverage measurement, latency
  measurement.
- The reviewer is the implementing agent. `DEV-003` remains the recorded single-reviewer deviation;
  this review is not an independent second opinion.

---

## 2. Checklist

| Area | Rule / control | Verdict | Evidence |
|---|---|---|---|
| Authentication | Argon2id password hashing | Pass | `hashPassword`/`verifyPassword`; dummy hash for unknown users |
| Authentication | Opaque session tokens stored as hashes | Pass | `randomBytes(32)`, SHA-256 storage; no signed token |
| Authentication | `__Host-` session cookie per audience | Pass | `session-policy.ts`; `session.ts` tests |
| Authentication | Refresh cookie scoped and `SameSite=Strict` | Pass | `session-policy.ts` |
| Authentication | Rotation and reuse detection | Partial | Code + tests; CI unobserved |
| Authentication | MFA challenge, encrypted TOTP secret | Pass | AES-256-GCM, per-environment key, challenge TTL |
| Authentication | Credential lockout and rate limiting | Partial | Configurable lockout; per-process limits (`F-41`) |
| Authorisation | Capability computed server-side | Pass | `computeCapabilities`; no client authority |
| Authorisation | Deny path labelled and stable `FORBIDDEN` | Pass | `enforcement.test.ts` |
| Authorisation | Unknown capability denies | Pass | Registry + enforcement tests |
| Authorisation | Check and write share a transaction | Partial | Enforced in service; DB-backed proof only CI |
| RLS | Every EP-01 table has RLS and one policy per operation | Partial | 15 `FORCE RLS` tables; `rls-policy.test.ts`; DB run unobserved |
| RLS | Fails closed without context | Partial | Policy pattern + test; DB run unobserved |
| Audit | Append-only; update/delete rejected | Pass | Trigger `reject_append_only_mutation`; DB assertion |
| Audit | Read scoped and audited | Partial | Service + tests; live unobserved |
| Secrets | No secret in repo, log, error, URL or client | Pass | Secret scan clean (329 files); config never echoes values |
| Secrets | Recorded provider and rotation | **Resolved** | Founder ruled no Doppler; GitHub + Fly with compensating controls; manual rotation residual |
| SQL | Parameterised queries only | Pass | Reviewed services; no string-built SQL from input |
| Input | Strict validation, stable error codes | Pass | Zod schemas; `request-pipeline.test.ts` |
| Errors | No stack, query string or secret in a response/log | Pass | API filter; correlation only |
| Logging | Structured and PII-redacted | Partial | Key-based redaction; `F-40` free text |
| Transport | TLS and HSTS at the edge | Partial | Hosts verified; no header test |
| Supply chain | Exact pins, secret/dependency scan | Partial | Exact versions; `security:secrets` clean; `security:deps` CI only |
| Test adequacy | Unit/contract/gate suites | Partial | 278 pass, 7 skipped; 7 suites fail to load on Windows |
| Test adequacy | Coverage measured | **Unmet** | No coverage report |
| Performance | Route JS budget | Pass | 121.4 KB / 71.0 KB gzip, under 200 KB |
| Performance | API read/write latency | **Unmet** | Not measured |
| Deployment | Staging runs the candidate digest | **High finding** | `F-49` stale image |
| Deployment | Slice deployed and E2E green | **High finding** | `F-50` manual Pages; E2E fails |
| Migrations | One CI-only applying role | **Accepted residual** | `MIGRATOR_DATABASE_URL` only in the migration step; `hivorr_migrator` remains `nologin` (`F-29` acceptance) |
| Migrations | `db diff` clean | **High finding** | `F-28` no baseline |
| Review | Independent second reviewer | Deviation | `DEV-003` recorded |

---

## 3. Findings

### Critical

None found in the reviewed code paths.

### High

| ID | Finding | Existing control | Required action |
|---|---|---|---|
| H-01 | `F-29` — migrations run with the deployment credential; `hivorr_migrator` is `nologin`. A single CI-only applying role is not proven. | **Accepted 2026-11-10.** The migration job uses a distinct `MIGRATOR_DATABASE_URL`, never set on Fly; the role stays `nologin`. Residual: the credential is broader than a login migrator role. | Provision a login migrator role before production (follow-up). |
| H-02 | `F-49` — the deployed staging API predates `/v1/session` and `/v1/activities`. | None; the smoke catches it. | Deploy the current digest; rerun smoke. |
| H-03 | `F-50` — the slice bundle is not deployed; Pages rollout is manual. | CI produces a digest-verified artifact. | Publish the four bundles with `slice.html`; rerun E2E. |
| H-04 | No CI run has been observed for the phase. All “green” evidence is local, and the work is uncommitted. | Local gates and seeded proofs. | Push; obtain a green CI run. |
| H-05 | `F-04` — the recorded secret provider is Doppler; the runtime uses GitHub environment secrets and Fly secrets. Rotation and scoped service tokens are weaker than recorded. | **Resolved 2026-11-10.** Founder ruled no Doppler; GitHub + Fly are the provider, with private repo, environment scoping, founder-only admin and deploy-time injection. Residual: manual rotation and GitHub Free reviewer limits. | Update standards §16 #8; record the residual at `G4`. |

### Medium

| ID | Finding | Action |
|---|---|---|
| M-01 | `F-28` — no committed schema baseline; `db diff` cannot be clean. | Generate and commit a baseline from a migrated database. |
| M-02 | `F-08` — `DATABASE_SSL_CA` unset; the pooler certificate is not verified. | Set the CA and verify with `rejectUnauthorized: true`. |
| M-03 | `F-40` — key-based redaction misses PII in free-text provider errors. | Add a scrubber or accept the residual. |
| M-04 | `F-41` — rate limits are per process; horizontal scaling weakens them. | Shared store before multi-instance. |
| M-05 | Coverage is not measured. | Add a coverage report and threshold. |
| M-06 | API read/write latency is not measured. | Measure on staging against the budget. |
| M-07 | No automated test for CSP/HSTS/frame protection, though `_headers` exists. | Add a header assertion to smoke. |
| M-08 | Authenticated E2E is optional and has no test identity. | Provision a staging test identity. |

### Low

| ID | Finding | Action |
|---|---|---|
| L-01 | `F-51` — the registry image digest is not captured; `RELEASE_DIGEST` has no injector. | Verify flyctl digest capture. |
| L-02 | `F-43` — the visual baseline covers entry screens only. | Extend as screens are extracted. |
| L-03 | `F-45` — `C.gray` uses `--muted-foreground`; no `--hivorr-gray`. | Add on the next theme touch. |
| L-04 | `DEV-003` — single-reviewer deviation. | Recorded; ends at `G5` or reviewer appointment. |

---

## 4. Deviations

| ID | Deviation | Status |
|---|---|---|
| `DEV-003` | Single reviewer for EP-01 sensitive changes | **Accepted**, ends at `G5` or appointment |
| `F-04` | Secret provider as-built differs from the recorded choice | **Open high** |
| `F-48` | Registration omits phone/country | **Accepted** by founder 2026-11-10 |
| `F-03` | Custom boundary linter, migration runner and outbox replace recorded selections | **Closed** 2026-11-09 |

---

## 5. Positive controls confirmed

- Argon2id with a dummy hash for unknown accounts (no timing oracle).
- Opaque session tokens, hashed at rest, `__Host-` cookies, audience binding.
- Server-side capability computation; client state is presentation-only.
- RLS forced on identity/profile tables, with a deny-without-context test.
- Append-only audit trigger; no update/delete path.
- Strict config validation that never echoes a supplied secret; secret scan clean.
- Structure-only logs, correlation IDs, stable error bodies.
- Exact dependency pins; seeded-failure proofs for every gate category.
- Founder-approved visual baseline; sign-in pixel parity at three widths.

---

## 6. Test adequacy

| Measure | Result |
|---|---|
| Local suite | 278 pass, 7 skipped, 7 suites cannot load argon2 (`F-10`) |
| Seeded gate proofs | 23/23 |
| Contract/design/visual parity | Pass |
| DB-backed RLS/role/audit proofs | Not run locally; CI unobserved |
| Coverage | **Not measured** |
| Authenticated staging E2E | **Not run** |
| Independent security test | **Not performed** |

The test inventory is broad, but the absence of a CI run and of DB-backed evidence means the phase
cannot claim “all blocking gates pass”.

---

## 7. Conclusion

**The phase is not ready for closure.**

- No critical finding.
- **Three high findings remain:** `F-49`, `F-50`, H-04 (no CI run). H-01 (`F-29`) is an accepted
  residual; H-05 (`F-04`) is resolved by the founder's no-Doppler ruling.
- Eight medium and four low findings are recorded.
- The unmet completion criteria `C4` and `C12` are consistent with these findings.

### Conditions for `072`

1. Deploy the current digest and the slice; smoke and E2E green (`H-02`, `H-03`).
2. Push and obtain a green CI run (`H-04`).
3. Commit a schema baseline (`M-01`).
4. At minimum, measure coverage and API latency, or record them as accepted gaps (`M-05`, `M-06`).

`072` must not be signed until those are met or explicitly accepted by the founder with the residual
risk stated.

---

## 8. Sign-off

| Role | Name | Decision | Date |
|---|---|---|---|
| Reviewer (AI agent) | Implementation agent | Review complete; closure blocked | 2026-11-10 |
| Architect | — | Pending | — |
| Founder | — | Pending | — |
