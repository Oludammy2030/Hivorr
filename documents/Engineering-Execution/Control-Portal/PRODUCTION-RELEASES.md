# Control Portal — Production Release Record

| Field | Value |
|---|---|
| **Document** | `documents/Engineering-Execution/Control-Portal/PRODUCTION-RELEASES.md` |
| **Date** | 15 November 2026 |
| **Purpose** | The `DEP-23` record for every production release, and where a `DEP-14` single-reviewer exception is signed |
| **Status** | **No release recorded.** The template is ready; the first entry is written at the Phase 4 rehearsal |

> One entry per release. `DEP-15` applies: an entry authorises that release and no other.

---

## 1. What every entry must contain

`DEP-23` requires the approval, the time, the artifact digest and the outcome. An entry without any
one of those is not a release record.

| Field | Source |
|---|---|
| Release SHA and artifact digest | `deploy-production.yml` inputs and the release manifest |
| Staging verification | The merge commit's CI, Fly and staging-gate runs |
| Reviewer | The named `DEP-14` reviewer, **or** the signed exception in §3 |
| Approval time | UTC, the moment the workflow was dispatched |
| Migrations applied | The migration list, with `migrations:verify` output |
| Rehearsed rollback | Date of the `DEP-24` rehearsal and the digest it restored |
| Outcome | Deployed, rolled back, or aborted — with the reason |

## 2. Entry template

```markdown
### Release <sha8> — <YYYY-MM-DD HH:MM UTC>

| Field | Value |
|---|---|
| Artifact digest | sha256:<digest> |
| Staging verification | CI <run id>; Fly <release>; gate <run id> |
| Reviewer | <name>, independent of the deployer |
| Approved at | <UTC timestamp> |
| Migrations | <n> applied; history verified |
| Rollback rehearsal | <date>, restored <digest> |
| Open findings at release | <list, or "none"> |
| Outcome | <deployed / rolled back / aborted> — <reason> |
```

## 3. `DEP-14` single-reviewer exception

`DEP-14` requires a named reviewer who is not the deployer and has no ability to affect the release.
Where no such person exists, a release may proceed only with this exception signed by the founder and
recorded **in the release entry itself**. The exception is a risk acceptance. It is **not** compliance,
it does not amend `DEP-14`, and it may not be cited as satisfying it.

```markdown
#### DEP-14 exception — release <sha8>

- **Rule:** DEP-14 — a named reviewer, not the deployer, with no ability to affect the release.
- **Status: NOT MET.** No second qualified reviewer exists. The deployer is the only reviewer.
- **Compensating controls relied on:**
  - build-once promotion: the artifact verified on staging is the artifact released, by digest;
  - CI on the exact commit: typecheck, lint, format, migrations, eleven database suites, bundles,
    OpenAPI, secret and dependency scan;
  - independent review passes recorded per package (`REVIEW-BATCH-A/B/C.md`) with signed statuses;
  - founder-only dispatch, the confirmation phrase, release-candidate issue check and main ancestry;
  - smoke against the promoted host with the expected SHA;
  - rollback rehearsed and recorded before this entry.
- **Residual risk:** a defect that only a second reader would catch can reach production, and the
  deployer is the sole judge of readiness. This risk is accepted, not mitigated.
- **Accepted by:** <name>, founder — <date and time, UTC>
- **Expires:** at the next release (`DEP-15`), or 90 days from acceptance, whichever is sooner.
  Re-acceptance is required; a previous exception never carries forward.
```

Two conditions make the exception void, and both are checked before it is signed:

1. a second qualified person has become available — then appoint them and delete the exception;
2. any High or Medium review finding is open against a package this release changes — then the
   exception cannot cover it, and the release waits.

## 4. What the exception does not cover

- **Migration review.** `DEP-18` requires migrations to be read as SQL by someone other than the
  author. The release entry names who read them; if that is the founder, the exception states it.
- **Financial-control or data-protection scope.** If real customer money or identity data is in
  production, an accountant or adviser should hold the seat for that scope rather than an exception
  being reused.
- **Disaster recovery.** A restore drill is evidence, not an approval, and is never waived by an
  exception.

## 5. Nothing recorded yet

There is no release entry because no production release has happened. Staging is the verification
environment, and `STAGING-VERIFICATION-CHECKLIST.md` is how it is exercised.
