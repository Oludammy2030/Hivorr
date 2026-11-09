# Legacy Flutter Cutover Runbook

**Status:** **Immediate detach and decommission complete.** The web CNAME records for `hivorr.com`
and `staging.hivorr.com` were deleted, the two Flutter Pages custom domains were removed, and the
two Flutter Pages projects were deleted. Both hostnames and both `*.pages.dev` subdomains are
unavailable. No mail or ownership record was changed. No Flutter rollback target remains.
**Selected path:** immediate detach. `hivorr.com` and `staging.hivorr.com` will be disconnected from
the Flutter origin and will be unavailable until the React production deployment is ready. No
maintenance page is being deployed under this decision.
**Scope:** Retire the legacy Flutter applications currently serving `hivorr.com` and
`staging.hivorr.com`, detach their custom domains, and preserve the old deployment as a rollback
target.
**Owner:** Founder. Execution requires Cloudflare access; an AI agent must not perform a step without
explicit approval and the relevant access.

---

## 1. Verified starting position — 7 November 2026

| Item | Observation |
|---|---|
| `hivorr.com` | Serves a legacy Flutter web build through Cloudflare; HTTP 200 |
| `staging.hivorr.com` | Serves the same legacy Flutter build through Cloudflare; HTTP 200 |
| `control.hivorr.com` | No DNS record |
| `staff.hivorr.com` | No DNS record |
| `partner.hivorr.com` | No DNS record |
| `control-staging.hivorr.com` | No DNS record |
| `staff-staging.hivorr.com` | No DNS record |
| `partner-staging.hivorr.com` | No DNS record |
| Live security headers | No HSTS, CSP, frame protection, or permissions policy observed |
| `staging.hivorr.com` indexing | Currently indexable; must become `Disallow: /` and `noindex` |
| Repository | Contains the React prototype only; no API, database, or portal bundles yet |

The Flutter hosting project, its origin, and its deployment pipeline have not been identified from
this workstation. The first task is to identify them before any change.

---

## 2. Principles

1. **Staged, not abrupt.** Flutter keeps serving until the React replacement is deployed and verified.
2. **Reversible until decommissioned.** The legacy deployment and its custom domains remain a
   rollback target for a recorded window.
3. **Do not delete DNS records to "disconnect".** Repoint or detach custom domains; preserve the
   records and the old origin until the rollback window closes.
4. **No production data in staging.** Staging uses synthetic seeds.
5. **Founder approval per production action.** The cutover is a production change.
6. **No agent performs an external step without access and approval.** No credentials in chat, logs,
   or commits.

---

## 3. Roles

| Role | Responsibility |
|---|---|
| Founder | Approves each production step and the final decommission |
| Engineer / agent | Prepares artifacts, runbook, checks, and evidence; executes only with access |
| Reviewer | Confirms the staging evidence and the rollback position |

---

## 4. Preconditions

Do not begin Phase 4 until all are true:

- [ ] The React staging ecosystem is deployed: `staging.hivorr.com`,
      `control-staging.hivorr.com`, `staff-staging.hivorr.com`, `partner-staging.hivorr.com`.
- [ ] Staging smoke, cross-portal E2E, header, `noindex`, and session-isolation tests pass.
- [ ] The production React deployment is reachable on its platform URL and passes smoke tests before
      any hostname switch.
- [ ] The release is recorded with digest/manifest and a rollback target.
- [ ] Cloudflare access is available and scoped to DNS, Pages/Workers, and Access.
- [ ] The legacy Flutter project and deployment are identified and preserved.
- [ ] The rollback window is agreed (recommended: 14 days).
- [ ] TTL on the affected DNS records is lowered to 300 seconds at least 24 hours before cutover.
- [ ] The founder has approved the cutover window in writing.

---

## 5. Phase 0 — Inventory and preserve

1. Identify whether the Flutter app is served by:
   - a Cloudflare Pages project;
   - a Cloudflare Worker route;
   - an external origin behind Cloudflare;
   - another host.
2. Record the project name, production branch/deployment, custom domains, and current deployment ID.
3. Export the DNS records for every name in §1, including proxied status and TTL.
4. Record the certificate type and any Cloudflare Access policies.
5. Tag or archive the Flutter source and build; record the exact version now serving.
6. Store the evidence in `documents/Engineering-Execution/evidence/flutter-cutover/` with no
   credentials.

**Exit:** a named legacy target, a recorded rollback deployment, and a DNS snapshot.

---

## 6. Phase 1 — Freeze the legacy deployment

1. Freeze the Flutter pipeline so no new legacy deployment replaces the rollback target.
2. Do not delete the project, build, custom domain, or DNS record.
3. Record the freeze in the cutover evidence.

---

## 7. Phase 2 — Deploy and verify the React staging ecosystem

1. Deploy all four staging portals and the staging API/worker from the same release manifest.
2. Apply migrations to the staging database.
3. Run:
   - smoke tests on all four staging hosts;
   - cross-portal E2E scenarios from `ARCHITECTURE.md` §11.8;
   - session audience and environment rejection tests;
   - header tests: HSTS, CSP, frame protection, permissions policy;
   - `noindex` and `robots.txt` checks on every staging host;
   - visual regression at 375 / 768 / 1280 px.
4. Record the staging verification evidence.

**Exit:** `ARCHITECTURE.md` §11.7 is satisfied. No production change yet.

---

## 8. Phase 3 — Prepare production

1. Provision the four production portals, API, worker, database, R2 buckets, secrets, and Access
   policies with production-only credentials.
2. Deploy the approved production artifacts to their platform URLs.
3. Run smoke tests against the platform URLs, not the public hostnames.
4. Confirm:
   - production cannot reach staging resources;
   - staging cannot reach production resources;
   - `control.hivorr.com` and `staff.hivorr.com` have Access policies;
   - production sessions are issued by the production issuer.
5. Record the production deployment and rollback manifest.

**Exit:** the new production origin is verified and ready to receive traffic.

---

## 9. Phase 4 — Cutover

Perform one hostname group at a time, with verification between groups.

### 9.1 Main production

1. Attach `hivorr.com` (and `www.hivorr.com` if used) to the React Cloudflare Pages project.
2. Keep the legacy custom domain intact until the new one is verified.
3. Verify:
   - HTTP 200 and the React build;
   - TLS certificate covers the host;
   - HSTS, CSP, frame protection, permissions policy;
   - sign-in, session, activity switcher, and a read-only marketplace page;
   - `/api/*` reaches the production API, not staging.
4. If any check fails, execute §11 rollback.

### 9.2 Control and staff

1. Attach `control.hivorr.com` and `staff.hivorr.com` to their React projects.
2. Confirm Cloudflare Access challenges unauthenticated requests.
3. Confirm backend authentication, MFA, capability checks, and `noindex`.

### 9.3 Partner

1. Attach `partner.hivorr.com` to the React project.
2. Confirm partner sign-in, organisation scoping, referral/commission read models, and `noindex`.

### 9.4 Staging

1. Attach `staging.hivorr.com`, `control-staging.hivorr.com`, `staff-staging.hivorr.com`, and
   `partner-staging.hivorr.com` to the staging projects.
2. Confirm `noindex` and `Disallow: /` on all four.
3. Confirm no staging request reaches production.

**Do not delete the legacy custom domains or DNS records in this phase.**

### 9.5 Immediate detach — selected path

The founder selected immediate detach on 7 November 2026. This path does **not** wait for the React
production deployment and does **not** deploy a maintenance page. The two hostnames will be
unavailable until React is ready.

Execute only with Cloudflare access and founder confirmation:

1. Record the current DNS records, custom domains, and Flutter deployment ID.
2. Remove `hivorr.com` and `www.hivorr.com` from the Flutter Pages/Worker custom-domain list.
3. Remove `staging.hivorr.com` from the Flutter Pages/Worker custom-domain list.
4. Remove or park only the web-serving DNS records (`A`, `AAAA`, or `CNAME`) for `hivorr.com`,
   `www.hivorr.com`, and `staging.hivorr.com`.
5. **Do not remove `MX`, `TXT`, SPF, DKIM, DMARC, or verification records.** Mail and domain
   ownership must remain intact.
6. Verify that both hostnames no longer serve the Flutter application. A DNS failure, an empty
   response, or a Cloudflare "no origin" response is the expected outcome of this chosen path.
7. Keep the Flutter project, build, and custom-domain configuration documented as the rollback
   position. Do not delete the Flutter project yet.
8. Record the detach time, the operator, the DNS changes, and the verification output.

**Rollback:** restore the recorded DNS records and reattach the custom domains to the preserved
Flutter project. This restores the old application, not the new backend.

**Consequence:** there is no product at `hivorr.com` or `staging.hivorr.com` after this step. The new
Supabase projects are unaffected; they are backend services, not web hosts.

---

## 10. Phase 5 — Post-cutover verification

- [ ] All eight hosts serve the intended application.
- [ ] All eight report the same release SHA where applicable.
- [ ] TLS, HSTS, CSP, frame protection, and permissions policy are present.
- [ ] Privileged and staging hosts are `noindex`.
- [ ] Sign-in works on all four portals.
- [ ] A wrong-audience session is rejected.
- [ ] A staging session is rejected by production.
- [ ] Control/staff Access challenges work.
- [ ] Cross-portal verification, complaint, and referral scenarios pass in production with synthetic
      accounts, then are removed.
- [ ] Error rate and queue depth are monitored for 30 minutes.
- [ ] The deployment record contains the manifest, digests, approver, timestamp, and rollback target.

---

## 11. Rollback

Trigger rollback if any of the following occurs:

- the new host returns an error or a blank shell;
- sign-in or session validation fails;
- `/api/*` reaches the wrong environment;
- privileged hosts are reachable without Access/authentication;
- a security header is missing on a host that should have it;
- a cross-portal workflow corrupts state.

Rollback steps:

1. Reattach the hostname/custom domain to the preserved Flutter deployment.
2. Restore the DNS record from the Phase 0 snapshot if it was changed.
3. Confirm the legacy host serves the recorded version.
4. Record the rollback, the reason, and the failed release.
5. Do not delete the React deployment; investigate before the next attempt.

The rollback is complete only when the host is verified and the founder has acknowledged it.

---

## 12. Phase 6 — Decommission Flutter

Only after the rollback window closes and the founder approves in writing:

1. Remove the legacy custom domains from the Flutter host.
2. Remove the legacy Flutter project or archive it according to the retention decision.
3. Remove superseded DNS records only if they are not needed by the React deployment.
4. Revoke legacy credentials and integrations.
5. Record the decommission and update `ARCHITECTURE.md` §4.8 from "transitional" to "retired".
6. Close the cutover evidence pack.

Decommissioning is irreversible. It is a separate approval from the cutover.

---

## 13. Do not do

- Do not delete `hivorr.com` or `staging.hivorr.com` DNS records to "disconnect" Flutter.
- Do not point production at staging.
- Do not reuse a staging secret, bucket, queue, or database in production.
- Do not cut over while the React production origin is unverified.
- Do not remove the Flutter rollback target during the rollback window.
- Do not perform a step without Cloudflare access and founder approval.
- Do not record a credential, token, or connection string in this runbook or its evidence.

---

## 14. Current status

| Phase | Status |
|---|---|
| 0 - Inventory and preserve | **Complete** — Pages projects and DNS records identified and backed up |
| 1 - Freeze | Not started |
| 2 - React staging | **Blocked** — no staging ecosystem exists |
| 3 - Production preparation | **Blocked** |
| 4 - Staged cutover | **Superseded by immediate detach** |
| 4a - Immediate detach | **Complete 7 November 2026** — DNS records deleted, Pages custom domains removed |
| 5 - Verification | **Complete** — both hostnames and both `*.pages.dev` subdomains unavailable |
| 6 - Decommission | **Complete 7 November 2026** — Flutter Pages projects deleted; no rollback target remains |
