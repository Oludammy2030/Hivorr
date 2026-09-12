-- Development-only demo identity seed (EP-02-18 UAT preview)
--
-- Purpose: the onboarding wizard has a development-only UAT seam that lets an
-- unauthenticated reviewer open `/onboarding` directly (route_guard.dart). The
-- functional steps (profile RPCs etc.) still require an authenticated session,
-- so the app in Development auto-signs-in with this seeded identity. The email
-- is confirmed below so it behaves like a normal confirmed account.
--
-- The password is a local, throwaway account credential used ONLY by this
-- seeded identity — it is not a secret. Production/Staging never reference it.
-- The login/signup UI remains the real auth surface.
--
-- GoTrue scans `auth.users` token/change columns into Go strings, so empty
-- strings (not NULL) are required for those columns: confirmation_token,
-- recovery_token, email_change, email_change_token_current/_new and the phone
-- change pair. They stay out of the token partial-unique indexes
-- (`WHERE confirmation_token !~ '^[0-9 ]*$'`), keeping this seed idempotent.
--
-- Idempotent: re-running seed/migrations leaves the row untouched.

insert into auth.users (
  instance_id,
  id,
  aud,
  role,
  email,
  encrypted_password,
  email_confirmed_at,
  confirmation_token,
  recovery_token,
  email_change,
  email_change_token_current,
  email_change_token_new,
  phone_change,
  phone_change_token,
  raw_app_meta_data,
  raw_user_meta_data,
  created_at,
  updated_at
)
values (
  '00000000-0000-0000-0000-000000000000',
  '00000000-0000-4000-8000-000000000001',
  'authenticated',
  'authenticated',
  'demo@hivorr.local',
  '$2a$10$4PUPAGfFcFUNO.nUXK4tC.Oncc9lVi8ZD0In.FF0swEdhqQ2SNuvS',
  now(),
  '',
  '',
  '',
  '',
  '',
  '',
  '',
  '{"provider":"email","providers":["email"]}',
  '{}',
  now(),
  now()
)
on conflict (id) do nothing;