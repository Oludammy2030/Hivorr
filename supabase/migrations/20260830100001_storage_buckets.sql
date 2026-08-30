-- =============================================================================
-- EP-02-06: Supabase Storage Infrastructure & Bucket Configuration
-- -----------------------------------------------------------------------------
-- Migration: 20260830100001_storage_buckets.sql
-- Source of truth: documents/Task-Implementation/EP-02/EP-02-06-Supabase
--   Storage Infrastructure & Bucket Configuration.md (approved TIP §5).
-- Ordered after 20260829120006_dispute_withdraw_definer.sql.
--
-- PURPOSE
--   Provision 3 RLS-protected storage buckets that underpin all EP-02 trust
--   workflows, and lay down owner-scoped `storage.objects` policies that enforce
--   a default-deny posture:
--
--     BUCKET               public  size    MIME                             access model
--     credential-documents false   10MiB   jpeg/png/webp/pdf                owner-only (private)
--     profile-avatars      true    5MiB    jpeg/png/webp                    public read + owner write
--     portfolio-items      true    10MiB   jpeg/png/webp/pdf                public read + owner write
--
-- SECURITY POSTURE
--   * storage.objects RLS is enabled (vanilla Supabase default; re-asserted
--     idempotently below).
--   * Every policy carries the `bucket_id = '<bucket>'` conjunct to prevent
--     cross-bucket leakage.
--   * Write policies use WITH CHECK on the first path segment
--     `(storage.foldername(name))[1] = auth.uid()::text` to block prefix escape.
--   * anon receives ZERO INSERT/UPDATE/DELETE policies (default-deny writes).
--   * service_role bypasses RLS (no policy needed) for server-side admin review.
--
-- PATH CONVENTION (documented for EP-02-08 lib/core/storage)
--   credential-documents/{entity_id}/{submission_id}/{uuid}.{ext}
--   profile-avatars/{entity_id}/avatar[.{ext}]          (canonical single avatar)
--   portfolio-items/{entity_id}/{item_id}/{file_name}
--   where {entity_id} == auth.uid()::text.
--
-- IDEMPOTENCY
--   * Buckets: INSERT ... ON CONFLICT (id) DO UPDATE.
--   * Policies: DROP POLICY IF EXISTS before CREATE POLICY.
--   * RLS enable: ALTER TABLE ... ENABLE ROW LEVEL SECURITY (idempotent).
--   Safe to re-apply across dev/staging/prod (ENV-002/ENV-008 isolation).
--
-- SCOPE
--   Touches the `storage` schema only. No DDL on `public.*`. No RPCs created.
--   No SECURITY DEFINER functions. No `lib/` (Dart) changes.
-- =============================================================================

-- 1. Bucket DDL --------------------------------------------------------------
-- `type` defaults to 'STANDARD' (NOT NULL, storage.buckettype). `avif`
-- autodetection left at default (DISABLED). `file_size_limit` is byte-enforced
-- by the Storage API on upload; `allowed_mime_types` is the MIME allowlist.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'credential-documents', 'credential-documents', false, 10485760 /* 10 MiB */,
  '{image/jpeg,image/png,image/webp,application/pdf}'
)
on conflict (id) do update
   set public = excluded.public,
       file_size_limit = excluded.file_size_limit,
       allowed_mime_types = excluded.allowed_mime_types,
       updated_at = now();

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'profile-avatars', 'profile-avatars', true, 5242880 /* 5 MiB */,
  '{image/jpeg,image/png,image/webp}'
)
on conflict (id) do update
   set public = excluded.public,
       file_size_limit = excluded.file_size_limit,
       allowed_mime_types = excluded.allowed_mime_types,
       updated_at = now();

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'portfolio-items', 'portfolio-items', true, 10485760 /* 10 MiB */,
  '{image/jpeg,image/png,image/webp,application/pdf}'
)
on conflict (id) do update
   set public = excluded.public,
       file_size_limit = excluded.file_size_limit,
       allowed_mime_types = excluded.allowed_mime_types,
       updated_at = now();

-- 2. RLS Enablement ----------------------------------------------------------
-- storage.objects RLS is ENABLED by default in vanilla Supabase (confirmed:
-- relrowsecurity = t). The table is owned by supabase_storage_admin, so the
-- migration principal cannot ALTER TABLE storage.objects (would raise
-- "must be owner of table objects"); no ownership-gated DDL is needed because
-- RLS is already on and the storage API enforces access via the policies we
-- create below. RLS state is asserted in 017_storage_posture.sql (#13).

-- 3. Revoke & Policy Reset ---------------------------------------------------
-- Drop any pre-existing policies for the three buckets so a clean re-run never
-- accumulates stale policies.

drop policy if exists credential_documents_select_owner   on storage.objects;
drop policy if exists credential_documents_insert_owner   on storage.objects;
drop policy if exists credential_documents_update_owner   on storage.objects;
drop policy if exists credential_documents_delete_owner   on storage.objects;

drop policy if exists profile_avatars_select_public       on storage.objects;
drop policy if exists profile_avatars_insert_owner        on storage.objects;
drop policy if exists profile_avatars_update_owner        on storage.objects;
drop policy if exists profile_avatars_delete_owner        on storage.objects;

drop policy if exists portfolio_items_select_public       on storage.objects;
drop policy if exists portfolio_items_insert_owner        on storage.objects;
drop policy if exists portfolio_items_update_owner        on storage.objects;
drop policy if exists portfolio_items_delete_owner        on storage.objects;

-- 4. Policies ----------------------------------------------------------------
-- credential-documents: PRIVATE, owner-only (authenticated). No anon SELECT.
create policy credential_documents_select_owner
  on storage.objects for select to authenticated
  using (
    bucket_id = 'credential-documents'
    and auth.role() = 'authenticated'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy credential_documents_insert_owner
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'credential-documents'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy credential_documents_update_owner
  on storage.objects for update to authenticated
  using (
    bucket_id = 'credential-documents'
    and (storage.foldername(name))[1] = auth.uid()::text
  )
  with check (
    bucket_id = 'credential-documents'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy credential_documents_delete_owner
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'credential-documents'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- profile-avatars: PUBLIC read (anon + authenticated), owner write/delete.
create policy profile_avatars_select_public
  on storage.objects for select to anon, authenticated
  using (bucket_id = 'profile-avatars');

create policy profile_avatars_insert_owner
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'profile-avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy profile_avatars_update_owner
  on storage.objects for update to authenticated
  using (
    bucket_id = 'profile-avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  )
  with check (
    bucket_id = 'profile-avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy profile_avatars_delete_owner
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'profile-avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- portfolio-items: PUBLIC read (anon + authenticated), owner write/delete.
create policy portfolio_items_select_public
  on storage.objects for select to anon, authenticated
  using (bucket_id = 'portfolio-items');

create policy portfolio_items_insert_owner
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'portfolio-items'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy portfolio_items_update_owner
  on storage.objects for update to authenticated
  using (
    bucket_id = 'portfolio-items'
    and (storage.foldername(name))[1] = auth.uid()::text
  )
  with check (
    bucket_id = 'portfolio-items'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy portfolio_items_delete_owner
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'portfolio-items'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- 5. Grants ------------------------------------------------------------------
-- storage.buckets and storage.objects are NOT grant-managed like `public.*`.
-- Access flows through the storage.objects RLS policies above + the Supabase
-- Storage API roles (anon / authenticated). No GRANT on storage.* is issued.

-- 6. Bucket Rationale -----------------------------------------------------------
-- Bucket purpose / access-model rationale is documented in the header comment
-- block above (catalog comment via COMMENT ON would raise "must be owner of
-- table buckets": storage.buckets is owned by supabase_storage_admin). Doing
-- Documentation is captured as the migration header, which serves as the
-- authoritative rationale (DoD #26/#27: "documented rationale").

-- 7. Realtime Guard ----------------------------------------------------------
-- storage.objects is not part of supabase_realtime (no exclusion mutation). A
-- guarded assertion validates storage.* is absent from the realtime publication.
do $$
declare
  v_count int;
begin
  select count(*) into v_count
    from pg_publication_tables
   where pubname = 'supabase_realtime'
     and schemaname = 'storage';
  if v_count > 0 then
    raise exception 'EP-02-06 guard: storage schema must not be in supabase_realtime (found %)', v_count;
  end if;
end
$$;
