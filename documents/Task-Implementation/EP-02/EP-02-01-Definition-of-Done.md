# Definition of Done — EP-02-01: Two-Tier Taxonomy Seed Data & Registry Population

> **Document Type:** Task Definition of Done | **Task ID:** EP-02-01 | **Status:** Completed
> **Reference Plan:** `documents/Task-Implementation/EP-02/EP-02-01-Two-Tier Taxonomy Seed Data & Registry Population.md`

---

## 1. Task Identification

| Attribute | Detail |
|---|---|
| **Task ID** | EP-02-01 |
| **Task Name** | Two-Tier Taxonomy Seed Data & Registry Population |
| **Related Phase** | EP-02 — Trust, Identity & Financial Integrity Engine |
| **Phase Stage** | Stage 1 — Taxonomy & Registry Foundation |
| **Priority** | Critical |
| **Dependencies** | EP-01-06 (industries + professions tables exist with RLS, indexes, and constraints) |
| **Blocks** | EP-02-02 (Taxonomy Management RPCs), EP-02-07 (Client-Side Taxonomy Engine) |
| **Reference Implementation Plan** | `documents/Task-Implementation/EP-02/EP-02-01-Two-Tier Taxonomy Seed Data & Registry Population.md` |

---

## 2. Functional Verification

This task is a server-side database seed data migration. There are no user-facing workflows, UI interactions, or API endpoints. Functional verification confirms the migration produces the correct data state.

### 2.1 Required Functionality

- [ ] **FV-01:** Migration file exists at `supabase/migrations/<YYYYMMDD><HHMMSS>_taxonomy_seed_data.sql` following the established naming convention
- [ ] **FV-02:** Migration executes successfully without errors via `supabase db push` or `supabase db reset`
- [ ] **FV-03:** After migration, `SELECT count(*) FROM industries` returns exactly **8**
- [ ] **FV-04:** After migration, `SELECT count(*) FROM professions` returns exactly **46**
- [ ] **FV-05:** All 8 seeded industries have `is_active = true`
- [ ] **FV-06:** All 46 seeded professions have `is_active = true`
- [ ] **FV-07:** Every seeded industry has a non-null `description`
- [ ] **FV-08:** Every seeded profession has a non-null `description`

### 2.2 Expected Workflows

- [ ] **FV-09:** Migration applies in a single transactional execution (no partial state on success)
- [ ] **FV-10:** Migration is idempotent — re-running produces no errors and no duplicate records
- [ ] **FV-11:** Migration applies cleanly to a fresh database (no prior seed data)
- [ ] **FV-12:** Migration applies cleanly to a database that already contains the same seed data (ON CONFLICT DO NOTHING)

### 2.3 Success Conditions

- [ ] **FV-13:** The seeded taxonomy data is queryable by `anon` role via `SELECT`
- [ ] **FV-14:** The seeded taxonomy data is queryable by `authenticated` role via `SELECT`
- [ ] **FV-15:** The `entity_profession_bind` RPC can successfully bind a seeded profession to an entity

### 2.4 Error Handling Scenarios

- [ ] **FV-16:** If a slug conflict exists (pre-existing record with same slug), the migration skips that record without error (ON CONFLICT DO NOTHING)
- [ ] **FV-17:** If any INSERT fails outside of conflict handling, the entire migration rolls back (transactional safety)

---

## 3. Technical Verification

### 3.1 Architecture Compliance

- [ ] **TV-01:** Migration file is located in `supabase/migrations/` — no other directories modified
- [ ] **TV-02:** No DDL statements (CREATE TABLE, ALTER TABLE, DROP TABLE) exist in the migration — only DML (INSERT)
- [ ] **TV-03:** No RLS policy changes, GRANT statements, or REVOKE statements exist in the migration
- [ ] **TV-04:** No client-side Dart code created — no files added under `lib/`
- [ ] **TV-05:** Migration header comment block documents purpose, EP-02-01 reference, and inherited conventions

### 3.2 Required System Behavior

- [ ] **TV-06:** Industry INSERTs use `ON CONFLICT (slug) DO NOTHING` for idempotency
- [ ] **TV-07:** Profession INSERTs use `ON CONFLICT (slug) DO NOTHING` for idempotency
- [ ] **TV-08:** Profession `industry_id` values are resolved via subselect on `industries.slug` (not hardcoded UUIDs)
- [ ] **TV-09:** No hardcoded UUID values appear anywhere in the migration
- [ ] **TV-10:** `created_by` column is either omitted (defaults to `NULL` in migration context) or explicitly set to `NULL`

### 3.3 Module Integration

- [ ] **TV-11:** Migration does not modify or conflict with any existing migration files (`20260819090001` through `20260821090006`)
- [ ] **TV-12:** Migration ordering is correct — timestamp places it after `20260821090006_entity_profile_legal_name_guard.sql`
- [ ] **TV-13:** Existing `industries_set_updated_at` and `professions_set_updated_at` triggers remain functional on seeded rows

---

## 4. Data Verification

### 4.1 Data Creation — Industries

- [ ] **DV-01:** Exactly 8 industries exist with the following slugs: `legal`, `technology`, `healthcare`, `construction`, `financial-services`, `creative`, `education`, `logistics`
- [ ] **DV-02:** Each industry `name` matches the approved plan: Legal, Technology, Healthcare, Construction, Financial Services, Creative, Education, Logistics
- [ ] **DV-03:** Each industry `description` matches the approved plan verbatim
- [ ] **DV-04:** Industry `sort_order` values are: 10, 20, 30, 40, 50, 60, 70, 80 (increments of 10)
- [ ] **DV-05:** All industry `sort_order` values are non-zero and non-null

### 4.2 Data Creation — Professions

- [ ] **DV-06:** Exactly 46 professions exist across all 8 industries
- [ ] **DV-07:** Profession distribution per industry matches the approved plan:
  - Legal: 5 professions
  - Technology: 8 professions
  - Healthcare: 6 professions
  - Construction: 6 professions
  - Financial Services: 5 professions
  - Creative: 6 professions
  - Education: 5 professions
  - Logistics: 5 professions
- [ ] **DV-08:** All 46 profession slugs match the approved plan exactly
- [ ] **DV-09:** All 46 profession names match the approved plan exactly
- [ ] **DV-10:** All profession `sort_order` values within each industry use increments of 10 starting from 10
- [ ] **DV-11:** All profession `sort_order` values are non-zero and non-null

### 4.3 Data Relationships

- [ ] **DV-12:** Every profession has a valid `industry_id` referencing an existing industry — zero orphaned professions:
  ```sql
  SELECT count(*) FROM professions p
  WHERE NOT EXISTS (SELECT 1 FROM industries i WHERE i.id = p.industry_id);
  -- Expected: 0
  ```
- [ ] **DV-13:** No industry has zero professions (every seeded industry has at least 3 professions)

### 4.4 Data Accuracy

- [ ] **DV-14:** All industry slugs pass the CHECK constraint: `lower(slug) AND slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$' AND char_length(slug) <= 140`
- [ ] **DV-15:** All profession slugs pass the same CHECK constraint
- [ ] **DV-16:** All industry names pass the CHECK constraint: `char_length(btrim(name)) between 1 and 255`
- [ ] **DV-17:** All profession names pass the same CHECK constraint

### 4.5 Data Integrity

- [ ] **DV-18:** Industry slug uniqueness: `SELECT count(DISTINCT slug) FROM industries` = 8
- [ ] **DV-19:** Profession slug uniqueness: `SELECT count(DISTINCT slug) FROM professions` = 46
- [ ] **DV-20:** No duplicate `(industry_id, slug)` combinations in professions
- [ ] **DV-21:** Idempotency confirmed — running migration twice yields identical row counts (8 industries, 46 professions)

---

## 5. Security Verification

### 5.1 Authentication

- [ ] **SV-01:** Migration does not alter any authentication configuration or `auth.*` tables

### 5.2 Authorization & Access Control

- [ ] **SV-02:** No new RLS policies are created by the migration
- [ ] **SV-03:** No existing RLS policies are dropped or modified by the migration
- [ ] **SV-04:** No new GRANT statements are issued by the migration
- [ ] **SV-05:** No REVOKE statements are issued by the migration
- [ ] **SV-06:** `anon` role can SELECT all 8 industries and 46 professions (public read preserved)
- [ ] **SV-07:** `authenticated` role can SELECT all 8 industries and 46 professions (public read preserved)
- [ ] **SV-08:** `authenticated` role cannot INSERT into `industries` (write blocked by RLS)
- [ ] **SV-09:** `authenticated` role cannot INSERT into `professions` (write blocked by RLS)
- [ ] **SV-10:** `authenticated` role cannot UPDATE any seeded industry or profession record
- [ ] **SV-11:** `authenticated` role cannot DELETE any seeded industry or profession record

### 5.3 Sensitive Data Protection

- [ ] **SV-12:** No sensitive data (credentials, keys, tokens, PII) exists in any seed record
- [ ] **SV-13:** Seed data contains only public classification data (names, slugs, descriptions)

---

## 6. Performance Verification

### 6.1 Response Performance

- [ ] **PV-01:** Migration executes in under 5 seconds on a local Supabase instance
- [ ] **PV-02:** Post-migration, `SELECT * FROM industries WHERE is_active = true ORDER BY sort_order` returns 8 rows using the `industries_is_active_sort_idx` index (no sequential scan)
- [ ] **PV-03:** Post-migration, `SELECT * FROM professions WHERE industry_id = $1 AND is_active = true ORDER BY sort_order` uses the `professions_is_active_industry_idx` index

### 6.2 Resource Usage

- [ ] **PV-04:** Migration inserts exactly 54 rows total (8 + 46) — no unexpected row multiplication
- [ ] **PV-05:** No excessive index rebuilds triggered — existing indexes accept incremental inserts normally

### 6.3 System Reliability

- [ ] **PV-06:** No table locks held after migration completes
- [ ] **PV-07:** Existing triggers (`industries_set_updated_at`, `professions_set_updated_at`) fire correctly on all seeded rows

---

## 7. Testing Verification

### 7.1 Automated Testing — pgTAP Seed Verification

- [ ] **TV-01:** Test file exists at `supabase/tests/database/009_taxonomy_seed_verification.sql`
- [ ] **TV-02:** Test file follows the established pgTAP pattern: `begin; set search_path; select plan(N); ... select * from finish(); rollback;`
- [ ] **TV-03:** Test asserts industry count = 8
- [ ] **TV-04:** Test asserts profession count = 46
- [ ] **TV-05:** Test asserts all industries have `is_active = true`
- [ ] **TV-06:** Test asserts all professions have `is_active = true`
- [ ] **TV-07:** Test asserts FK integrity (every profession references a valid industry)
- [ ] **TV-08:** Test asserts slug uniqueness in both tables
- [ ] **TV-09:** Test asserts slug format compliance (regex match)
- [ ] **TV-10:** Test asserts profession distribution (3–8 per industry)
- [ ] **TV-11:** Test asserts no `sort_order` is NULL or 0
- [ ] **TV-12:** Test asserts `anon` role can SELECT seeded data
- [ ] **TV-13:** Test asserts `authenticated` role can SELECT seeded data
- [ ] **TV-14:** Test asserts `authenticated` role cannot INSERT/UPDATE/DELETE seeded data
- [ ] **TV-15:** All pgTAP assertions in `009_taxonomy_seed_verification.sql` pass — zero failures

### 7.2 Regression Testing — Existing pgTAP Suite

- [ ] **TV-16:** `006_taxonomy_integrity.sql` passes all 15 assertions without regression
- [ ] **TV-17:** `008_full_schema_posture_audit.sql` passes all assertions without regression
- [ ] **TV-18:** Full test suite execution via `supabase db test` reports zero failures across all test files

### 7.3 Edge Cases

- [ ] **TV-19:** Idempotency edge case: migration run twice produces identical database state
- [ ] **TV-20:** Slug conflict edge case: pre-existing record with a conflicting slug is preserved (not overwritten)
- [ ] **TV-21:** Empty database edge case: migration applies cleanly to a database with zero existing taxonomy records

### 7.4 Failure Scenarios

- [ ] **TV-22:** If migration is interrupted mid-execution, no partial seed data remains (transaction rollback)
- [ ] **TV-23:** If a profession subselect fails to resolve an industry slug, the migration fails with a clear error (not silent data loss)

### 7.5 Manual Testing

- [ ] **TV-24:** Manual SQL verification query returns expected results:
  ```sql
  SELECT i.slug, i.name, count(p.id) as profession_count
  FROM industries i
  LEFT JOIN professions p ON p.industry_id = i.id
  GROUP BY i.slug, i.name
  ORDER BY i.sort_order;
  ```
  Expected: 8 rows with profession counts matching the approved distribution (5, 8, 6, 6, 5, 6, 5, 5)

---

## 8. User Acceptance Verification

This task has no direct user interface. User acceptance is verified indirectly through data correctness and downstream readiness.

- [ ] **UA-01:** All 8 industry names are recognizable and relevant to the Nigerian professional services market
- [ ] **UA-02:** All 46 profession names are recognizable professional titles in the Nigerian market
- [ ] **UA-03:** All slugs are human-readable and suitable for public SEO URLs (`/p/:profession_slug/:entity_id`)
- [ ] **UA-04:** Industry descriptions accurately convey the scope of each industry category
- [ ] **UA-05:** Profession-to-industry groupings are logically correct (no misclassified professions)
- [ ] **UA-06:** Sort ordering presents industries and professions in a logical, discoverable sequence
- [ ] **UA-07:** The seeded taxonomy is sufficient to unblock EP-02-02 (Taxonomy Management RPCs) and EP-02-07 (Client-Side Taxonomy Engine)

---

## 9. Final Approval Checklist

All conditions below must be satisfied before EP-02-01 can be marked **Completed**.

| # | Condition | Verified By | Pass |
|---|---|---|---|
| 1 | Migration file exists with correct naming convention and timestamp ordering | File inspection | ☐ |
| 2 | Migration contains only INSERT statements — no DDL, no RLS, no GRANT/REVOKE | Code review | ☐ |
| 3 | Migration header comment block documents purpose and EP reference | Code review | ☐ |
| 4 | 8 industries seeded with correct slugs, names, descriptions, sort_order, is_active=true | Query verification | ☐ |
| 5 | 46 professions seeded with correct slugs, names, descriptions, sort_order, is_active=true | Query verification | ☐ |
| 6 | All profession `industry_id` FKs are valid — zero orphans | FK integrity query | ☐ |
| 7 | All slugs globally unique in both tables | Uniqueness query | ☐ |
| 8 | All slugs pass CHECK constraint format | Constraint verification | ☐ |
| 9 | Migration is idempotent (re-run produces identical state) | Dual-run test | ☐ |
| 10 | No hardcoded UUIDs in migration | Code review | ☐ |
| 11 | Profession `industry_id` resolved via slug subselects | Code review | ☐ |
| 12 | pgTAP test `009_taxonomy_seed_verification.sql` exists and passes all assertions | `supabase db test` | ☐ |
| 13 | Existing pgTAP tests (`006`, `008`) pass without regression | `supabase db test` | ☐ |
| 14 | Full test suite reports zero failures | `supabase db test` | ☐ |
| 15 | RLS posture unchanged — no new policies, grants, or auth modifications | Code review + security query | ☐ |
| 16 | `anon` and `authenticated` can read all seeded data | Role-based SELECT test | ☐ |
| 17 | `authenticated` cannot write to seeded data | Role-based INSERT/UPDATE/DELETE test | ☐ |
| 18 | No client-side code created — no files added under `lib/` | File inspection | ☐ |
| 19 | No modifications to existing migration files | Diff review | ☐ |
| 20 | Seed data content reviewed for Nigerian market relevance and accuracy | Project lead review | ☐ |
| 21 | EP-02-02 unblocked — taxonomy management RPCs can operate against real data | Dependency check | ☐ |

---

> **Sign-off:** Task EP-02-01 marked **Completed** -- all 21 conditions in the Final Approval Checklist are verified and signed off by the project lead.
