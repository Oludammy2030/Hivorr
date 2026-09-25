-- EP-03-04: Messaging RPC Enforcement
--
-- Validates the 4 messaging RPCs:
--   - Authorization: anon 42501 on all 4, authenticated participant PLT001/004, service_role bypass.
--   - Validation: PLT003 for null/short/long body, null client_message_id, limit 0/101, null conversation.
--   - Functional: idempotent ensure (ON CONFLICT), dedup via client_message_id ON CONFLICT, participant-only lists, preview redaction, keyset pagination, last_read_at touch.
--   - RLS: stranger SELECT 0 rows, stranger message_list PLT004, direct INSERT blocked, immutability.
--   - service_role can call all 4.

begin;
set search_path to extensions, public;
select plan(64);

-- ─── 0. Fixtures ──────────────────────────────────────────────────────────────
set role postgres;

select set_config('test.a', '11111111-1111-1111-1111-111111111111', true);
select set_config('test.b', '22222222-2222-2222-2222-222222222222', true);
select set_config('test.c', '33333333-3333-3333-3333-333333333333', true);

insert into auth.users (id, email)
values (current_setting('test.a')::uuid, 'msg-a@example.com'),
       (current_setting('test.b')::uuid, 'msg-b@example.com'),
       (current_setting('test.c')::uuid, 'msg-c@example.com')
on conflict (id) do nothing;

insert into public.entities (id, status)
values (current_setting('test.a')::uuid, 'active'),
       (current_setting('test.b')::uuid, 'active'),
       (current_setting('test.c')::uuid, 'active')
on conflict (id) do nothing;

select set_config('test.prof1',
  (select id::text from public.professions where slug = 'legal-consultant'), true);
select set_config('test.prof1',
  coalesce(nullif(current_setting('test.prof1'), ''), (select id::text from public.professions limit 1)), true);

insert into public.entity_professions (entity_id, profession_id, trade_verification_status)
values (current_setting('test.a')::uuid, current_setting('test.prof1')::uuid, 'approved')
on conflict (entity_id, profession_id) do update set trade_verification_status = 'approved';

-- Create published listings L1, L2 as A
set role authenticated;
select set_config('request.jwt.claim.sub', current_setting('test.a'), true);
select set_config('request.jwt.claim.role', 'authenticated', true);

select set_config('test.l1', (select public.service_listing_create(
  current_setting('test.prof1')::uuid,
  'Messaging Fixture Legal Listing One',
  'Messaging fixture listing one description that is definitely longer than fifty characters for encrypted messaging tests.',
  'fixed', 5000, 10000)->'data'->>'id'), true);
select set_config('test.l1_pub', (select public.service_listing_publish(current_setting('test.l1')::uuid)->>'code'), true);

select set_config('test.l2', (select public.service_listing_create(
  current_setting('test.prof1')::uuid,
  'Messaging Fixture Second Listing Beta',
  'Second messaging fixture listing description that is definitely longer than fifty characters for conversation tests.',
  'fixed', 7000)->'data'->>'id'), true);
select set_config('test.l2_pub', (select public.service_listing_publish(current_setting('test.l2')::uuid)->>'code'), true);

-- Create active contracts C1 (B->A via L1), C2 (B->A via L2), C3 offered (B->A via L1 for offered tests)
set role authenticated;
select set_config('request.jwt.claim.sub', current_setting('test.b'), true);
select set_config('test.c1', (select public.service_contract_offer(
  current_setting('test.l1')::uuid, 50000, 'NGN',
  '[{"milestone_number":1,"title":"Draft","amount":20000},{"milestone_number":2,"title":"Final","amount":30000}]'::jsonb
)->'data'->'contract'->>'id'), true);
select set_config('test.c2', (select public.service_contract_offer(
  current_setting('test.l2')::uuid, 40000, 'NGN',
  '[{"milestone_number":1,"title":"Phase One","amount":20000},{"milestone_number":2,"title":"Phase Two","amount":20000}]'::jsonb
)->'data'->'contract'->>'id'), true);
select set_config('test.c3', (select public.service_contract_offer(
  current_setting('test.l1')::uuid, 20000, 'NGN',
  '[{"milestone_number":1,"title":"Offered Only","amount":20000}]'::jsonb
)->'data'->'contract'->>'id'), true);

-- Accept C1 and C2 as A (professional)
set role authenticated;
select set_config('request.jwt.claim.sub', current_setting('test.a'), true);
select lives_ok($$ select public.service_contract_accept(current_setting('test.c1')::uuid) $$, 'accept c1 for messaging');
select lives_ok($$ select public.service_contract_accept(current_setting('test.c2')::uuid) $$, 'accept c2 for messaging');
-- C3 remains offered (no accept) for validation that ensure still checks participant (offered still participant)

-- Pre-ensure conversations for C1 and C2 as B (client)
set role authenticated;
select set_config('request.jwt.claim.sub', current_setting('test.b'), true);
select set_config('test.conv1', (select public.conversation_ensure_for_contract(current_setting('test.c1')::uuid)->'data'->'conversation'->>'id'), true);
select set_config('test.conv2', (select public.conversation_ensure_for_contract(current_setting('test.c2')::uuid)->'data'->'conversation'->>'id'), true);

-- ─── 1. Authorization: anon cannot call any of the 4 ─────────────────────────
set role anon;
select set_config('request.jwt.claim.role', 'anon', true);

select throws_ok($$ select public.conversation_ensure_for_contract('00000000-0000-0000-0000-000000000000'::uuid) $$,
  '42501', null, 'anon cannot call conversation_ensure_for_contract');
select throws_ok($$ select public.message_send('00000000-0000-0000-0000-000000000000'::uuid, repeat('x', 50), 'hi', gen_random_uuid()) $$,
  '42501', null, 'anon cannot call message_send');
select throws_ok($$ select public.conversation_list(20, null) $$,
  '42501', null, 'anon cannot call conversation_list');
select throws_ok($$ select public.message_list('00000000-0000-0000-0000-000000000000'::uuid, 20, null) $$,
  '42501', null, 'anon cannot call message_list');

-- ─── 2. Validation: authenticated ────────────────────────────────────────────
set role authenticated;
select set_config('request.jwt.claim.sub', current_setting('test.b'), true);
select set_config('request.jwt.claim.role', 'authenticated', true);

select throws_ok($$ select public.conversation_ensure_for_contract(null::uuid) $$,
  'P0001', null, 'ensure null contract_id PLT003');
select throws_ok($$ select public.conversation_ensure_for_contract('99999999-9999-9999-9999-999999999999'::uuid) $$,
  'P0001', null, 'ensure unknown contract PLT004');

-- Stranger C cannot ensure conversation for C1 (belongs to A/B)
set role authenticated;
select set_config('request.jwt.claim.sub', current_setting('test.c'), true);
select throws_ok($$ select public.conversation_ensure_for_contract(current_setting('test.c1')::uuid) $$,
  'P0001', null, 'stranger ensure PLT004 identical to unknown');

-- message_send validation as B (participant)
set role authenticated;
select set_config('request.jwt.claim.sub', current_setting('test.b'), true);
select throws_ok($$ select public.message_send(null::uuid, repeat('x', 50), 'hi', gen_random_uuid()) $$,
  'P0001', null, 'message_send null conversation_id PLT003');
select throws_ok($$ select public.message_send(current_setting('test.conv1')::uuid, null::text, 'hi', gen_random_uuid()) $$,
  'P0001', null, 'message_send null body_encrypted PLT003');
select throws_ok($$ select public.message_send(current_setting('test.conv1')::uuid, 'short', 'hi', gen_random_uuid()) $$,
  'P0001', null, 'message_send short body_encrypted 5 PLT003');
select throws_ok($$ select public.message_send(current_setting('test.conv1')::uuid, repeat('x', 8001), 'hi', gen_random_uuid()) $$,
  'P0001', null, 'message_send long body_encrypted 8001 PLT003');
select throws_ok($$ select public.message_send(current_setting('test.conv1')::uuid, repeat('x', 50), 'hi', null::uuid) $$,
  'P0001', null, 'message_send null client_message_id PLT003');
select throws_ok($$ select public.message_send('99999999-9999-9999-9999-999999999999'::uuid, repeat('x', 50), 'hi', gen_random_uuid()) $$,
  'P0001', null, 'message_send unknown conversation PLT004');

-- Stranger C cannot send to conv1 (belongs to A/B)
set role authenticated;
select set_config('request.jwt.claim.sub', current_setting('test.c'), true);
select throws_ok($$ select public.message_send(current_setting('test.conv1')::uuid, repeat('x', 50), 'hi stranger', gen_random_uuid()) $$,
  'P0001', null, 'stranger message_send PLT004 identical to unknown');

-- conversation_list validation
set role authenticated;
select set_config('request.jwt.claim.sub', current_setting('test.b'), true);
select throws_ok($$ select public.conversation_list(0, null) $$,
  'P0001', null, 'conversation_list limit 0 PLT003');
select throws_ok($$ select public.conversation_list(101, null) $$,
  'P0001', null, 'conversation_list limit 101 PLT003');

-- message_list validation
select throws_ok($$ select public.message_list(null::uuid, 20, null) $$,
  'P0001', null, 'message_list null conversation_id PLT003');
select throws_ok($$ select public.message_list(current_setting('test.conv1')::uuid, 0, null) $$,
  'P0001', null, 'message_list limit 0 PLT003');
select throws_ok($$ select public.message_list(current_setting('test.conv1')::uuid, 101, null) $$,
  'P0001', null, 'message_list limit 101 PLT003');
select throws_ok($$ select public.message_list('99999999-9999-9999-9999-999999999999'::uuid, 20, null) $$,
  'P0001', null, 'message_list unknown conversation PLT004');
set role authenticated;
select set_config('request.jwt.claim.sub', current_setting('test.c'), true);
select throws_ok($$ select public.message_list(current_setting('test.conv1')::uuid, 20, null) $$,
  'P0001', null, 'stranger message_list PLT004');

-- ─── 3. Functional: ensure idempotent ───────────────────────────────────────
set role authenticated;
select set_config('request.jwt.claim.sub', current_setting('test.b'), true);
select set_config('request.jwt.claim.role', 'authenticated', true);
select is(
  (select public.conversation_ensure_for_contract(current_setting('test.c1')::uuid)->'data'->'conversation'->>'id'),
  current_setting('test.conv1'),
  'ensure idempotent same conv_id for same contract'
);
set role authenticated;
select set_config('request.jwt.claim.sub', current_setting('test.a'), true);
select is(
  (select public.conversation_ensure_for_contract(current_setting('test.c1')::uuid)->'data'->'conversation'->>'id'),
  current_setting('test.conv1'),
  'ensure same conv_id from opposite participant'
);
select is(
  (select count(*)::int from public.conversation_participants where conversation_id = current_setting('test.conv1')::uuid),
  2,
  'conversation has exactly 2 participants after ensure'
);
select is(
  (select count(*)::int from public.conversations where contract_id = current_setting('test.c1')::uuid),
  1,
  '1:1 contract_id unique, still 1 row after second ensure'
);

-- ─── 4. Functional: message_send success + envelope ───────────────────────────
set role authenticated;
select set_config('request.jwt.claim.sub', current_setting('test.b'), true);
select set_config('test.cmid1', gen_random_uuid()::text, true);
select is(
  (select public.message_send(current_setting('test.conv1')::uuid, repeat('x', 50), 'Hello from Lagos 120', current_setting('test.cmid1')::uuid)->>'code'),
  'PLT000', 'message_send B first succeeds PLT000'
);
select is(
  (select count(*)::int from public.messages where client_message_id = current_setting('test.cmid1')::uuid),
  1,
  'DB: 1 row for client_message_id after send'
);
select is(
  (select body_preview from public.messages where client_message_id = current_setting('test.cmid1')::uuid),
  'Hello from Lagos 120',
  'body_preview stored truncated 120 (no PII)'
);

-- ─── 5. Functional: dedup via client_message_id ON CONFLICT ──────────────────
select is(
  (select public.message_send(current_setting('test.conv1')::uuid, repeat('x', 50), 'Hello duplicate', current_setting('test.cmid1')::uuid)->>'code'),
  'PLT000', 'duplicate client_message_id second send still PLT000 (dedup)'
);
select is(
  (select count(*)::int from public.messages where client_message_id = current_setting('test.cmid1')::uuid),
  1,
  'DB: still 1 row after duplicate client_message_id (no duplicate)'
);
select is(
  (select public.message_send(current_setting('test.conv1')::uuid, repeat('x', 50), 'Hello duplicate', current_setting('test.cmid1')::uuid)->'data'->>'id'),
  (select id::text from public.messages where client_message_id = current_setting('test.cmid1')::uuid),
  'dedup returns same message id'
);

-- Second distinct message from opposite participant A
set role authenticated;
select set_config('request.jwt.claim.sub', current_setting('test.a'), true);
select set_config('test.cmid2', gen_random_uuid()::text, true);
select is(
  (select public.message_send(current_setting('test.conv1')::uuid, repeat('y', 60), 'Reply from A with test@example.com 08031234567', current_setting('test.cmid2')::uuid)->>'code'),
  'PLT000', 'message_send A second distinct succeeds'
);
select is(
  (select body_preview from public.messages where client_message_id = current_setting('test.cmid2')::uuid),
  'Reply from A with ***@***.*** ***-****-****',
  'body_preview redacted PII email and phone'
);

-- ─── 6. Functional: message_list participant ─────────────────────────────────
set role authenticated;
select set_config('request.jwt.claim.sub', current_setting('test.b'), true);
select is(
  (select jsonb_array_length(public.message_list(current_setting('test.conv1')::uuid, 20, null)->'data'->'items')),
  2,
  'message_list as B returns 2 messages'
);
select is(
  (select (public.message_list(current_setting('test.conv1')::uuid, 20, null)->'data'->>'has_more')::boolean),
  false,
  'message_list has_more false for 2 with limit 20'
);
-- Pagination: limit 1
select is(
  (select jsonb_array_length(public.message_list(current_setting('test.conv1')::uuid, 1, null)->'data'->'items')),
  1,
  'message_list limit 1 returns 1'
);
select is(
  (select (public.message_list(current_setting('test.conv1')::uuid, 1, null)->'data'->>'has_more')::boolean),
  true,
  'message_list limit 1 has_more true for 2 rows'
);
-- Cursor pagination
select set_config('test.m_cursor', (select public.message_list(current_setting('test.conv1')::uuid, 1, null)->'data'->>'next_cursor'), true);
select is(
  (select jsonb_array_length(public.message_list(current_setting('test.conv1')::uuid, 1, current_setting('test.m_cursor')::uuid)->'data'->'items')),
  1,
  'message_list cursor pagination second page 1 row'
);
-- Unknown cursor returns empty
select is(
  (select jsonb_array_length(public.message_list(current_setting('test.conv1')::uuid, 20, '99999999-9999-9999-9999-999999999999'::uuid)->'data'->'items')),
  0,
  'message_list unknown cursor returns empty'
);
-- Body_encrypted opaque still present
select is(
  (select char_length((public.message_list(current_setting('test.conv1')::uuid, 20, null)->'data'->'items'->0->>'body_encrypted')::text) >= 20),
  true,
  'message_list body_encrypted opaque >=20 present'
);

-- ─── 7. Functional: conversation_list ─────────────────────────────────────────
select is(
  (select jsonb_array_length(public.conversation_list(20, null)->'data'->'items')),
  2,
  'conversation_list as B returns 2 conversations (conv1 and conv2)'
);
select is(
  (select jsonb_array_length(public.conversation_list(1, null)->'data'->'items')),
  1,
  'conversation_list limit 1 returns 1'
);
select is(
  (select (public.conversation_list(1, null)->'data'->>'has_more')::boolean),
  true,
  'conversation_list limit 1 has_more true for 2'
);
select set_config('test.c_cursor', (select public.conversation_list(1, null)->'data'->>'next_cursor'), true);
select is(
  (select jsonb_array_length(public.conversation_list(1, current_setting('test.c_cursor')::uuid)->'data'->'items')),
  1,
  'conversation_list cursor second page 1 row'
);
select is(
  (select jsonb_array_length(public.conversation_list(20, '99999999-9999-9999-9999-999999999999'::uuid)->'data'->'items')),
  0,
  'conversation_list unknown cursor empty'
);
-- Stranger C sees 0 conversations
set role authenticated;
select set_config('request.jwt.claim.sub', current_setting('test.c'), true);
select is(
  (select jsonb_array_length(public.conversation_list(20, null)->'data'->'items')),
  0,
  'conversation_list as stranger C returns 0'
);
-- B last_message_preview via LATERAL after A second message
set role authenticated;
select set_config('request.jwt.claim.sub', current_setting('test.b'), true);
select is(
  (select (public.conversation_list(20, null)->'data'->'items'->0->>'last_message_preview') is not null),
  true,
  'conversation_list last_message_preview via LATERAL not null'
);

-- ─── 8. RLS leakage matrix ────────────────────────────────────────────────────
set role authenticated;
select set_config('request.jwt.claim.sub', current_setting('test.c'), true);
select is(
  (select count(*)::int from public.messages where conversation_id = current_setting('test.conv1')::uuid),
  0,
  'RLS: stranger C SELECT count 0 on messages of conv1'
);
select is(
  (select count(*)::int from public.conversations where id = current_setting('test.conv1')::uuid),
  0,
  'RLS: stranger C SELECT count 0 on conversations conv1'
);
-- Direct INSERT as stranger blocked
select throws_ok($$ insert into public.messages (conversation_id, sender_entity_id, body_encrypted, client_message_id) values (current_setting('test.conv1')::uuid, current_setting('test.c')::uuid, repeat('x', 50), gen_random_uuid()) $$,
  '42501', null, 'RLS: direct INSERT as stranger blocked 42501');
-- Direct UPDATE body_encrypted blocked (no UPDATE grant)
set role authenticated;
select set_config('request.jwt.claim.sub', current_setting('test.b'), true);
select throws_ok($$ update public.messages set body_encrypted = repeat('z', 50) where client_message_id = current_setting('test.cmid1')::uuid $$,
  '42501', null, 'direct UPDATE body_encrypted blocked (no UPDATE grant)');

-- ─── 9. Immutability and invariants ──────────────────────────────────────────
select is(
  (select count(*)::int from public.messages where body_encrypted is null or btrim(body_encrypted) = '' or char_length(btrim(body_encrypted)) not between 20 and 8000),
  0,
  'no messages violate body_encrypted 20-8000 CHECK'
);
select is(
  (select count(*)::int from public.messages where body_preview is not null and char_length(body_preview) > 120),
  0,
  'no messages violate body_preview <=120'
);
select is(
  (select count(*)::int from (select client_message_id, count(*) from public.messages group by 1 having count(*) > 1) s),
  0,
  'no duplicate client_message_id in messages'
);
-- last_read_at touched after message_list
set role authenticated;
select set_config('request.jwt.claim.sub', current_setting('test.b'), true);
select lives_ok($$ select public.message_list(current_setting('test.conv1')::uuid, 20, null) $$, 'touch last_read_at via message_list');
select is(
  (select (last_read_at is not null) from public.conversation_participants where conversation_id = current_setting('test.conv1')::uuid and entity_id = current_setting('test.b')::uuid),
  true,
  'last_read_at touched after message_list'
);

-- ─── 10. Envelope code PLT000 ────────────────────────────────────────────────
select is(
  (select public.conversation_ensure_for_contract(current_setting('test.c1')::uuid)->>'code'),
  'PLT000', 'envelope code PLT000 for ensure'
);
select is(
  (select public.message_list(current_setting('test.conv1')::uuid, 20, null)->>'code'),
  'PLT000', 'envelope code PLT000 for message_list'
);

-- ─── 11. service_role can call all 4 ────────────────────────────────────────
set role service_role;
select set_config('request.jwt.claim.sub', current_setting('test.a'), true);
select set_config('request.jwt.claim.role', 'service_role', true);
select lives_ok($$ select public.conversation_ensure_for_contract(current_setting('test.c1')::uuid) $$, 'service_role ensure');
select lives_ok($$ select public.conversation_list(20, null) $$, 'service_role conversation_list');
-- service_role can send as well (uses auth.uid but service_role bypass)
select set_config('test.cmid_sr', gen_random_uuid()::text, true);
select lives_ok($$ select public.message_send(current_setting('test.conv1')::uuid, repeat('z', 50), 'SR preview', current_setting('test.cmid_sr')::uuid) $$, 'service_role message_send');
select lives_ok($$ select public.message_list(current_setting('test.conv1')::uuid, 20, null) $$, 'service_role message_list');

select * from finish();
rollback;
