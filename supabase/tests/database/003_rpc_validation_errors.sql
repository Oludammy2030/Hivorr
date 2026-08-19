-- EP-01-05: Validation & Error Contract
--
-- Verifies the normalized error-code contract PLT001-PLT005 and that error
-- messages are static (never contain data values or credentials)
-- (EP-01-05 Plan §14.3).
--
-- Actor: A = 11111111-1111-1111-1111-111111111111 (authenticated).

begin;
set search_path to extensions, public;
select plan(15);

set role authenticated;
select set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', true);
select set_config('request.jwt.claim.role', 'authenticated', true);

-- ─── PLT003: validation failures ────────────────────────────────────────────
select throws_ok(
  'select public.platform_demo_records_create('''', ''{}''::jsonb)',
  'P0001',
  'PLT003: Title is required\.',
  'empty title raises PLT003'
);

select throws_ok(
  'select public.platform_demo_records_create(NULL, ''{}''::jsonb)',
  'P0001',
  'PLT003: Title is required\.',
  'null title raises PLT003'
);

select throws_ok(
  'select public.platform_demo_records_create(''   '', ''{}''::jsonb)',
  'P0001',
  'PLT003: Title is required\.',
  'whitespace title raises PLT003'
);

select throws_ok(
  'select public.platform_demo_records_create(repeat(''x'', 256), ''{}''::jsonb)',
  'P0001',
  'PLT003: Title must be 255 characters or fewer\.',
  'oversized title raises PLT003'
);

select throws_ok(
  'select public.platform_demo_records_create(''ok'', NULL)',
  'P0001',
  'PLT003: Payload is required\.',
  'null payload raises PLT003'
);

select throws_ok(
  'select public.platform_demo_records_create(''ok'', ''[1,2]''::jsonb)',
  'P0001',
  'PLT003: Payload must be a JSON object\.',
  'non-object payload raises PLT003'
);

select throws_ok(
  'select public.platform_validate_payload(''{"name":"x"}'', ''{"name","amount"}''::text[])',
  'P0001',
  'PLT003: Missing required field\(s\): amount\.',
  'missing required payload key raises PLT003'
);

-- ─── PLT005: conflict ───────────────────────────────────────────────────────
select lives_ok(
  'select public.platform_demo_records_create(''dup'', ''{}''::jsonb)',
  'first record with title dup created'
);

select throws_ok(
  'select public.platform_demo_records_create(''dup'', ''{}''::jsonb)',
  'P0001',
  'PLT005: A record with this title already exists\.',
  'duplicate owner title raises PLT005'
);

-- ─── PLT004: not found ──────────────────────────────────────────────────────
select throws_ok(
  'select public.platform_demo_records_get(''00000000-0000-0000-0000-000000000000''::uuid)',
  'P0001',
  'PLT004: Record not found\.',
  'unknown id raises PLT004'
);

select throws_ok(
  'select public.platform_demo_records_update(''00000000-0000-0000-0000-000000000000''::uuid, ''{}''::jsonb)',
  'P0001',
  'PLT004: Record not found\.',
  'update of unknown id raises PLT004'
);

-- ─── PLT003: missing ids (parameter validation) ─────────────────────────────
select throws_ok(
  'select public.platform_demo_records_get(NULL)',
  'P0001',
  'PLT003: Record id is required\.',
  'null id on get raises PLT003'
);

select throws_ok(
  'select public.platform_demo_records_update(NULL, ''{}''::jsonb)',
  'P0001',
  'PLT003: Record id is required\.',
  'null id on update raises PLT003'
);

select throws_ok(
  'select public.platform_audit_log_add('''', ''entity'')',
  'P0001',
  'PLT003: Audit action is required\.',
  'empty audit action raises PLT003'
);

select throws_ok(
  'select public.platform_audit_log_add(''action'', '''')',
  'P0001',
  'PLT003: Audit entity is required\.',
  'empty audit entity raises PLT003'
);

select * from finish();
rollback;