-- EP-02-06: Storage Infrastructure Posture
--
-- Validates the 3 storage buckets + storage.objects RLS policies (EP-02-06 TIP
-- §14.1). Mirrors the 013_financial_schema_posture.sql / 015_dispute_schema_
-- posture.sql style: begin; set search_path to extensions, public, storage;
-- select plan(N); ... select * from finish(); rollback;
--
-- Covers:
--   - All 3 buckets exist with correct public / file_size_limit / MIME allowlist.
--   - storage.objects RLS enabled; >= 11 policies across all buckets.
--   - anon has zero INSERT/UPDATE/DELETE policies (default-deny write).
--   - credential-documents is private & owner-scoped (no anon SELECT); the two
--     public buckets grant SELECT to anon + authenticated.
--   - Every policy carries the bucket_id conjunct (no cross-bucket leakage).
--   - No storage_% SECURITY DEFINER function (013/015 regression guard keeps).
--   - Buckets are well-formed (not-null created_at, exactly 3 rows).
--   - storage schema not in supabase_realtime.
--   - Role-simulated leakage: an authenticated user cannot read another
--     entity's credential under the private bucket (001-style harness).

begin;
set search_path to extensions, public, storage;
select plan(25);

-- ─── 1-3. All 3 buckets exist ────────────────────────────────────────────────
select is(
  (select count(*)::int from storage.buckets where id = 'credential-documents'),
  1,
  'bucket credential-documents exists'
);
select is(
  (select count(*)::int from storage.buckets where id = 'profile-avatars'),
  1,
  'bucket profile-avatars exists'
);
select is(
  (select count(*)::int from storage.buckets where id = 'portfolio-items'),
  1,
  'bucket portfolio-items exists'
);

-- ─── 4-6. Public flags ───────────────────────────────────────────────────────
select is(
  (select public from storage.buckets where id = 'credential-documents'),
  false,
  'credential-documents is private (public = false)'
);
select is(
  (select public from storage.buckets where id = 'profile-avatars'),
  true,
  'profile-avatars is public (public = true)'
);
select is(
  (select public from storage.buckets where id = 'portfolio-items'),
  true,
  'portfolio-items is public (public = true)'
);

-- ─── 7-9. file_size_limit ────────────────────────────────────────────────────
select is(
  (select file_size_limit from storage.buckets where id = 'credential-documents'),
  10485760::bigint,
  'credential-documents file_size_limit = 10485760 (10 MiB)'
);
select is(
  (select file_size_limit from storage.buckets where id = 'profile-avatars'),
  5242880::bigint,
  'profile-avatars file_size_limit = 5242880 (5 MiB)'
);
select is(
  (select file_size_limit from storage.buckets where id = 'portfolio-items'),
  10485760::bigint,
  'portfolio-items file_size_limit = 10485760 (10 MiB)'
);

-- ─── 10-12. allowed_mime_types ───────────────────────────────────────────────
select is(
  (select allowed_mime_types from storage.buckets where id = 'credential-documents'),
  array['image/jpeg','image/png','image/webp','application/pdf']::text[],
  'credential-documents MIME allowlist = jpeg/png/webp/pdf'
);
select is(
  (select allowed_mime_types from storage.buckets where id = 'profile-avatars'),
  array['image/jpeg','image/png','image/webp']::text[],
  'profile-avatars MIME allowlist = jpeg/png/webp'
);
select ok(
  (select allowed_mime_types from storage.buckets where id = 'portfolio-items') @> '{application/pdf}'::text[],
  'portfolio-items MIME allowlist includes application/pdf'
);

-- ─── 13. storage.objects RLS enabled ──────────────────────────────────────────
select is(
  (select c.relrowsecurity
     from pg_class c
     join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'storage' and c.relname = 'objects'),
  true,
  'storage.objects RLS is enabled'
);

-- ─── 14. >= 11 storage.objects policies ───────────────────────────────────────
select ok(
  (select count(*)::int from pg_policies where schemaname = 'storage' and tablename = 'objects') >= 11,
  'at least 11 storage.objects policies exist covering all buckets'
);

-- ─── 15. anon has zero INSERT/UPDATE/DELETE on storage.objects ───────────────
select is(
  (select count(*)::int
     from pg_policies
    where schemaname = 'storage' and tablename = 'objects'
      and roles @> array['anon']::name[]
      and cmd in ('INSERT','UPDATE','DELETE')),
  0,
  'anon has zero INSERT/UPDATE/DELETE policies on storage.objects'
);

-- ─── 16. credential-documents SELECT is owner-scoped (no anon) ────────────────
select is(
  (select count(*)::int
     from pg_policies
    where schemaname = 'storage' and tablename = 'objects'
      and policyname = 'credential_documents_select_owner'
      and roles @> array['authenticated']::name[]
      and not (roles @> array['anon']::name[])
      and qual::text like '%foldername%'
      and qual::text like '%auth.uid()%'),
  1,
  'credential-documents SELECT policy is owner-scoped to authenticated (no anon)'
);

-- ─── 17. profile-avatars public SELECT for anon + authenticated ──────────────
select is(
  (select count(*)::int
     from pg_policies
    where schemaname = 'storage' and tablename = 'objects'
      and policyname = 'profile_avatars_select_public'
      and roles @> array['anon','authenticated']::name[]),
  1,
  'profile-avatars public SELECT granted to anon + authenticated'
);

-- ─── 18. portfolio-items public SELECT for anon + authenticated ──────────────
select is(
  (select count(*)::int
     from pg_policies
    where schemaname = 'storage' and tablename = 'objects'
      and policyname = 'portfolio_items_select_public'
      and roles @> array['anon','authenticated']::name[]),
  1,
  'portfolio-items public SELECT granted to anon + authenticated'
);

-- ─── 19. no storage.objects policy grants anon INSERT ─────────────────────────
select is(
  (select count(*)::int
     from pg_policies
    where schemaname = 'storage' and tablename = 'objects'
      and roles @> array['anon']::name[]
      and cmd = 'INSERT'),
  0,
  'no storage.objects policy grants anon INSERT'
);

-- ─── 20. no storage_% SECURITY DEFINER function ───────────────────────────────
select is(
  (select count(*)::int
     from pg_proc
    where proname like 'storage_%' and prosecdef),
  0,
  'no storage_% function is SECURITY DEFINER'
);

-- ─── 21. exactly 3 buckets with not-null ids (well-formed catalog) ─────────────
select is(
  (select count(*)::int from storage.buckets where id is not null and btrim(id) <> ''),
  3,
  'storage.buckets contains exactly 3 rows with non-empty ids'
);

-- ─── 22. all 3 buckets created_at not null ────────────────────────────────────
select is(
  (select count(*)::int from storage.buckets where created_at is null),
  0,
  'all buckets have not-null created_at'
);

-- ─── 23. every policy carries the bucket_id conjunct (no cross-bucket leak) ──
select is(
  (select count(*)::int
     from pg_policies
    where schemaname = 'storage' and tablename = 'objects'
      and coalesce(qual::text, '') not like '%bucket_id%'
      and coalesce(with_check::text, '') not like '%bucket_id%'),
  0,
  'every storage.objects policy includes the bucket_id conjunct'
);

-- ─── 24. realtime excludes storage schema ─────────────────────────────────────
select is(
  (select count(*)::int
     from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'storage'),
  0,
  'storage schema is not in supabase_realtime'
);

-- ─── 25. leakage simulation: authenticated cannot read another entity's ───────
-- ────────── credential (owner-scoped isolation under the private bucket) ───────
-- Fixtures: insert a credential object for entity A and one for entity B as
-- service_role (RLS bypass), then act as B and confirm only B's own row is
-- visible (A's row hidden by the owner-scoped SELECT policy). Object names are
-- the path WITHIN the bucket (bucket_id is tracked separately); the first path
-- segment is the entity id that storage.foldername(name)[1] checks.
set role service_role;
insert into storage.objects (bucket_id, name, owner, owner_id, version)
values ('credential-documents', '11111111-1111-1111-1111-111111111111/sub/uuid-one.pdf',
        '11111111-1111-1111-1111-111111111111'::uuid,
        '11111111-1111-1111-1111-111111111111', '1');
insert into storage.objects (bucket_id, name, owner, owner_id, version)
values ('credential-documents', '22222222-2222-2222-2222-222222222222/sub/uuid-two.pdf',
        '22222222-2222-2222-2222-222222222222'::uuid,
        '22222222-2222-2222-2222-222222222222', '1');

set role authenticated;
select set_config('request.jwt.claim.sub', '22222222-2222-2222-2222-222222222222', true);
select set_config('request.jwt.claim.role', 'authenticated', true);

select is(
  (select count(*)::int
     from storage.objects
    where bucket_id = 'credential-documents'),
  1,
  'authenticated user B sees only own credential row (entity A row hidden)'
);

set role service_role;
select * from finish();
rollback;
