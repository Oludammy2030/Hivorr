# Task Implementation Plan — EP-03-03: Double-Blind Review & Rating Schema & Server-Side Rules

**Task ID:** EP-03-03 | **Priority:** High | **Status:** Not Started | **Phase:** EP-03 Stage 1 — Trust & Rating

> **Source of Truth:** `documents/Engineering-Execution/Engineering-Phase-Plan/EP-03 Two-Party Transaction Engine & Professional Services Platform.md:268-276` + `documents/Context/AGENT.md:1-18` + `documents/Context/ARCHITECTURE.md:39-173` + `supabase/migrations/20260924090001_service_review_schema.sql:1` (pending)

---

## 1. Task Objective

Deliver the trust-invariant **double-blind review system** that prevents retaliatory rating by ensuring neither participant's `rating`/`comment` is revealed until **both have submitted** or the **14-day deadline** expires, then reveals atomically with aggregate recomputation and `service_listings` cache update in a single transaction.

Deliverables (server-only, zero `lib/` Dart initially, zero mutation of prior tables except `service_listings avg_rating/review_count` cache):

- **2 tables:** `service_reviews` (FK `contract_id→service_contracts CASCADE`, `service_listing_id→service_listings RESTRICT`, `reviewer/reviewee→entities RESTRICT`, `profession_id→professions RESTRICT`, `rating 1-5 smallint`, `comment 10-2000`, `is_revealed boolean default false`, `revealed_at`, `UNIQUE(contract_id, reviewer_entity_id)`, `CHECK no_self`, `CHECK revealed_at semantics`), `service_review_aggregates` (PK `profession_id+professional_entity_id`, `avg_rating numeric 0-5`, `review_count int`, `distribution jsonb {1:count,...5:count}`, `updated_at`)
- **4 RPCs `SECURITY INVOKER`, envelope `{success,code,message,data}` (`PLT000/001/003/004/005/999`):** `service_review_submit(contract_id, rating, comment)`, `service_review_get_mine(contract_id)`, `service_review_get_for_listing(service_listing_id, limit, cursor)` (returns only `is_revealed=true`, `anon` readable for public stars), `service_review_reveal_if_ready(contract_id)` (internal, `FOR UPDATE` on `service_reviews` rows, `ON CONFLICT DO UPDATE` on aggregates, also called internally by `submit` when `count=2`)
- **Atomic cache:** `service_listings avg_rating` + `review_count` updated in same transaction as `is_revealed` flip (via `FOR UPDATE` on `service_listings` row, narrow `GRANT UPDATE(avg_rating, review_count)` to `authenticated`)
- **Full RLS default-deny** participant + public `is_revealed` + `service_role` full, `REVOKE EXECUTE` re-baseline, `8` `COMMENT ON FUNCTION`, realtime exclusion, `GIN` not needed (review listing is by `service_listing_id`).

Unblocks `EP-03-06` ranking (`bayesian_avg` over `service_review_aggregates`), `EP-03-12` client `double_blind_review_*` widgets, `EP-03-09` `service_detail_screen` stars.

## 2. Business Problem Being Solved

EP-03-02 proved `service_contracts:43` (`offered→active→closed`) and `EP-03-01` proved `service_listings:42` with `avg_rating/review_count` cache columns (currently `0`). No double-blind primitive exists:

- Reviews are currently not stored, so `EP-03-06` `w_rating * bayesian_avg` has no data, and `EP-03-09` `service_detail_screen` cannot show stars.
- Without `is_revealed=false` until `count=2` (both participants submitted `rating` for same `contract_id`) or `now() > review_deadline`, retaliatory rating returns (Business-Roadmap Trust layer #3).
- Without atomic `is_revealed` flip + `service_review_aggregates` recomputation + `service_listings` cache in one transaction, `avg_rating` would drift from `SELECT avg(rating) WHERE is_revealed=true`.

## 3. Scope

| In Scope | Detail |
|---|---|
| `service_reviews` | `id uuid PK`, `contract_id→service_contracts CASCADE`, `service_listing_id→service_listings RESTRICT`, `reviewer_entity_id→entities RESTRICT`, `reviewee_entity_id→entities RESTRICT`, `profession_id→professions RESTRICT`, `rating smallint 1-5 CHECK`, `comment text 10-2000`, `is_revealed boolean default false`, `revealed_at timestamptz`, `UNIQUE(contract_id, reviewer_entity_id)`, `CHECK no_self`, `CHECK revealed_at semantics`, `created_at/updated_at` + `platform_set_updated_at()` |
| `service_review_aggregates` | `professional_entity_id→entities RESTRICT`, `profession_id→professions RESTRICT`, `avg_rating numeric 0-5`, `review_count int`, `distribution jsonb`, `updated_at`, `PK (professional_entity_id, profession_id)` |
| `service_review_submit` | `p_contract_id uuid, p_rating smallint, p_comment text` → `INSERT` `is_revealed=false` + `service_review_reveal_if_ready` if `count=2` or `deadline` → `is_revealed=true` + aggregates + `service_listings` cache |
| `service_review_get_mine` | `p_contract_id uuid` → returns `is_revealed` + `revealed_at` + `rating`/`comment` only if `is_revealed=true` or `reviewer=auth.uid()` shows `you_submitted` boolean, not counterparty `rating` |
| `service_review_get_for_listing` | `p_service_listing_id uuid, p_limit int, p_cursor uuid` → `STABLE`, `anon` + `authenticated` readable, returns only `is_revealed=true` rows paginated, plus `service_review_aggregates` for that listing's `profession_id` |
| `service_review_reveal_if_ready` | `p_contract_id uuid` → internal `FOR UPDATE` on `service_reviews where contract_id=p_contract_id` + `EXISTS` both submitted → `UPDATE is_revealed=true, revealed_at=now()` + `INSERT ... ON CONFLICT DO UPDATE` aggregates + `UPDATE service_listings SET avg_rating, review_count` |
| RLS + grants | `REVOKE ALL` 2 tables from `anon,authenticated,service_role` then `GRANT SELECT` on `aggregates` to `anon,authenticated` (public stars), `SELECT,INSERT` on `service_reviews` to `authenticated` with `UPDATE(is_revealed,revealed_at,updated_at)` narrow, full to `service_role`; `GRANT UPDATE(avg_rating, review_count)` on `service_listings` to `authenticated` (safe, mirrors `financial_balances:520`) |
| Realtime exclusion | Guarded `DO $$ ALTER PUBLICATION supabase_realtime DROP TABLE` |
| pgTAP | `027_service_review_schema_posture.sql` + `028_service_review_rpc_enforcement.sql` |

## 4. Out of Scope

| Out of Scope | Reason |
|---|---|
| `conversations/messages` | `EP-03-04` |
| `availability_slots/appointments` | `EP-03-05` |
| `service_ranking_search` ranking formula | `EP-03-06` consumes `service_review_aggregates` |
| Any `lib/systems/reviews/*` Dart | `EP-03-12` |
| Admin moderation of reviews | `EP-02-11` tooling reuse |
| New `service_listing_media` bucket | Reuse `20260921090001:284` |

## 5. Recommended Technical Approach

### 5.1 Single Migration `supabase/migrations/20260924090001_service_review_schema.sql` (after `20260923090001` tip)

1. Header (EP-03-03, `SECURITY INVOKER`, envelope, double-blind state machine, `REVIEW_REVEAL_DAYS=14`, grant strategy).
2. DDL `service_reviews` (FKs `CASCADE/RESTRICT`, `CHECK 1-5`, `10-2000`, `UNIQUE(contract_id, reviewer)`, `CHECK no_self`, `CHECK revealed_at`, indexes `contract_idx, reviewer_idx, listing_revealed_idx, contract_revealed_idx`, `platform_set_updated_at()`, comments).
3. DDL `service_review_aggregates` (FKs, `CHECK 0-5`, `PK (professional, profession)`, indexes, comments).
4. `ALTER TABLE ... ENABLE RLS` + `REVOKE ALL` + `GRANT` + `UPDATE avg_rating, review_count` on `service_listings` to `authenticated`.
5. 4 RPCs `SECURITY INVOKER` (`VOLATILE` `submit/reveal`, `STABLE` `get_mine/get_for_listing`).
6. `REVOKE EXECUTE ON ALL FUNCTIONS FROM public` + `GRANT EXECUTE` per RPC + `COMMENT ON FUNCTION`.
7. Guarded `DO $$` realtime exclusion.

### 5.2 Execution Model `SECURITY INVOKER`

All 4 RPCs `SECURITY INVOKER` — RLS inside body. `008/013/015/023/025` posture `prosecdef=0`.

| RPC | `anon` | `authenticated` | `service_role` | Gate |
|---|---|---|---|---|
| `service_review_submit` | — | `EXECUTE` (participant, `contract.status='closed'/'completed'`) | `EXECUTE` | `platform_is_authenticated()`, `contract.client OR professional = auth.uid()`, `UNIQUE` `PLT005` `Already reviewed`, `rating 1-5` `PLT003` |
| `service_review_get_mine` | — | `EXECUTE` (participant) | `EXECUTE` | `contract participant = auth.uid()` → returns `you_submitted` boolean, not counterparty `rating` until `is_revealed` |
| `service_review_get_for_listing` | `EXECUTE` (public `is_revealed=true` only) | `EXECUTE` (public) | `EXECUTE` | `is_revealed=true` `WHERE service_listing_id=p_service_listing_id` + `service_review_aggregates` for `profession_id` |
| `service_review_reveal_if_ready` | — | `EXECUTE` (internal, participant) | `EXECUTE` | `FOR UPDATE` on `service_reviews` `count=2` → `is_revealed=true` + `aggregates` + `service_listings` cache |

**State machine:** `INSERT is_revealed=false` → `both_submitted (count=2) → is_revealed=true` atomically with `UPDATE service_review_aggregates SET avg_rating=avg(rating), review_count=count(*), distribution=jsonb_build_object(...)` + `UPDATE service_listings SET avg_rating, review_count` (same `professional, profession`).

**Deadline:** `review_deadline = coalesce(closed_at, completed_at, accepted_at) + 14 days`; `reveal_if_ready` also called by `service_review_submit` and by a future `pg_cron` job (not in this migration) when `now() > deadline`; if `completed_at IS NULL` (active), only `count=2` path applies.

## 6. Reuse

- `service_listings` `avg_rating/review_count` cache (`20260921090001:42`): **Reuse** — `GRANT UPDATE(avg_rating, review_count)` to `authenticated` (narrow) for atomic cache, mirrors `financial_balances:520`.
- `service_contracts` `closed/completed` gate (`20260923090001:43`): **Reuse** — `reviewable` check `contract.status IN ('closed','completed')` + `closed_at/completed_at` for deadline.
- `professions/industries` `20260821090001:15`: **Reuse** `profession_id` for aggregate partition.
- `platform_*` helpers `20260819090001:37`: **Reuse** `platform_is_authenticated()`, `platform_raise_error()`, `platform_set_updated_at()`.

## 7. Data Requirements

### 7.1 `service_reviews`
`id uuid PK`, `contract_id→service_contracts CASCADE`, `service_listing_id→service_listings RESTRICT`, `reviewer→entities RESTRICT`, `reviewee→entities RESTRICT`, `profession_id→professions RESTRICT`, `rating 1-5`, `comment 10-2000`, `is_revealed boolean default false`, `revealed_at`, `UNIQUE(contract_id, reviewer)`, `CHECK no_self`, `CHECK revealed_at`.

### 7.2 `service_review_aggregates`
`professional_entity_id→entities RESTRICT`, `profession_id→professions RESTRICT`, `avg_rating 0-5`, `review_count`, `distribution jsonb`, `PK (professional, profession)`.

## 8. Database Considerations

**RLS & Grants:**
```sql
revoke all on service_reviews, service_review_aggregates from anon, authenticated, service_role;
grant select on service_review_aggregates to anon, authenticated;
grant select, insert on service_reviews to authenticated; -- + UPDATE(is_revealed,revealed_at,updated_at) narrow
grant update (avg_rating, review_count) on service_listings to authenticated;
grant select, insert, update, delete on service_reviews, service_review_aggregates to service_role;
```
Policies: `service_reviews_select` (`reviewer=auth.uid() OR reviewee=auth.uid() OR is_revealed=true` for `get_for_listing` via `service_listing_id`), `service_reviews_insert WITH CHECK (reviewer=auth.uid())`.

**Indexes:** `service_reviews_contract_idx`, `reviewer_idx`, `listing_revealed_idx WHERE is_revealed`, `contract_revealed_idx`.

**Triggers:** `platform_set_updated_at()` on `service_reviews` + `service_review_aggregates`.

## 9. API Requirements

| RPC | Signature | Volatility | Access | Purpose |
|---|---|---|---|---|
| `service_review_submit` | `(p_contract_id uuid, p_rating smallint, p_comment text)` | `VOLATILE` | `authenticated, service_role` | `INSERT` `is_revealed=false` → `reveal_if_ready` if `count=2` |
| `service_review_get_mine` | `(p_contract_id uuid)` | `STABLE` | `authenticated, service_role` | `you_submitted` boolean, not counterparty `rating` until `is_revealed` |
| `service_review_get_for_listing` | `(p_service_listing_id uuid, p_limit int, p_cursor uuid)` | `STABLE` | `anon, authenticated, service_role` | `is_revealed=true` only + `aggregates` |
| `service_review_reveal_if_ready` | `(p_contract_id uuid)` | `VOLATILE` | `authenticated, service_role` | `FOR UPDATE` `count=2` → `is_revealed=true` + aggregates + cache |

## 10. UI Requirements

**None** — server-only. Client `lib/systems/reviews/services/service_review_service.dart` + `double_blind_review_*` widgets is `EP-03-12`.

## 11. Security Considerations

- `CHECK reviewer<>reviewee` + `UNIQUE(contract_id, reviewer)` → `PLT005` `Already reviewed`
- Plain `SELECT` on `service_reviews` returns `0` for `is_revealed=false` via `get_for_listing` `WHERE is_revealed=true` (no oracle)
- `service_review_get_mine` returns `you_submitted` boolean, not `revealed` count
- `prosecdef 0` (`025:234` pattern)

## 12. Performance Considerations

- `service_reviews_listing_revealed_idx WHERE is_revealed` for `get_for_listing` `Index Scan`
- `service_review_aggregates` `PK` for `ON CONFLICT DO UPDATE` with `FOR UPDATE`

## 13. Testing Strategy

`027_service_review_schema_posture.sql` (`has_table 2`, `relrowsecurity 2`, `anon 0`, `authenticated 2`, `prosecdef 0`, `4 RPCs`, `realtime 0`) + `028_service_review_rpc_enforcement.sql` (`anon can get_for_listing`, `authenticated submit` `PLT003/004/005`, `both_submitted→revealed` `is_revealed=true` + `avg_rating` `avg(rating)` + `service_listings` cache, `stranger` `PLT004`, `count=2` vs `deadline`).

## 14. Expected Outcome

- 2 tables `relrowsecurity 2` + 4 `SECURITY INVOKER` RPCs `prosecdef 0` + `service_listings` cache narrow grant + `8` `COMMENT ON FUNCTION`
- Double-blind `is_revealed=false` until `count=2`, then `true` atomically with `aggregates` + `service_listings` `avg_rating` `review_count` in same transaction

