# Definition of Done — EP-03-03: Double-Blind Review & Rating Schema & Server-Side Rules

> **Verification Checklist for Project Lead Approval — Task-Specific, Not Universal**

---

## 1. Task Identification

| Attribute | Value |
|---|---|
| **Task ID** | EP-03-03 |
| **Task Name** | Double-Blind Review & Rating Schema & Server-Side Rules |
| **Related Phase** | EP-03 Two-Party Transaction Engine & Professional Services Platform — Stage 1 Trust & Rating |
| **Priority** | High |
| **Reference Implementation Plan** | `documents/Task-Implementation/EP-03/EP-03-03 Double-Blind Review & Rating Schema & Server-Side Rules.md:1-560` |
| **Approved Phase Plan** | `documents/Engineering-Execution/Engineering-Phase-Plan/EP-03 Two-Party Transaction Engine & Professional Services Platform.md:268-276` |
| **Dependencies** | EP-03-02 `service_contracts` (`supabase/migrations/20260923090001_service_contract_schema.sql:43`), `service_listings` (`20260921090001:42`), `professions` (`20260821090001:15`), `entities` (`20260821090002:20`), `platform_*` helpers (`20260819090001:37`) |
| **Delivery Scope** | 2 tables `service_reviews` / `service_review_aggregates` + `service_listings avg_rating/review_count` cache narrow grant + 4 RPCs `SECURITY INVOKER` (`service_review_submit`, `service_review_get_mine`, `service_review_get_for_listing`, `service_review_reveal_if_ready`) + participant/public RLS + 2 pgTAP suites. **Zero** `lib/` Dart initially. |
| **Guardrails** | `AGENT.md:13` Rule 4 Database-First, `ARCHITECTURE.md:160` DB-First, `AGENT.md:7` Deterministic Core (no AI reveal) |

**How to use this document:** Check each box only after executing the listed verification (SQL query, `supabase db test`, PostgREST `/rpc/` call) and observing the exact expected result. A single unchecked box blocks `Completed` status.

---

## 2. Functional Verification

### 2.1 Required Functionality

- [ ] **Review submit** — Any authenticated participant (`client` or `professional`) of a `service_contracts` with `status IN ('closed','completed')` can call `service_review_submit(p_contract_id, p_rating 1-5, p_comment 10-2000 or null)` and receive `PLT000` with row `is_revealed=false`, `revealed_at NULL`, `reviewer=auth.uid()`, `reviewee=opposite participant` (derived), `profession_id` denormalized from `service_listings`, `service_listing_id` denormalized. Second submit by same reviewer for same `contract_id` → `PLT005` `Already reviewed` (`UNIQUE(contract_id, reviewer)`).
- [ ] **Reveal on both submitted** — When `count(service_reviews where contract_id=X)=2` (both participants submitted), `service_review_submit` (second submit) atomically flips both rows `is_revealed=true`, `revealed_at=now()`, inserts/updates `service_review_aggregates` (`avg_rating=avg(rating)`, `review_count=2`, `distribution`), and updates `service_listings SET avg_rating, review_count` for that `service_listing_id`/`profession_id` in same transaction.
- [ ] **Get mine** — `service_review_get_mine(p_contract_id)` as participant returns `PLT000` with `you_submitted` boolean, and if `is_revealed=true` returns `rating`/`comment`/`revealed_at`, else returns `you_submitted=true` but `rating`/`comment` hidden (not `is_revealed` count). Non-participant → `PLT004`.
- [ ] **Get for listing** — `service_review_get_for_listing(p_service_listing_id, p_limit, p_cursor)` as `anon`/`authenticated` returns `PLT000` with `items[]` only where `is_revealed=true` for that `service_listing_id` (public stars), plus `aggregates` (`avg_rating`, `review_count`, `distribution`) for that listing's `profession_id`. `is_revealed=false` rows never returned, even to participant via this RPC.

### 2.2 Expected Workflows (End-to-End)

- [ ] **Both submit → reveal:** `C` submits `rating 5` for `closed` contract `X` → `PLT000` `is_revealed=false`; `P` submits `rating 4` for same `X` → `PLT000` `is_revealed=true` for **both** rows + `service_review_aggregates` `avg_rating=4.5` `review_count=2` + `service_listings` `avg_rating=4.5` `review_count=2` (if first reviews for that listing). `service_review_get_for_listing(X.service_listing_id)` as `anon` now returns 2 items.
- [ ] **Single submit → not revealed:** `C` submits `rating 5` for `X` → `is_revealed=false`; `P` has not submitted → `service_review_get_for_listing` as `anon` returns `[]`; `service_review_get_mine` as `C` returns `you_submitted=true` but no counterparty `rating`; as `P` returns `you_submitted=false`.
- [ ] **Duplicate submit blocked:** `C` submits `rating 5` for `X` → `PLT000`; `C` submits again for same `X` → `PLT005` `Already reviewed`.

### 2.3 Success Conditions

- [ ] Every write RPC returns envelope `{success:true, code:'PLT000', message:'...', data: to_jsonb(row)}` on success.
- [ ] `is_revealed` is `false` until `count=2` for that `contract_id`, then `true` for **both** rows atomically in same transaction as `service_review_reveal_if_ready` `FOR UPDATE`.
- [ ] `service_review_aggregates` `avg_rating` equals `SELECT avg(rating) FROM service_reviews WHERE service_listing_id=Y AND is_revealed=true AND profession_id=Z` and `review_count` equals `count(*)`.
- [ ] `service_listings` `avg_rating`/`review_count` for that `service_listing_id` equals `service_review_aggregates` for that `professional, profession` (cache).

### 2.4 Error Handling Scenarios

- [ ] `NULL` `p_contract_id` → `PLT003`.
- [ ] Unknown `contract_id` → `PLT004`.
- [ ] `contract_id` where `contract.status NOT IN ('closed','completed')` (e.g., `offered`, `active`) → `PLT005` `Contract not reviewable`.
- [ ] Non-participant `reviewer` → `PLT004` (identical to unknown `contract_id`).
- [ ] `rating` not `1-5` → `PLT003`.
- [ ] `comment` non-null `char_length NOT BETWEEN 10 AND 2000` → `PLT003`.
- [ ] Self-review `reviewer=reviewee` → `PLT005` `CHECK no_self` (never occurs via RPC, but `CHECK` enforces).
- [ ] Duplicate `(contract_id, reviewer)` → `PLT005` `Already reviewed` via `UNIQUE` `EXCEPTION WHEN unique_violation`.
- [ ] `service_review_get_mine` non-participant → `PLT004`.
- [ ] `service_review_get_for_listing` unknown `service_listing_id` → `PLT004`.

### 2.5 Important User Interactions

- [ ] Second submit triggers `HivorrSuccessState` with `Review revealed` and `service_review_get_for_listing` now shows stars.
- [ ] Single submit shows `Awaiting counterparty` `you_submitted=true` but no stars.
- [ ] All RPCs are CORS-accessible via PostgREST `/rpc/` with `Authorization: Bearer <JWT>` (public `get_for_listing` also `apikey` `anon`).

---

## 3. Technical Verification

### 3.1 Architecture Compliance

- [ ] **Server-side enforcement** (`AGENT.md:13` Rule 4): All `is_revealed` flip, `avg_rating` recomputation, `service_listings` cache update inside `SECURITY INVOKER` RPCs. No `lib/` Dart files created.
- [ ] **File placement** (`ARCHITECTURE.md:39-173`): Single migration after `20260923090001` tip.

### 3.2 Required System Behavior

- [ ] **Execution model:** All 4 RPCs `SECURITY INVOKER` (`pg_proc.prosecdef=false`), `VOLATILE` `submit/reveal`, `STABLE` `get_mine/get_for_listing`.
- [ ] **Volatility:** `submit` `VOLATILE` (writes), `get_*` `STABLE` (PostgREST cacheable).

### 3.3 Module Integration

| Integration Point | Verification |
|---|---|
| `service_contracts` | `service_reviews.contract_id` FK `CASCADE` — `SELECT * FROM service_reviews WHERE contract_id NOT IN (SELECT id FROM service_contracts)` → 0. |
| `service_listings` | `service_reviews.service_listing_id` FK `RESTRICT` + `service_review_aggregates` `FK` + `service_listings` cache `avg_rating` update — `SELECT * FROM service_reviews WHERE service_listing_id NOT IN (SELECT id FROM service_listings)` → 0. |
| `professions` | `profession_id` `RESTRICT` — `SELECT * FROM service_reviews WHERE profession_id NOT IN (SELECT id FROM professions)` → 0. |
| `platform_*` helpers | RPCs use `platform_is_authenticated()`, `platform_raise_error()`, `platform_set_updated_at()`. |

### 3.4 Technical Requirements

- [ ] Migration header documents EP-03-03, `SECURITY INVOKER`, envelope, double-blind state machine, `REVIEW_REVEAL_DAYS=14`, grant strategy.
- [ ] No prior table/function/policy mutated — `git diff -- supabase/migrations/202608*` shows only new `20260924090001_service_review_schema.sql`.

---

## 4. Data Verification

### 4.1 Data Creation

- [ ] `service_reviews` `INSERT` via `submit` creates row with `is_revealed=false`, `revealed_at NULL`, `reviewer=auth.uid()`, `reviewee` derived, `profession_id` denormalized, `service_listing_id` denormalized, `rating 1-5`, `comment 10-2000`.
- [ ] `service_review_aggregates` `INSERT` via `reveal` creates row with `avg_rating`, `review_count`, `distribution`.

### 4.2 Data Updates

- [ ] `service_reviews` `is_revealed` flips `false→true` atomically via `reveal_if_ready` `FOR UPDATE` on `service_reviews where contract_id=X`.
- [ ] `service_review_aggregates` `avg_rating` recomputed via `ON CONFLICT DO UPDATE` with `FOR UPDATE` lock.
- [ ] `service_listings` `avg_rating`/`review_count` updated in same transaction as reveal.

### 4.3 Data Relationships

- [ ] `service_reviews.contract_id → service_contracts CASCADE` — deleting contract cascades reviews.
- [ ] `service_reviews` rows always have `service_listing_id = service_contracts.service_listing_id` — `SELECT * FROM service_reviews sr JOIN service_contracts sc ON sc.id=sr.contract_id WHERE sr.service_listing_id <> sc.service_listing_id` → 0.

### 4.4 Data Accuracy

- [ ] `avg_rating` `0-5`, `review_count` `≥0`, `distribution` `jsonb` `{1:0,...5:0}`.
- [ ] `UNIQUE(contract_id, reviewer)` — `SELECT contract_id, reviewer_entity_id, count(*) FROM service_reviews GROUP BY 1,2 HAVING count(*)>1` → 0.

### 4.5 Data Integrity

- [ ] `CHECK rating 1-5` holds: `SELECT count(*) FROM service_reviews WHERE rating NOT BETWEEN 1 AND 5` → 0.
- [ ] `CHECK comment 10-2000` holds.
- [ ] `is_revealed=false` rows have `revealed_at IS NULL`; `is_revealed=true` rows have `revealed_at IS NOT NULL`.

---

## 5. Security Verification

### 5.1 Authentication

- [ ] `service_review_submit` without JWT → `PLT001`.
- [ ] `service_review_get_for_listing` without JWT on `is_revealed=true` rows → `PLT000` (public).

### 5.2 Authorization

- [ ] `REVOKE EXECUTE` baseline — `service_review_submit` has `authenticated, service_role`; `service_review_get_for_listing` has `anon, authenticated, service_role`.

### 5.3 Access Control

- [ ] **Tables:** `relrowsecurity` `2`.
- [ ] **Policies:** `service_reviews_select` (`reviewer=auth.uid() OR reviewee=auth.uid() OR is_revealed=true` for `get_for_listing` via `service_listing_id`), `service_reviews_insert WITH CHECK (reviewer=auth.uid())`.
- [ ] **`service_role` bypass** — no policy needed.

### 5.4 Sensitive Data Protection

- [ ] No `rating`/`comment` for `is_revealed=false` returned via `get_for_listing`.

### 5.5 Security Rules

- [ ] **Double-blind:** `is_revealed` flip only when `count=2` via `FOR UPDATE`.
- [ ] **No `SECURITY DEFINER`** — `SELECT count(*) FROM pg_proc WHERE proname LIKE 'service_review_%' AND prosecdef=true` → 0.

---

## 6. Performance Verification

- [ ] `service_reviews_listing_revealed_idx WHERE is_revealed` `Index Scan` for `get_for_listing`.
- [ ] `service_review_aggregates` `PK` for `ON CONFLICT DO UPDATE`.

---

## 7. Testing Verification

### 7.1 Manual Testing

- [ ] As `C` and `P` (participants of `closed` contract `X`), each submits `rating` via `service_review_submit` and checks `is_revealed` before/after `count=2`.

### 7.2 Automated Testing

- [ ] `027_service_review_schema_posture.sql` — `has_table` 2, `relrowsecurity` 2, `prosecdef 0`, `4 RPCs`, `realtime 0`.
- [ ] `028_service_review_rpc_enforcement.sql` — `anon can get_for_listing`, `authenticated submit` `PLT003/004/005`, `both_submitted→revealed` `is_revealed=true` + `avg_rating` + `service_listings` cache.

### 7.3 Edge Cases

- [ ] `comment` `NULL` (star-only) → `PLT000`.
- [ ] `rating` `6` → `PLT003`.

### 7.4 Failure Scenarios

- [ ] Duplicate `(contract_id, reviewer)` → `PLT005` not `23505`.

---

## 8. User Acceptance Verification

- [ ] As `C` submits `5` for `closed` contract, `P` has not submitted → `get_for_listing` as `anon` returns `[]`; `P` submits `4` → both `is_revealed=true` and `get_for_listing` returns `2` items with `avg_rating 4.5`.

---

## 9. Final Approval Checklist

| # | Condition | Evidence Required | Status |
|---|---|---|---|
| 1 | `20260924090001_service_review_schema.sql` after `20260923090001` | `ls -l supabase/migrations \| tail -n 5` | ☐ |
| 2 | 2 tables `service_reviews` / `service_review_aggregates` exist with RLS `relrowsecurity=true` `2` + `CHECK` `rating 1-5` `UNIQUE` + comments | `supabase test db --local 027` `plan` `All tests successful.` | ☐ |
| 3 | `8` `COMMENT ON FUNCTION` + `REVOKE EXECUTE` + `GRANT EXECUTE` `authenticated 3` `anon 1` + `service_listings` cache `UPDATE(avg_rating, review_count)` narrow | `027` `EXIT:0` | ☐ |
| 4 | `4` `SECURITY INVOKER` RPCs `prosecdef 0` | `027` `0` | ☐ |
| 5 | Double-blind `is_revealed=false` until `count=2` → `true` atomically with `aggregates` + `service_listings` cache | `028` `EXIT:0` `is_revealed=true` + `avg_rating 4.5` | ☐ |
| 6 | `supabase test db --local` `Files=28, Tests=...` `PASS` | `supabase test db --local` `Result: PASS` | ☐ |
| 7 | No prior DDL, no `lib/` Dart, `dart analyze` `No issues found!` | `git diff --stat` `1 file` `dart analyze` | ☐ |
| 8 | `EP-03-06` `bayesian_avg` over `service_review_aggregates` ready | `SELECT avg_rating FROM service_review_aggregates` | ☐ |

